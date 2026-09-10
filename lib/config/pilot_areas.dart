import 'package:flutter/widgets.dart';

/// Una Pilot Area del progetto PRIMES.
///
/// Ogni area determina due cose:
///  * la lingua in cui l'app viene mostrata ([locale]);
///  * l'etichetta mostrata nel selettore e nella card di allerta.
@immutable
class PilotArea {
  /// Identificativo stabile: e' cio' che viene salvato sul dispositivo e
  /// che il backend/cruscotto dovrebbe usare per indirizzare le notifiche.
  final String id;

  /// Nome dell'area nella lingua locale (mostrato nel dropdown).
  final String label;

  /// Paese, nella lingua locale.
  final String country;

  /// Lingua dell'app per questa area.
  final Locale locale;

  const PilotArea({
    required this.id,
    required this.label,
    required this.country,
    required this.locale,
  });

  String get displayName => '$country - $label';

  /// Sigla della lingua in cui l'app viene mostrata per quest'area
  /// (IT, HR, BS, SR, EL): serve da indizio nel selettore del login.
  String get languageBadge => locale.languageCode.toUpperCase();
}

/// Le 8 aree pilota del progetto.
const List<PilotArea> pilotAreas = [
  PilotArea(
    id: 'it-marche',
    label: 'Regione Marche',
    country: 'Italia',
    locale: Locale('it'),
  ),
  PilotArea(
    id: 'it-emilia-romagna',
    label: 'Regione Emilia-Romagna',
    country: 'Italia',
    locale: Locale('it'),
  ),
  PilotArea(
    id: 'hr-medimurje',
    label: 'Međimurska županija',
    country: 'Hrvatska',
    locale: Locale('hr'),
  ),
  PilotArea(
    id: 'hr-koprivnica-krizevci',
    label: 'Koprivničko-križevačka županija',
    country: 'Hrvatska',
    locale: Locale('hr'),
  ),
  PilotArea(
    id: 'ba-gradiska',
    label: 'Područje Gradiške',
    country: 'Bosna i Hercegovina',
    locale: Locale('bs'),
  ),
  PilotArea(
    id: 'me-danilovgrad',
    label: 'Opština Danilovgrad',
    country: 'Crna Gora',
    locale: Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ),
  PilotArea(
    id: 'gr-laconia',
    label: 'Περιφέρεια Λακωνίας (Σπάρτη)',
    country: 'Ελλάδα',
    locale: Locale('el'),
  ),
  PilotArea(
    id: 'rs-vojvodina',
    label: 'Vojvodina',
    country: 'Srbija',
    locale: Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
  ),
];

PilotArea? pilotAreaById(String? id) {
  if (id == null) return null;
  for (final area in pilotAreas) {
    if (area.id == id) return area;
  }
  return null;
}
