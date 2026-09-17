import 'package:app_primes/config/api_config.dart';
import 'package:app_primes/services/area_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  // Se uno di questi test diventa rosso, l'app sta rimbalzando l'utente sul
  // browser di sistema: e' il motivo per cui App Store e Play Store bloccano
  // una pubblicazione, non un dettaglio di stile.
  group('come si aprono i link', () {
    test("gli indirizzi web restano dentro l'app", () {
      for (final url in [
        'https://primes-drought.com/',
        'http://esempio.eu/pagina?a=1',
        'https://primes-drought.com/notizie#sezione',
      ]) {
        expect(
          AreaLinks.launchModeFor(Uri.parse(url)),
          LaunchMode.inAppBrowserView,
          reason: url,
        );
      }
    });

    test("il portale configurato resta dentro l'app", () {
      expect(
        AreaLinks.launchModeFor(Uri.parse(primesPortalUrl)),
        LaunchMode.inAppBrowserView,
        reason: primesPortalUrl,
      );
    });

    test('telefono ed email escono, come devono', () {
      expect(
        AreaLinks.launchModeFor(Uri(scheme: 'tel', path: '112')),
        LaunchMode.externalApplication,
      );
      expect(
        AreaLinks.launchModeFor(Uri(scheme: 'mailto', path: 'a@b.it')),
        LaunchMode.externalApplication,
      );
    });
  });
}
