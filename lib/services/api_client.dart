import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Chiamate REST verso il backend PRIMES.
///
/// Sono tutte rotte pubbliche: l'app legge lo stato della propria area e
/// registra il token per le push. Scrivere (cambiare livello, inviare avvisi)
/// e' riservato agli operatori del cruscotto, che passano da rotte autenticate.
class ApiClient {
  static const Duration _timeout = Duration(seconds: 15);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$backendBaseUrl$path').replace(queryParameters: query);

  static Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(body['error']?.toString() ?? 'Errore ${res.statusCode}');
    }
    return body;
  }

  /// Livello di allerta corrente dell'area.
  static Future<AlertLevelDto> alertLevel(String areaId) async {
    final res = await http.get(_uri('/api/areas/$areaId/alert-level')).timeout(_timeout);
    final body = _decode(res);
    return AlertLevelDto.fromJson(
      Map<String, dynamic>.from(body['alertLevel'] as Map),
    );
  }

  /// Storico degli avvisi dell'area, dal piu' recente.
  static Future<List<Map<String, dynamic>>> notifications(
    String areaId, {
    int limit = 50,
  }) async {
    final res = await http
        .get(_uri('/api/areas/$areaId/notifications', {'limit': '$limit'}))
        .timeout(_timeout);
    final body = _decode(res);
    return (body['notifications'] as List<dynamic>)
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
  }

  /// Registra il token FCM e iscrive il dispositivo al topic della sua area.
  ///
  /// Va richiamata a ogni avvio e a ogni cambio di area: e' il server a
  /// disiscrivere dal topic precedente, cosi' un utente delle Marche smette di
  /// ricevere gli avvisi croati.
  static Future<void> registerDevice({
    required String token,
    required String areaId,
    String? platform,
  }) async {
    final res = await http
        .post(
          _uri('/api/devices'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'areaId': areaId,
            'platform': platform ?? defaultTargetPlatform.name,
          }),
        )
        .timeout(_timeout);
    _decode(res);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Livello di allerta come arriva dal backend.
@immutable
class AlertLevelDto {
  /// Chiave canonica del livello (`none`, `level1`, `level2`, `level3`).
  ///
  /// E' cio' che permette all'app di mostrare il nome scelto dall'area invece
  /// dell'etichetta di servizio del backend. Puo' mancare: il cruscotto
  /// attuale non la manda quando cambia livello.
  final String? key;

  final String level;
  final String colorHex;

  const AlertLevelDto({
    required this.level,
    required this.colorHex,
    this.key,
  });

  factory AlertLevelDto.fromJson(Map<String, dynamic> json) => AlertLevelDto(
    key: json['key']?.toString(),
    level: json['level']?.toString() ?? 'N/D',
    colorHex: json['colorHex']?.toString() ?? '#FF9800',
  );
}
