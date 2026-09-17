import 'package:app_primes/config/pilot_areas.dart';
import 'package:app_primes/main.dart';
import 'package:app_primes/services/app_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    selectedPilotArea.value = null;
  });

  testWidgets('App launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PrimesApp());
    await tester.pumpAndSettle();

    // Nessuna area scelta: l'app ripiega sulla lingua del dispositivo (en).
    expect(find.text('Welcome to PRIMES'), findsOneWidget);
  });

  testWidgets('la lingua cambia scegliendo l\'area pilota', (tester) async {
    await tester.pumpWidget(const PrimesApp());
    await tester.pumpAndSettle();

    // L'area si sceglie solo registrandosi.
    await tester.tap(find.text('REGISTER'));
    await tester.pumpAndSettle();

    Future<void> scegliArea(String nomeArea) async {
      await tester.tap(find.byType(DropdownButtonFormField<PilotArea>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nomeArea).last);
      await tester.pumpAndSettle();
    }

    // Paggaio -> greco, subito nella schermata di registrazione.
    await scegliArea('Ελλάδα - Δήμος Παγγαίου (Καβάλα)');
    expect(find.text('Δημιουργήστε λογαριασμό'), findsOneWidget);

    // Cambiando area cambia di nuovo, senza riavviare.
    await scegliArea('Italia - Regione Marche');
    expect(find.text('Crea il tuo account'), findsOneWidget);

    await scegliArea('Hrvatska - Međimurska županija');
    expect(find.text('Izradite račun'), findsOneWidget);
  });

  testWidgets('ogni area espone la sigla della lingua', (tester) async {
    await tester.pumpWidget(const PrimesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('REGISTER'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<PilotArea>));
    await tester.pumpAndSettle();

    for (final sigla in ['IT', 'HR', 'BS', 'SR', 'EL']) {
      expect(find.text(sigla), findsWidgets, reason: 'sigla $sigla mancante');
    }
  });

  test('ogni area pilota ha una lingua', () {
    expect(pilotAreas.length, 8);
    for (final area in pilotAreas) {
      expect(area.languageBadge.length, 2, reason: area.id);
    }
  });
}
