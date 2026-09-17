import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Chiamate REST verso il backend PRIMES.
///
/// Il livello di allerta e' pubblico. Tutto cio' che riguarda le notifiche
/// (storico, registrazione del dispositivo, lette ed eliminate) richiede il
/// login: l'ID token Firebase viaggia in `Authorization`. Scrivere (cambiare
/// livello, inviare avvisi) resta riservato agli operatori del cruscotto.
class ApiClient {
  static const Duration _timeout = Duration(seconds: 15);

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$backendBaseUrl$path').replace(queryParameters: query);

  static Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final token = await AuthService.idToken();
    if (token == null) throw ApiException('Login richiesto.', statusCode: 401);
    return {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        body['error']?.toString() ?? 'Errore ${res.statusCode}',
        statusCode: res.statusCode,
        code: body['code']?.toString(),
        body: body,
      );
    }
    return body;
  }

  /// Livello di allerta corrente dell'area.
  static Future<AlertLevelDto> alertLevel(String areaId) async {
    final res = await http
        .get(_uri('/api/areas/$areaId/alert-level'))
        .timeout(_timeout);
    final body = _decode(res);
    return AlertLevelDto.fromJson(
      Map<String, dynamic>.from(body['alertLevel'] as Map),
    );
  }

  /// Storico degli avvisi dell'area per l'utente loggato, dal piu' recente.
  ///
  /// Il backend toglie le eliminate e aggiunge a ognuna il flag `read`.
  static Future<List<Map<String, dynamic>>> notifications(
    String areaId, {
    int limit = 50,
  }) async {
    final res = await http
        .get(
          _uri('/api/areas/$areaId/notifications', {'limit': '$limit'}),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);
    final body = _decode(res);
    return (body['notifications'] as List<dynamic>)
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
  }

  /// Registra il token FCM per l'utente loggato e l'area scelta.
  ///
  /// Va richiamata dopo il login, a ogni avvio e a ogni cambio di area: il
  /// server invia le push solo ai dispositivi registrati cosi'.
  static Future<void> registerDevice({
    required String token,
    required String areaId,
    String? platform,
  }) async {
    final res = await http
        .post(
          _uri('/api/devices'),
          headers: await _authHeaders(json: true),
          body: jsonEncode({
            'token': token,
            'areaId': areaId,
            'platform': platform ?? defaultTargetPlatform.name,
          }),
        )
        .timeout(_timeout);
    _decode(res);
  }

  /// Logout: il dispositivo smette di ricevere notifiche.
  static Future<void> unregisterDevice(String token) async {
    final res = await http
        .delete(
          _uri('/api/devices/${Uri.encodeComponent(token)}'),
          headers: await _authHeaders(),
        )
        .timeout(_timeout);
    _decode(res);
  }

  /// Area pilota con cui l'utente si e' registrato, o null se non l'ha
  /// ancora scelta.
  static Future<String?> profileAreaId() async {
    final res = await http
        .get(_uri('/api/me'), headers: await _authHeaders())
        .timeout(_timeout);
    final body = _decode(res);
    final profile = body['profile'];
    return profile is Map ? profile['areaId']?.toString() : null;
  }

  /// Salva l'area pilota scelta alla registrazione. Restituisce quella del
  /// profilo: se l'account ne aveva gia' una, e' quella che vale.
  static Future<String> setProfileArea(String areaId) async {
    final res = await http
        .put(
          _uri('/api/me/profile'),
          headers: await _authHeaders(json: true),
          body: jsonEncode({'areaId': areaId}),
        )
        .timeout(_timeout);
    try {
      final body = _decode(res);
      return (body['profile'] as Map)['areaId'].toString();
    } on ApiException catch (e) {
      final locked = e.body?['profile'];
      if (e.code == 'area-locked' && locked is Map) {
        return locked['areaId'].toString();
      }
      rethrow;
    }
  }

  /// Elimina l'account: dispositivi, profilo, notifiche lette/eliminate e
  /// utente Firebase. [reason] facoltativo, conservato senza dati personali.
  static Future<void> deleteAccount({String? reason}) async {
    final res = await http
        .delete(
          _uri('/api/me'),
          headers: await _authHeaders(json: true),
          body: jsonEncode({'reason': reason ?? ''}),
        )
        .timeout(_timeout);
    _decode(res);
  }

  static Future<void> markNotificationsRead(List<String> ids) =>
      _postIds('/api/me/notifications/read', ids);

  /// Elimina solo per questo utente: lo storico dell'area resta intatto.
  static Future<void> deleteNotifications(List<String> ids) =>
      _postIds('/api/me/notifications/delete', ids);

  static Future<void> _postIds(String path, List<String> ids) async {
    if (ids.isEmpty) return;
    final res = await http
        .post(
          _uri(path),
          headers: await _authHeaders(json: true),
          body: jsonEncode({'ids': ids}),
        )
        .timeout(_timeout);
    _decode(res);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Codice applicativo del backend (`area-locked`, `profile-missing`...).
  final String? code;
  final Map<String, dynamic>? body;
  ApiException(this.message, {this.statusCode, this.code, this.body});
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

  const AlertLevelDto({required this.level, required this.colorHex, this.key});

  factory AlertLevelDto.fromJson(Map<String, dynamic> json) => AlertLevelDto(
    key: json['key']?.toString(),
    level: json['level']?.toString() ?? 'N/D',
    colorHex: json['colorHex']?.toString() ?? '#FF9800',
  );
}
