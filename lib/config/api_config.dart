/// Indirizzo del backend PRIMES.
///
/// Si passa a compile time, cosi' la stessa build punta a locale o a Cloud Run
/// senza toccare il codice:
///
///   flutter run   --dart-define=BACKEND_URL=http://10.0.2.2:4000
///   flutter build apk --dart-define=BACKEND_URL=https://primes-backend-xxx.europe-west8.run.app
///
/// Nota: su emulatore Android `localhost` e' l'emulatore stesso, il PC e'
/// 10.0.2.2. Su dispositivo fisico serve l'IP del PC nella stessa rete.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://primes-backend-225520625301.europe-west8.run.app',
);

/// URL del WebSocket, derivato da [backendBaseUrl].
///
/// Il WebSocket serve solo ad aggiornare la schermata mentre l'app e' aperta:
/// la consegna affidabile passa da FCM. Se cade, non si perde nulla.
///
/// Attenzione in produzione: i rewrite di Firebase Hosting non supportano il
/// WebSocket, quindi qui va l'URL diretto di Cloud Run, non quello di Hosting.
String backendWebSocketUrl(String areaId) {
  final base = backendBaseUrl
      .replaceFirst(RegExp(r'^http://'), 'ws://')
      .replaceFirst(RegExp(r'^https://'), 'wss://');
  return '$base/ws?areaId=$areaId&role=app';
}

/// Portale web pubblico del progetto, aperto dalla card in "Articoli".
///
/// Anche questo si puo' sovrascrivere a compile time
/// (`--dart-define=PORTAL_URL=...`) senza toccare il codice.
const String primesPortalUrl = String.fromEnvironment(
  'PORTAL_URL',
  defaultValue: 'https://primes-drought.com/',
);
