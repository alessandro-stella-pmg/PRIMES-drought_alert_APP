import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Localizzazione a runtime basata su file JSON in `assets/i18n/`.
///
/// Scelta voluta: i partner (e i traduttori) possono modificare un JSON senza
/// toccare Dart e senza rigenerare codice. Le chiavi mancanti in una lingua
/// ricadono automaticamente sull'inglese, quindi un file incompleto non rompe
/// mai l'interfaccia.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings;
  final Map<String, String> _fallback;

  AppLocalizations(this.locale, this._strings, this._fallback);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('it'),
    Locale('hr'),
    Locale('bs'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
    Locale('el'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Traduce [key]. Restituisce la chiave stessa se non esiste da nessuna
  /// parte: in debug e' immediatamente visibile cosa manca.
  String t(String key) => _strings[key] ?? _fallback[key] ?? key;

  /// Come [t], ma sostituisce i segnaposto `{nome}` con [args].
  String f(String key, Map<String, Object?> args) {
    var out = t(key);
    args.forEach((k, v) => out = out.replaceAll('{$k}', '${v ?? ''}'));
    return out;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final fallback = await _loadJson('en');
    final strings = locale.languageCode == 'en'
        ? fallback
        : await _loadJson(locale.languageCode);
    return AppLocalizations(locale, strings, fallback);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;

  static final Map<String, Map<String, String>> _cache = {};

  static Future<Map<String, String>> _loadJson(String languageCode) async {
    final cached = _cache[languageCode];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/i18n/$languageCode.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = decoded.map((k, v) => MapEntry(k, v.toString()));
      _cache[languageCode] = map;
      return map;
    } catch (e) {
      debugPrint('i18n: impossibile caricare $languageCode.json ($e)');
      return const {};
    }
  }
}
