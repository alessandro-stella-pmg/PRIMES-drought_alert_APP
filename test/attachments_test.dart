import 'package:app_primes/config/api_config.dart';
import 'package:app_primes/l10n/app_localizations.dart';
import 'package:app_primes/main.dart';
import 'package:app_primes/services/attachments.dart';
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
          attachmentName: 'DOC_PRIMES.pdf',
          documentUrl: '$backendBaseUrl/api/areas/it-marche/documents/a/file',
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
      const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        home: NotificationDetailScreen(
          title: 'Avviso',
          body: 'Testo',
          time: '2026-09-14 15:00',
          isUrgent: false,
          attachmentName: 'DOC_PRIMES.pdf',
          documentUrl: url,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OPEN DOCUMENT'), findsOneWidget);
    expect(find.text('40 KB'), findsOneWidget);
    archivioDocumenti.value = [];
  });
}
