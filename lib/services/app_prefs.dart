import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/pilot_areas.dart';

/// Area pilota attiva: determina la lingua dell'app e le etichette di zona.
///
/// E' un [ValueNotifier] globale come il resto dello stato dell'app, cosi'
/// `MaterialApp` puo' ricostruirsi quando l'utente sceglie o cambia area.
final ValueNotifier<PilotArea?> selectedPilotArea = ValueNotifier(null);

class AppPrefs {
  static const String _areaKey = 'primes.pilot_area_id';

  /// Rilegge l'area salvata al primo avvio dell'app.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    selectedPilotArea.value = pilotAreaById(prefs.getString(_areaKey));
  }

  static Future<void> setArea(PilotArea area) async {
    selectedPilotArea.value = area;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_areaKey, area.id);
  }

  static Future<void> clearArea() async {
    selectedPilotArea.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_areaKey);
  }
}
