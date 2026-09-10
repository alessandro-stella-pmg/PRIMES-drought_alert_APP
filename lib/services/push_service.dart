import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Notifica applicativa ricevuta da FCM.
@immutable
class PushMessage {
  final String title;
  final String body;
  final bool isUrgent;
  final String? documentUrl;
  final String? documentName;
  final DateTime receivedAt;

  const PushMessage({
    required this.title,
    required this.body,
    required this.isUrgent,
    required this.receivedAt,
    this.documentUrl,
    this.documentName,
  });

  factory PushMessage.fromRemote(RemoteMessage message) {
    final data = message.data;
    return PushMessage(
      title: message.notification?.title ?? data['title']?.toString() ?? 'PRIMES',
      body: message.notification?.body ?? data['message']?.toString() ?? '',
      isUrgent: data['type']?.toString() == 'emergency',
      documentUrl: data['documentUrl']?.toString(),
      documentName: data['documentName']?.toString(),
      receivedAt: DateTime.now(),
    );
  }
}

/// Handler per i messaggi che arrivano con l'app chiusa o in background.
///
/// Deve stare al livello superiore del file ed essere annotato: Flutter lo
/// esegue in un isolate separato, senza lo stato dell'app.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Il sistema mostra gia' la notifica: qui non serve altro. Il corpo resta
  // come punto di aggancio se in futuro servira' salvare qualcosa su disco.
}

/// Integrazione Firebase Cloud Messaging.
///
/// FCM e' il canale affidabile: consegna anche ad app chiusa, che per un
/// sistema di allerta siccita' e' il caso che conta davvero. Il WebSocket
/// aggiorna solo la schermata mentre l'app e' aperta.
class PushService {
  static bool _initialised = false;
  static String? _token;

  static String? get token => _token;
  static bool get isReady => _initialised;

  /// Inizializza Firebase e i gestori dei messaggi.
  ///
  /// Non solleva: se Firebase non e' configurato (manca google-services.json)
  /// l'app deve restare utilizzabile, semplicemente senza push.
  static Future<void> init({
    required void Function(PushMessage) onMessage,
  }) async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // iOS e Android 13+ richiedono il permesso esplicito. Su Android <13
      // la chiamata e' innocua e restituisce sempre "authorized".
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Con l'app in primo piano iOS non mostra nulla di default: senza questa
      // riga una notifica che arriva mentre l'utente guarda l'app sparirebbe.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(
        (m) => onMessage(PushMessage.fromRemote(m)),
      );
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => onMessage(PushMessage.fromRemote(m)),
      );

      _token = await messaging.getToken();

      // Il token puo' cambiare (reinstallazione, ripristino, pulizia dati):
      // senza questo listener il dispositivo smetterebbe di ricevere avvisi
      // in silenzio, che e' il modo peggiore di rompersi.
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        final areaId = _lastRegisteredArea;
        if (areaId != null) registerForArea(areaId);
      });

      _initialised = true;
      debugPrint('[push] FCM pronto, token ${_token?.substring(0, 12)}...');
    } catch (e) {
      debugPrint('[push] FCM non disponibile: $e');
    }
  }

  static String? _lastRegisteredArea;

  /// Comunica al backend token + area, cosi' il server iscrive al topic giusto.
  static Future<void> registerForArea(String areaId) async {
    _lastRegisteredArea = areaId;
    final token = _token;
    if (token == null) return;
    try {
      await ApiClient.registerDevice(
        token: token,
        areaId: areaId,
        platform: defaultTargetPlatform.name,
      );
      debugPrint('[push] registrato per $areaId');
    } catch (e) {
      // Rete assente o backend giu': l'app funziona lo stesso, riproveremo al
      // prossimo avvio o al prossimo cambio area.
      debugPrint('[push] registrazione fallita: $e');
    }
  }
}
