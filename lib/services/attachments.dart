import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Allegati scaricati dalle notifiche, dal piu' recente.
///
/// Ogni voce: `nome`, `dim` (dimensione leggibile), `data` (gg/mm/aaaa),
/// `path` (file sul dispositivo) e `url` (da dove e' stato scaricato).
final ValueNotifier<List<Map<String, String>>> archivioDocumenti =
    ValueNotifier([]);

/// Esito di un'apertura o di un download.
enum AttachmentError { notAllowed, network, noViewer }

class AttachmentException implements Exception {
  final AttachmentError reason;
  const AttachmentException(this.reason);
  @override
  String toString() => 'AttachmentException($reason)';
}

/// Download e apertura degli allegati delle notifiche.
///
/// Il file finisce nella cartella privata dell'app e si apre con il
/// visualizzatore di sistema, come i documenti ufficiali dell'area. L'elenco
/// resta salvato per utente: chiudendo l'app i documenti scaricati restano.
class Attachments {
  const Attachments._();

  static const Duration _timeout = Duration(seconds: 60);
  static String? _uid;

  static String _prefsKey(String uid) => 'primes.allegati.$uid';

  /// Rilegge l'archivio dell'utente, scartando i file che non esistono piu'.
  static Future<void> load(String uid) async {
    _uid = uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(uid));
      final list = raw == null
          ? <Map<String, String>>[]
          : (jsonDecode(raw) as List)
                .map((e) => Map<String, String>.from(e as Map))
                .where((doc) => File(doc['path'] ?? '').existsSync())
                .toList();
      archivioDocumenti.value = list;
    } catch (e) {
      debugPrint('[allegati] archivio non letto: $e');
      archivioDocumenti.value = [];
    }
  }

  /// Account eliminato: via i file scaricati e l'elenco salvato.
  static Future<void> deleteAll() async {
    await delete(List.of(archivioDocumenti.value));
    final uid = _uid;
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefsKey(uid));
      } catch (e) {
        debugPrint('[allegati] archivio non rimosso: $e');
      }
    }
    clear();
  }

  /// Logout: l'elenco era dell'utente precedente.
  static void clear() {
    _uid = null;
    archivioDocumenti.value = [];
  }

  /// Il documento gia' scaricato da [url], se c'e'.
  static Map<String, String>? downloaded(String? url) {
    if (url == null) return null;
    final resolved = resolveUrl(url)?.toString();
    return archivioDocumenti.value
        .where((doc) => doc['url'] == resolved)
        .firstOrNull;
  }

  /// Gli allegati si scaricano solo dal backend PRIMES: l'URL arriva dentro
  /// una push, e non deve poter far scaricare al telefono file da altrove.
  @visibleForTesting
  static Uri? resolveUrl(String url) {
    final base = Uri.parse(backendBaseUrl);
    final uri = url.startsWith('/') ? base.resolve(url) : Uri.tryParse(url);
    if (uri == null || uri.host != base.host || uri.scheme != base.scheme) {
      return null;
    }
    return uri;
  }

  /// Nome di file sicuro: niente cartelle, niente caratteri che Android o iOS
  /// rifiutano.
  @visibleForTesting
  static String safeFileName(String name) {
    final cleaned = name
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
        .trim();
    return cleaned.isEmpty ? 'documento' : cleaned;
  }

  @visibleForTesting
  static String readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Scarica l'allegato (o riusa quello gia' scaricato) e lo aggiunge
  /// all'archivio.
  static Future<Map<String, String>> download({
    required String url,
    required String name,
  }) async {
    final existing = downloaded(url);
    if (existing != null) return existing;

    final uri = resolveUrl(url);
    if (uri == null) {
      throw const AttachmentException(AttachmentError.notAllowed);
    }

    final http.Response res;
    try {
      res = await http.get(uri).timeout(_timeout);
    } catch (e) {
      debugPrint('[allegati] download di $uri fallito: $e');
      throw const AttachmentException(AttachmentError.network);
    }
    if (res.statusCode != 200) {
      debugPrint('[allegati] download di $uri: HTTP ${res.statusCode}');
      throw const AttachmentException(AttachmentError.network);
    }

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/allegati');
    await folder.create(recursive: true);

    // Due allegati diversi con lo stesso nome non si sovrascrivono.
    final fileName = safeFileName(name);
    var file = File('${folder.path}/$fileName');
    for (var i = 2; await file.exists(); i++) {
      final dot = fileName.lastIndexOf('.');
      final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
      final ext = dot > 0 ? fileName.substring(dot) : '';
      file = File('${folder.path}/$stem ($i)$ext');
    }
    await file.writeAsBytes(res.bodyBytes, flush: true);

    final now = DateTime.now();
    final doc = {
      'nome': name,
      'dim': readableSize(res.bodyBytes.length),
      'data':
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      'path': file.path,
      'url': uri.toString(),
    };
    archivioDocumenti.value = [doc, ...archivioDocumenti.value];
    await _save();
    return doc;
  }

  /// Apre il file con il visualizzatore di sistema.
  static Future<void> open(Map<String, String> doc) async {
    final path = doc['path'];
    if (path == null || !File(path).existsSync()) {
      throw const AttachmentException(AttachmentError.network);
    }
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      debugPrint('[allegati] apertura di $path: ${result.message}');
      throw const AttachmentException(AttachmentError.noViewer);
    }
  }

  /// Elimina dall'archivio e dal dispositivo.
  static Future<void> delete(Iterable<Map<String, String>> docs) async {
    final paths = docs.map((d) => d['path']).whereType<String>().toSet();
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('[allegati] eliminazione di $path fallita: $e');
      }
    }
    archivioDocumenti.value = archivioDocumenti.value
        .where((d) => !paths.contains(d['path']))
        .toList();
    await _save();
  }

  static Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey(uid),
        jsonEncode(archivioDocumenti.value),
      );
    } catch (e) {
      debugPrint('[allegati] archivio non salvato: $e');
    }
  }
}
