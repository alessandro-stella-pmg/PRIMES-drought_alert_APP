import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// Notifica applicativa ricevuta da FCM.
@immutable
class PushMessage {
  /// Id della notifica nel backend: serve a non duplicarla nell'elenco e a
  /// segnarla come letta quando l'utente la apre.
  final String? id;
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
    this.id,
    this.documentUrl,
    this.documentName,
  });

  factory PushMessage.fromRemote(RemoteMessage message) {
    return PushMessage.fromData(
      message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  /// Il payload `data` che manda il backend (vedi push.js): e' anche quello
  /// che viaggia nelle notifiche locali, cosi' il tap porta allo stesso posto.
  factory PushMessage.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    String? text(String key) {
      final value = data[key]?.toString();
      return value == null || value.isEmpty ? null : value;
    }

    return PushMessage(
      id: text('id'),
      title: title ?? text('title') ?? 'PRIMES',
      body: body ?? text('message') ?? '',
      isUrgent: text('type') == 'emergency',
      documentUrl: text('documentUrl'),
      documentName: text('documentName'),
      receivedAt: DateTime.tryParse(text('timestamp') ?? '') ?? DateTime.now(),
    );
  }

  Map<String, String> toData() => {
    if (id != null) 'id': id!,
    'title': title,
    'message': body,
    'type': isUrgent ? 'emergency' : 'communication',
    'timestamp': receivedAt.toIso8601String(),
    if (documentUrl != null) 'documentUrl': documentUrl!,
    if (documentName != null) 'documentName': documentName!,
  };
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
/// FCM e' l'unico canale delle notifiche: consegna anche ad app chiusa e
/// raggiunge solo i dispositivi su cui un utente ha fatto login.
class PushService {
  static bool _initialised = false;
  static String? _token;

  static String? get token => _token;
  static bool get isReady => _initialised;

  /// Notifica toccata mentre l'app era chiusa: l'app si apre direttamente sul
  /// suo dettaglio appena l'utente e' dentro.
  static PushMessage? initialMessage;

  /// Inizializza Firebase e i gestori dei messaggi.
  ///
  /// [onMessage] riceve le notifiche con l'app in primo piano, [onOpened]
  /// quelle toccate dal pannello con l'app in background.
  ///
  /// Non solleva: se Firebase non e' configurato (manca google-services.json)
  /// l'app deve restare utilizzabile, semplicemente senza push.
  static Future<void> init({
    required void Function(PushMessage) onMessage,
    required void Function(PushMessage) onOpened,
  }) async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // iOS e Android 13+ richiedono il permesso esplicito. Su Android <13
      // la chiamata e' innocua e restituisce sempre "authorized".
      await messaging.requestPermission(alert: true, badge: true, sound: true);

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
        (m) => onOpened(PushMessage.fromRemote(m)),
      );

      final initial = await messaging.getInitialMessage();
      if (initial != null) initialMessage = PushMessage.fromRemote(initial);

      _token = await messaging.getToken();

      // Il token puo' cambiare (reinstallazione, ripristino, pulizia dati):
      // senza questo listener il dispositivo smetterebbe di ricevere avvisi
      // in silenzio, che e' il modo peggiore di rompersi.
      messaging.onTokenRefresh.listen((t) {
        // Al primo token dopo un logout l'evento arriva insieme alla
        // registrazione gia' in corso: stesso token, niente da rifare.
        if (t == _token && _registered == '$t|$_lastRegisteredArea') return;
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

  /// Ultima coppia token|area confermata dal backend, e quella in corso: la
  /// stessa registrazione chiesta due volte di fila parte una volta sola.
  static String? _registered;
  static Future<void>? _inFlight;
  static String? _inFlightKey;

  /// Comunica al backend token + area per l'utente loggato.
  ///
  /// Senza login non si registra nulla: il backend lo respingerebbe, e il
  /// dispositivo non deve ricevere notifiche.
  static Future<void> registerForArea(String areaId) async {
    if (!_initialised || !AuthService.isSignedIn) return;
    _lastRegisteredArea = areaId;
    try {
      // Dopo un logout il token e' stato cancellato: se ne chiede uno nuovo.
      final token = _token ??= await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final key = '$token|$areaId|${AuthService.currentUser?.uid}';
      if (_inFlightKey == key && _inFlight != null) return await _inFlight;
      _inFlightKey = key;
      _inFlight = ApiClient.registerDevice(
        token: token,
        areaId: areaId,
        platform: defaultTargetPlatform.name,
      );
      try {
        await _inFlight;
      } finally {
        _inFlight = null;
        _inFlightKey = null;
      }
      _registered = '$token|$areaId';
      debugPrint('[push] registrato per $areaId');
    } catch (e) {
      // Rete assente o backend giu': l'app funziona lo stesso, riproveremo al
      // prossimo avvio o al prossimo cambio area.
      debugPrint('[push] registrazione fallita: $e');
    }
  }

  /// Account eliminato: il backend ha gia' tolto i dispositivi, resta solo da
  /// cancellare il token FCM sul telefono.
  static Future<void> forget() async {
    _lastRegisteredArea = null;
    _registered = null;
    if (!_initialised) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] cancellazione token fallita: $e');
    }
    _token = null;
  }

  /// Da chiamare PRIMA del logout da Firebase, finche' c'e' ancora il token
  /// di accesso per dire al backend di togliere il dispositivo.
  ///
  /// Il token FCM viene poi cancellato: anche se il backend non fosse
  /// raggiungibile, quel token non riceverebbe piu' nulla.
  static Future<void> unregister() async {
    _lastRegisteredArea = null;
    _registered = null;
    if (!_initialised) return;
    final token = _token;
    if (token != null) {
      try {
        await ApiClient.unregisterDevice(token);
      } catch (e) {
        debugPrint('[push] rimozione dispositivo fallita: $e');
      }
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] cancellazione token fallita: $e');
    }
    _token = null;
  }
}
