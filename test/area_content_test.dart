import 'dart:convert';
import 'dart:io';

import 'package:app_primes/config/area_content.dart';
import 'package:app_primes/config/pilot_areas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contenuti delle aree pilota', () {
    test('ogni contenuto e\' agganciato a un\'area esistente', () {
      for (final id in areaContents.keys) {
        expect(pilotAreaById(id), isNotNull, reason: 'area sconosciuta: $id');
      }
    });

    test('ogni area configurata ha quattro livelli non vuoti', () {
      areaContents.forEach((id, content) {
        expect(content.officialName, isNotEmpty, reason: id);
        expect(content.levels.length, 4, reason: id);
        for (final level in content.levels) {
          expect(level.name, isNotEmpty, reason: id);
          expect(level.rules, isNotEmpty, reason: '${level.name} ($id)');
        }
      });
    });

    // Un refuso nel percorso di un asset non rompe la compilazione: si vedrebbe
    // solo aprendo il documento sul dispositivo. Meglio accorgersene qui.
    test('ogni documento punta a un file esistente e dichiarato', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      areaContents.forEach((id, content) {
        for (final doc in content.documents) {
          expect(
            File(doc.asset).existsSync(),
            isTrue,
            reason: 'file mancante: ${doc.asset}',
          );
          final folder =
              '${doc.asset.substring(0, doc.asset.lastIndexOf('/'))}/';
          expect(
            pubspec.contains('- $folder'),
            isTrue,
            reason: 'cartella non dichiarata in pubspec.yaml: $folder',
          );
        }
      });
    });

    test('nessun documento e\' elencato due volte', () {
      areaContents.forEach((id, content) {
        final assets = content.documents.map((d) => d.asset).toList();
        expect(assets.toSet().length, assets.length, reason: id);
      });
    });

    test('i recapiti hanno etichetta e valore', () {
      areaContents.forEach((id, content) {
        for (final contact in content.contacts) {
          expect(contact.label, isNotEmpty, reason: id);
          expect(contact.value, isNotEmpty, reason: '${contact.label} ($id)');
          if (contact.isEmail) {
            expect(contact.value, contains('@'), reason: contact.label);
          }
        }
      });
    });
  });

  group("livello del backend tradotto nel nome dell'area", () {
    test('la chiave canonica sceglie il livello giusto', () {
      final l = areaLevelFor(areaId: 'hr-medimurje', key: 'level2');
      expect(l, isNotNull);
      expect(l!.name, contains('Upozorenje'));
    });

    // Il cruscotto in produzione non manda ancora la chiave: senza il ripiego
    // sull'etichetta l'app croata mostrerebbe "Livello 2 - Allarme".
    test("senza chiave si ripiega sull'etichetta italiana del backend", () {
      final l = areaLevelFor(
        areaId: 'hr-koprivnica-krizevci',
        key: null,
        backendLabel: 'Livello 3 - Avviso di carenza',
      );
      expect(l, isNotNull);
      expect(l!.name, startsWith('Razina 4'));
    });

    test('ogni chiave del backend copre un livello di ogni area', () {
      for (final areaId in areaContents.keys) {
        for (final key in backendLevelKeys) {
          expect(
            areaLevelFor(areaId: areaId, key: key),
            isNotNull,
            reason: '$areaId non risolve $key',
          );
        }
      }
    });

    test("un'area non configurata non risolve nulla", () {
      expect(areaLevelFor(areaId: 'it-marche', key: 'level2'), isNull);
      expect(areaLevelFor(areaId: null, key: 'level2'), isNull);
    });

    test('una chiave sconosciuta non risolve nulla', () {
      expect(areaLevelFor(areaId: 'hr-medimurje', key: 'level9'), isNull);
      expect(
        areaLevelFor(areaId: 'hr-medimurje', backendLabel: 'Boh'),
        isNull,
      );
    });
  });

  // Le chiavi mancanti ricadono sull'inglese, quindi un buco non rompe nulla:
  // ma resta un pezzo di interfaccia non tradotto, ed e' bene saperlo.
  test('ogni lingua ha tutte le chiavi dell\'inglese', () {
    Map<String, dynamic> load(String lang) =>
        jsonDecode(File('assets/i18n/$lang.json').readAsStringSync())
            as Map<String, dynamic>;

    final en = load('en').keys.toSet();
    for (final lang in ['it', 'hr', 'bs', 'sr', 'el']) {
      final missing = en.difference(load(lang).keys.toSet());
      expect(missing, isEmpty, reason: 'chiavi mancanti in $lang.json');
    }
  });
}
