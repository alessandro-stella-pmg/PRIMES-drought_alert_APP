import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/area_content.dart';

/// Aperture verso il mondo esterno: portale web, telefonate, email e
/// documenti ufficiali dell'area.
///
/// Tutti i metodi restituiscono `false` invece di sollevare: se sul dispositivo
/// manca l'app capace di gestire il link (nessun client di posta, tablet senza
/// modulo telefonico, nessun lettore PDF) la schermata mostra un avviso e
/// l'utente resta dov'era.
class AreaLinks {
  const AreaLinks._();

  /// Apre un URL **dentro l'app**, in Custom Tab (Android) o
  /// SFSafariViewController (iOS).
  ///
  /// Non e' un dettaglio estetico: App Store e Play Store contestano le app
  /// che si limitano a rimbalzare l'utente sul browser esterno. La vista
  /// integrata resta il browser di sistema — stessa sandbox, stessa barra
  /// dell'indirizzo — ma con il pulsante per tornare indietro nell'app.
  static Future<bool> openUrl(String url) =>
      _launch(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

  /// Avvia una telefonata verso [phone].
  ///
  /// Spazi e trattini vanno tolti: `tel:` accetta solo cifre, `+` e `*#`.
  static Future<bool> call(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+*#]'), '');
    return _launch(Uri(scheme: 'tel', path: digits));
  }

  /// Apre il client di posta con il destinatario gia' compilato.
  static Future<bool> email(String address) =>
      _launch(Uri(scheme: 'mailto', path: address));

  /// Apre un documento dell'area con il visualizzatore di sistema.
  ///
  /// Gli asset del bundle non sono file veri sul filesystem, quindi non si
  /// possono passare a un'altra app: vanno prima estratti nella cache. La copia
  /// avviene una sola volta, ai passaggi successivi si riusa il file gia'
  /// scritto.
  static Future<bool> openDocument(AreaDocument doc) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/primes_docs/${doc.fileName}');
      if (!await file.exists()) {
        await file.parent.create(recursive: true);
        final bytes = await rootBundle.load(doc.asset);
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      }
      final result = await OpenFilex.open(file.path);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[docs] apertura di ${doc.fileName} fallita: $e');
      return false;
    }
  }

  /// [mode] resta `externalApplication` per `tel:` e `mailto:`, che devono
  /// arrivare al telefono e al client di posta veri.
  static Future<bool> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('[link] apertura di $uri fallita: $e');
      return false;
    }
  }
}
