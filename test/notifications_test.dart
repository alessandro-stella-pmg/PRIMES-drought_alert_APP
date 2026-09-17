import 'dart:convert';
import 'dart:io';

import 'package:app_primes/config/pilot_areas.dart';
import 'package:app_primes/l10n/app_localizations.dart';
import 'package:app_primes/main.dart';
import 'package:app_primes/services/auth_service.dart';
import 'package:app_primes/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('notifiche dal backend', () {
    test('il flag read del backend diventa isRead', () {
      final letta = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Letta',
        'message': 'corpo',
        'type': 'emergency',
        'timestamp': '2026-09-10T13:16:09.407Z',
        'read': true,
      });
      final nuova = AppNotification.fromJson({
        'id': 'n2',
        'title': 'Nuova',
        'message': 'corpo',
        'timestamp': '2026-09-10T13:16:09.407Z',
      });
      expect(letta.isRead, isTrue);
      expect(letta.isUrgent, isTrue);
      expect(nuova.isRead, isFalse);
      expect(nuova.key, 'n2');
    });

    test('push e storico della stessa notifica non si duplicano', () {
      notificheSalvate.value = [];
      final dalBackend = AppNotification.fromJson({
        'id': 'abc',
        'title': 'Avviso',
        'message': 'corpo',
        'timestamp': '2026-09-10T13:16:09.407Z',
      });
      mergeNotification(dalBackend);
      mergeNotification(
        AppNotification.fromPush(
          PushMessage.fromData({
            'id': 'abc',
            'title': 'Avviso',
            'message': 'corpo',
          }),
        ),
      );
      expect(notificheSalvate.value, hasLength(1));
      notificheSalvate.value = [];
    });
  });

  group('payload delle push', () {
    test('il tap su una notifica locale ritrova tutto il contenuto', () {
      final push = PushMessage.fromData({
        'id': 'n1',
        'type': 'emergency',
        'title': 'CALO DI PRESSIONE',
        'message': 'Interruzione dalle 14 alle 18.',
        'timestamp': '2026-09-10T13:16:09.407Z',
        'documentName': 'Avviso.pdf',
        'documentUrl': 'https://example.com/avviso.pdf',
      });
      // Il payload viaggia come stringa JSON nella notifica locale.
      final back = PushMessage.fromData(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(push.toData())) as Map),
      );
      expect(back.id, 'n1');
      expect(back.isUrgent, isTrue);
      expect(back.title, 'CALO DI PRESSIONE');
      expect(back.body, 'Interruzione dalle 14 alle 18.');
      expect(back.documentName, 'Avviso.pdf');
      expect(back.receivedAt, DateTime.parse('2026-09-10T13:16:09.407Z'));
    });

    test('titolo e testo della parte notification hanno la precedenza', () {
      final push = PushMessage.fromData(
        {'title': 'dal data', 'message': 'dal data'},
        title: 'dalla notifica',
        body: 'dalla notifica',
      );
      expect(push.title, 'dalla notifica');
      expect(push.body, 'dalla notifica');
    });
  });

  test('ogni errore di login ha un messaggio tradotto', () {
    final en =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final code in [
      'invalid-credential',
      'email-already-in-use',
      'account-exists-with-different-credential',
      'weak-password',
      'invalid-email',
      'user-disabled',
      'too-many-requests',
      'network-request-failed',
      'codice-mai-visto',
    ]) {
      final key = AuthService.messageKeyFor(code);
      expect(en.containsKey(key), isTrue, reason: '$code -> $key');
    }
    expect(en.containsKey('auth_unavailable'), isTrue);
    expect(en.containsKey('auth_google_unavailable'), isTrue);
  });

  group('schermata notifiche', () {
    AppNotification notifica(String id, {bool read = false}) =>
        AppNotification.fromJson({
          'id': id,
          'title': 'Avviso $id',
          'message': 'Corpo della notifica $id',
          'type': id == 'n1' ? 'emergency' : 'communication',
          'timestamp': '2026-09-10T13:16:09.407Z',
          'read': read,
        });

    Future<void> apri(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          home: NotificheScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    tearDown(() => notificheSalvate.value = []);

    testWidgets('mostra le notifiche, lette e da leggere', (tester) async {
      notificheSalvate.value = [notifica('n1'), notifica('n2', read: true)];
      await apri(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Avviso n1'), findsOneWidget);
      expect(find.text('Avviso n2'), findsOneWidget);
    });

    testWidgets('la pressione prolungata seleziona', (tester) async {
      notificheSalvate.value = [notifica('n1'), notifica('n2')];
      await apri(tester);

      await tester.longPress(find.text('Avviso n1'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  group('schermata di accesso', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('all\'apertura si sceglie tra accedi e registrati', (
      tester,
    ) async {
      await tester.pumpWidget(const PrimesApp());
      await tester.pumpAndSettle();

      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('REGISTER'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.byType(DropdownButtonFormField<PilotArea>), findsNothing);
    });

    testWidgets('l\'accesso chiede email e password, non l\'area', (
      tester,
    ) async {
      await tester.pumpWidget(const PrimesApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsNothing);
      expect(find.byType(DropdownButtonFormField<PilotArea>), findsNothing);
      expect(find.text('Sign in with Google'), findsOneWidget);

      // Indietro torna alla scelta.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('REGISTER'), findsOneWidget);
    });

    testWidgets('la registrazione chiede area pilota e password ripetuta', (
      tester,
    ) async {
      await tester.pumpWidget(const PrimesApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('REGISTER'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<PilotArea>), findsOneWidget);
      expect(
        find.text('The pilot area cannot be changed later.'),
        findsOneWidget,
      );
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Register with Google'), findsOneWidget);
    });

    testWidgets('email non valida e password diverse vengono segnalate', (
      tester,
    ) async {
      await tester.pumpWidget(const PrimesApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('REGISTER'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'non-una-email');
      await tester.enterText(fields.at(1), 'abc');
      await tester.enterText(fields.at(2), 'diversa');

      await tester.ensureVisible(find.text('CREATE ACCOUNT'));
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(find.text('The passwords do not match'), findsOneWidget);
      expect(find.text('Please select your area'), findsOneWidget);
    });
  });

  group('elimina account', () {
    testWidgets('senza email di conferma e spunta non si elimina', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          home: DeleteAccountScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'DELETE ACCOUNT PERMANENTLY'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
