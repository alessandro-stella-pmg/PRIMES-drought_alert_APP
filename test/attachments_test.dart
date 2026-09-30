import 'package:app_primes/config/api_config.dart';
import 'package:app_primes/l10n/app_localizations.dart';
import 'package:app_primes/main.dart';
import 'package:app_primes/services/attachments.dart';
import 'package:app_primes/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('da dove si scaricano gli allegati', () {
    test('link del backend PRIMES accettati, anche relativi', () {
      final full = '$backendBaseUrl/api/areas/it-marche/documents/abc/file';
      expect(Attachments.resolveUrl(full).toString(), full);
      expect(
        Attachments.resolveUrl(
          '/api/areas/it-marche/documents/abc/file',
        ).toString(),
        full,
      );
    });

    test('link verso altri siti rifiutati', () {
      expect(Attachments.resolveUrl('https://example.com/virus.apk'), isNull);
      expect(
        Attachments.resolveUrl(
          backendBaseUrl.replaceFirst('https://', 'http://'),
        ),
        isNull,
      );
    });
  });

  test('nomi di file sicuri', () {
    expect(Attachments.safeFileName('Avviso.pdf'), 'Avviso.pdf');
    expect(Attachments.safeFileName('../../etc/passwd'), 'passwd');
    expect(Attachments.safeFileName(r'C:\temp\a:b?.pdf'), 'a_b_.pdf');
    expect(Attachments.safeFileName('   '), 'documento');
  });

  test('dimensioni leggibili', () {
    expect(Attachments.readableSize(512), '512 B');
    expect(Attachments.readableSize(40731), '40 KB');
    expect(Attachments.readableSize(3 * 1024 * 1024), '3.0 MB');
  });

  test('icona dal tipo di file', () {
    expect(fileIconFor('DOC_PRIMES.pdf').$1, Icons.picture_as_pdf);
    expect(fileIconFor('foto.JPG').$1, Icons.image_outlined);
    expect(fileIconFor('dati.xlsx').$1, Icons.table_chart_outlined);
    expect(fileIconFor('PIANO.md').$1, Icons.description_outlined);
  });

  testWidgets('il dettaglio con allegato offre il download', (tester) async {
    archivioDocumenti.value = [];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: NotificationDetailScreen(
          title: 'Avviso',
          body: 'Testo',
          time: '2026-09-14 15:00',
          isUrgent: true,
          attachments: const [
            NotificationAttachment(
              name: 'DOC_PRIMES.pdf',
              url: '$backendBaseUrl/api/areas/it-marche/documents/a/file',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DOC_PRIMES.pdf'), findsOneWidget);
    expect(find.text('DOWNLOAD DOCUMENT'), findsOneWidget);
    // La dimensione finta "1.2 MB" della vecchia demo non c'e' piu'.
    expect(find.textContaining('1.2 MB'), findsNothing);
  });

  testWidgets('se gia\' scaricato il pulsante apre il documento', (
    tester,
  ) async {
    const url = '$backendBaseUrl/api/areas/it-marche/documents/a/file';
    archivioDocumenti.value = [
      {
        'nome': 'DOC_PRIMES.pdf',
        'dim': '40 KB',
        'data': '14/09/2026',
        'path': '/non/esiste.pdf',
        'url': url,
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: NotificationDetailScreen(
          title: 'Avviso',
          body: 'Testo',
          time: '2026-09-14 15:00',
          isUrgent: false,
          attachments: [
            NotificationAttachment(name: 'DOC_PRIMES.pdf', url: url),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPEN DOCUMENT'), findsOneWidget);
    expect(find.text('40 KB'), findsOneWidget);
    archivioDocumenti.value = [];
  });

  testWidgets('il dettaglio elenca tutti gli allegati', (tester) async {
    archivioDocumenti.value = [];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: NotificationDetailScreen(
          title: 'Avviso',
          body: 'Testo',
          time: '2026-09-14 15:00',
          isUrgent: false,
          attachments: const [
            NotificationAttachment(
              name: 'PRIMO.pdf',
              url: '$backendBaseUrl/api/areas/it-marche/documents/a/file',
            ),
            NotificationAttachment(
              name: 'SECONDO.xlsx',
              url: '$backendBaseUrl/api/areas/it-marche/documents/b/file',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIMO.pdf'), findsOneWidget);
    expect(find.text('SECONDO.xlsx'), findsOneWidget);
    // Un pulsante per allegato: si scaricano uno alla volta.
    expect(find.text('DOWNLOAD DOCUMENT'), findsNWidgets(2));
  });

  group('allegati nel payload della notifica', () {
    test('la lista arriva dal campo documents', () {
      final notifica = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Avviso',
        'message': 'Testo',
        'timestamp': '2026-09-30T10:00:00.000Z',
        'documents': [
          {'name': 'PRIMO.pdf', 'url': '$backendBaseUrl/a'},
          {'name': 'SECONDO.xlsx', 'url': '$backendBaseUrl/b'},
        ],
      });
      expect(notifica.attachments.length, 2);
      expect(notifica.attachments.first.name, 'PRIMO.pdf');
      expect(notifica.firstAttachment?.url, '$backendBaseUrl/a');
    });

    test('una notifica vecchia porta comunque il suo allegato', () {
      final notifica = AppNotification.fromJson({
        'id': 'n2',
        'title': 'Avviso',
        'message': 'Testo',
        'timestamp': '2026-09-30T10:00:00.000Z',
        'documentUrl': '$backendBaseUrl/a',
        'extra': {'attachments': 'VECCHIO.pdf'},
      });
      expect(notifica.attachments.length, 1);
      expect(notifica.attachments.first.name, 'VECCHIO.pdf');
    });

    test('senza allegati la lista e\' vuota, non un elemento a vuoto', () {
      final notifica = AppNotification.fromJson({
        'id': 'n3',
        'title': 'Avviso',
        'message': 'Testo',
        'timestamp': '2026-09-30T10:00:00.000Z',
        'extra': {'attachments': null},
      });
      expect(notifica.attachments, isEmpty);
      expect(notifica.firstAttachment, isNull);
    });

    test('dal push la lista viaggia come JSON', () {
      final push = PushMessage.fromData({
        'id': 'n4',
        'title': 'Avviso',
        'message': 'Testo',
        'timestamp': '2026-09-30T10:00:00.000Z',
        'documentName': 'PRIMO.pdf',
        'documentUrl': '$backendBaseUrl/a',
        'documentCount': '2',
        'documents':
            '[{"name":"PRIMO.pdf","url":"$backendBaseUrl/a"},'
            '{"name":"SECONDO.xlsx","url":"$backendBaseUrl/b"}]',
      });
      expect(push.attachments.length, 2);
      expect(push.attachments.last.name, 'SECONDO.xlsx');
      // Se la lista non ci sta nel payload resta il primo allegato.
      final ridotto = PushMessage.fromData({
        'id': 'n5',
        'title': 'Avviso',
        'message': 'Testo',
        'documentName': 'PRIMO.pdf',
        'documentUrl': '$backendBaseUrl/a',
        'documentCount': '7',
      });
      expect(ridotto.attachments.length, 1);
      expect(ridotto.attachments.first.name, 'PRIMO.pdf');
    });
  });
}
