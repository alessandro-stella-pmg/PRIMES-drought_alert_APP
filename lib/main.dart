import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config/api_config.dart';
import 'config/area_content.dart';
import 'config/pilot_areas.dart';
import 'l10n/app_localizations.dart';
import 'services/api_client.dart';
import 'services/app_prefs.dart';
import 'services/area_links.dart';
import 'services/push_service.dart';

// --- STATO GLOBALE ---

/// Allegati scaricati dalle notifiche. Parte vuoto: i documenti ufficiali
/// dell'area arrivano da `area_content.dart`, qui finisce solo cio' che
/// l'utente scarica.
final ValueNotifier<List<Map<String, String>>> archivioDocumenti =
    ValueNotifier([]);

void aggiungiDocumento(String nome, String dim) {
  bool esiste = archivioDocumenti.value.any((doc) => doc['nome'] == nome);
  if (!esiste) {
    archivioDocumenti.value = [
      {'nome': nome, 'dim': dim, 'data': 'Oggi'},
      ...archivioDocumenti.value,
    ];
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Storico degli avvisi. Si riempie con quelli veri del backend, via REST
/// all'avvio e via WebSocket/FCM mentre l'app e' aperta.
final ValueNotifier<List<AppNotification>> notificheSalvate = ValueNotifier([]);

class AlertLevelState {
  final String label;
  final Color color;
  const AlertLevelState(this.label, this.color);

  /// Stato iniziale: il livello vero lo sa solo il backend. Finche' non
  /// risponde non si puo' scrivere niente, e un'etichetta vuota fa mostrare
  /// alla card il testo tradotto "non disponibile".
  const AlertLevelState.unknown() : label = '', color = const Color(0xFF90A4AE);
}

Color _colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

final ValueNotifier<AlertLevelState> currentAlertLevel = ValueNotifier(
  const AlertLevelState.unknown(),
);

/// Traduce il livello che arriva dal backend nel nome che il referente
/// dell'area ha scritto nel form.
///
/// Il backend ragiona per chiavi (`none`, `level1`...) con etichette italiane
/// di servizio: mostrarle cosi' com'erano significava un'app croata che scrive
/// "Livello 2 - Allarme". Se l'area non e' configurata, o la chiave non si
/// riconosce, si mostra quello che manda il backend.
AlertLevelState _alertStateFrom({
  required String? key,
  required String label,
  required String colorHex,
}) {
  final level = areaLevelFor(
    areaId: selectedPilotArea.value?.id,
    key: key,
    backendLabel: label,
  );
  if (level != null) return AlertLevelState(level.name, level.color);
  return AlertLevelState(label, _colorFromHex(colorHex));
}

class AppNotification {
  final String title;
  final String body;
  final String time;
  final bool isUrgent;
  final String? attachmentName;
  bool isRead;

  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    this.isUrgent = false,
    this.attachmentName,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final timestamp =
        json['timestamp']?.toString() ?? DateTime.now().toIso8601String();
    return AppNotification(
      title: json['title']?.toString() ?? 'Notifica PRIMES',
      body: json['message']?.toString() ?? '',
      time: _formatTimestamp(timestamp),
      isUrgent: json['type']?.toString().toLowerCase() == 'emergency',
      attachmentName: json['extra'] is Map
          ? json['extra']['attachments']?.toString()
          : null,
      isRead: false,
    );
  }

  static String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }
}

void markAllNotificationsRead() {
  for (var item in notificheSalvate.value) {
    item.isRead = true;
  }
  notificheSalvate.value = [...notificheSalvate.value];
}

final AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
      'primes_alerts',
      'Avvisi PRIMES',
      description: 'Canale per le notifiche demo PRIMES.',
      importance: Importance.high,
      playSound: true,
    );

Future<void> initializeNotificationService() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
    macOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_notificationChannel);
}

Future<void> showLocalNotification(AppNotification notification) async {
  final NotificationDetails platformDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _notificationChannel.id,
      _notificationChannel.name,
      channelDescription: _notificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      ticker: 'Avviso PRIMES',
      color: const Color(0xFFD32F2F),
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      badgeNumber: notificheSalvate.value.where((n) => !n.isRead).length,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    platformDetails,
    payload: notification.title,
  );
}

/// Una push in arrivo diventa una notifica in elenco, come quelle del WebSocket.
void _handlePushMessage(PushMessage push) {
  final notif = AppNotification(
    title: push.title,
    body: push.body,
    time: AppNotification._formatTimestamp(push.receivedAt.toIso8601String()),
    isUrgent: push.isUrgent,
    attachmentName: push.documentName,
  );
  notificheSalvate.value = [notif, ...notificheSalvate.value];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.load();
  await initializeNotificationService();

  // FCM: canale affidabile, funziona anche ad app chiusa. Se Firebase non e'
  // configurato l'init non solleva e l'app resta usabile senza push.
  await PushService.init(onMessage: _handlePushMessage);
  final area = selectedPilotArea.value;
  if (area != null) await PushService.registerForArea(area.id);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const PrimesApp());
}

class PrimesApp extends StatelessWidget {
  const PrimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // L'area pilota scelta determina la lingua: cambiandola nel dropdown del
    // login l'intera app si ricostruisce tradotta.
    return ValueListenableBuilder<PilotArea?>(
      valueListenable: selectedPilotArea,
      builder: (context, area, _) => MaterialApp(
      title: 'PRIMES Drought-Alert',
      locale: area?.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          surface: Colors.transparent,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE1F5FE),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0D47A1),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0D47A1), size: 28),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      // MODIFICA: L'app ora parte dalla LoginScreen
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// --- LOGIN SCREEN (NUOVA SCHERMATA) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  PilotArea? _selectedArea;

  @override
  void initState() {
    super.initState();
    // Se l'utente aveva gia' scelto un'area, la ritroviamo preselezionata.
    _selectedArea = selectedPilotArea.value;
  }

  /// Selezionare l'area cambia subito la lingua dell'intera app.
  void _onAreaChanged(PilotArea? area) {
    setState(() => _selectedArea = area);
    if (area == null) return;
    AppPrefs.setArea(area);
    // Il server iscrive al topic della nuova zona e disiscrive dalla vecchia.
    PushService.registerForArea(area.id);
  }

  void _doLogin() {
    if (_formKey.currentState!.validate()) {
      // Simula il login e passa alla Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFF89F7FE), Color(0xFF66A6FF)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  SizedBox(
                    height: 100,
                    child: Image.asset(
                      'assets/PRIMES_MAP.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.t('login_welcome'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0D47A1),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 1. Selezione Zona (Dropdown)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: DropdownButtonFormField<PilotArea>(
                      initialValue: _selectedArea,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          Icons.location_on,
                          color: Color(0xFF0D47A1),
                        ),
                        labelText: l10n.t('login_select_area'),
                        labelStyle: const TextStyle(color: Colors.black54),
                      ),
                      isExpanded: true,
                      items: pilotAreas.map((PilotArea area) {
                        return DropdownMenuItem<PilotArea>(
                          value: area,
                          child: Row(
                            children: [
                              _LanguageBadge(code: area.languageBadge),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  area.displayName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onAreaChanged,
                      validator: (value) => value == null
                          ? l10n.t('login_select_area_error')
                          : null,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      l10n.t('login_language_hint'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Username
                  _buildTextField(
                    controller: _userController,
                    label: l10n.t('login_username'),
                    icon: Icons.person,
                    validator: (v) =>
                        v!.isEmpty ? l10n.t('login_username_error') : null,
                  ),

                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _passController,
                    label: l10n.t('login_password'),
                    icon: Icons.lock,
                    isPassword: true,
                    validator: (v) =>
                        v!.isEmpty ? l10n.t('login_password_error') : null,
                  ),

                  const SizedBox(height: 40),

                  // Bottone Login
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _doLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        l10n.t('login_button'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer Logo
                  SizedBox(
                    height: 120,
                    child: Image.asset(
                      'assets/Logo_interreg_PRIMES.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: validator,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.grey),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

/// Sigla della lingua (IT, HR, BS, SR, EL) mostrata accanto all'area pilota.
class _LanguageBadge extends StatelessWidget {
  final String code;
  const _LanguageBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF0D47A1).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }
}

// --- HOMEPAGE ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
    _connectWebSocket();
  }

  /// Stato iniziale letto dal backend: livello di allerta e storico avvisi.
  ///
  /// Senza questo l'app mostrerebbe i dati finti finche' non arriva un evento,
  /// e chi apre l'app dopo un cambio di livello vedrebbe quello sbagliato.
  Future<void> _loadFromBackend() async {
    final area = selectedPilotArea.value;
    if (area == null) return;
    try {
      final level = await ApiClient.alertLevel(area.id);
      if (!mounted) return;
      currentAlertLevel.value = _alertStateFrom(
        key: level.key,
        label: level.level,
        colorHex: level.colorHex,
      );
    } catch (e) {
      debugPrint('[api] livello non caricato: $e');
    }
    try {
      final list = await ApiClient.notifications(area.id, limit: 50);
      if (!mounted || list.isEmpty) return;
      notificheSalvate.value = list
          .map((n) => AppNotification.fromJson(n))
          .toList();
    } catch (e) {
      debugPrint('[api] notifiche non caricate: $e');
    }
  }

  void _connectWebSocket() {
    final area = selectedPilotArea.value;
    if (area == null || _disposed) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(backendWebSocketUrl(area.id)),
      );
      _wsSubscription = _channel!.stream.listen(
        _handleSocketEvent,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _reconnectAttempt = 0;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  /// Riconnessione con backoff esponenziale (2s, 4s, 8s... max 60s).
  ///
  /// Serve davvero: su Cloud Run la connessione ha comunque una durata massima
  /// pari al request timeout, quindi cade da sola anche quando tutto funziona.
  /// Senza riconnessione l'app resterebbe muta fino al riavvio.
  void _scheduleReconnect() {
    if (_disposed) return;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _channel = null;

    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 5);
    final delay = Duration(seconds: (1 << _reconnectAttempt).clamp(2, 60));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _connectWebSocket();
      // Al rientro lo stato puo' essere cambiato mentre eravamo scollegati.
      _loadFromBackend();
    });
  }

  void _handleSocketEvent(dynamic event) {
    try {
      final parsed = jsonDecode(event.toString()) as Map<String, dynamic>;
      if (parsed['event'] == 'notification') {
        final AppNotification notif = AppNotification.fromJson(
          Map<String, dynamic>.from(parsed['data'] as Map),
        );
        notificheSalvate.value = [notif, ...notificheSalvate.value];
        showLocalNotification(notif);
      } else if (parsed['event'] == 'alert_level_change') {
        final data = Map<String, dynamic>.from(parsed['data'] as Map);
        currentAlertLevel.value = _alertStateFrom(
          key: data['key']?.toString(),
          label: data['level']?.toString() ?? 'N/D',
          colorHex: data['colorHex']?.toString() ?? '#FF9800',
        );
      }
    } catch (_) {
      // ignore malformed websocket payloads
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _changeArea() async {
    await AppPrefs.clearArea();
    _disposed = true;
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _channel?.sink.close();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final area = selectedPilotArea.value;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFF89F7FE), Color(0xFF66A6FF)],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 24,
                  left: 8,
                  right: 8,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: SizedBox(
                        height: 90,
                        child: Center(
                          child: Image.asset(
                            'assets/PRIMES_MAP.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t('home_change_area'),
                      icon: const Icon(
                        Icons.travel_explore,
                        color: Color(0xFF0D47A1),
                      ),
                      onPressed: _changeArea,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  children: [
                    const SizedBox(height: 10),
                    // CARD IBRIDA
                    ValueListenableBuilder<AlertLevelState>(
                      valueListenable: currentAlertLevel,
                      builder: (context, alertState, _) {
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AlertGuidelinesScreen(),
                            ),
                          ),
                          child: AlertStatusCard(
                            // Finche' il backend non risponde non si inventa
                            // un livello: si dice che non e' disponibile.
                            level: alertState.label.isEmpty
                                ? l10n.t('alert_level_unknown')
                                : alertState.label,
                            color: alertState.color,
                            statusLabel: l10n.t('home_alert_status'),
                            // Se il referente ha indicato un nome ufficiale
                            // nel form, e' quello che vale per i cittadini.
                            zoneLabel: l10n.f('home_zone', {
                              'area':
                                  areaContentFor(area?.id)?.officialName ??
                                  area?.displayName ??
                                  '--',
                            }),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 60),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.2,
                      children: [
                        _buildModernMenuCard(
                          context,
                          l10n.t('menu_articles'),
                          Icons.article_outlined,
                          const ArticoliScreen(),
                        ),
                        ValueListenableBuilder<List<AppNotification>>(
                          valueListenable: notificheSalvate,
                          builder: (context, list, _) {
                            final count =
                                list.where((n) => !n.isRead).length;
                            return _buildModernMenuCard(
                              context,
                              l10n.t('menu_notifications'),
                              Icons.notifications_none_outlined,
                              const NotificheScreen(),
                              badgeCount: count,
                            );
                          },
                        ),
                        _buildModernMenuCard(
                          context,
                          l10n.t('menu_documents'),
                          Icons.folder_outlined,
                          const DocumentiScreen(),
                        ),
                        _buildModernMenuCard(
                          context,
                          l10n.t('menu_sos'),
                          Icons.support_agent_outlined,
                          const SosScreen(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // --- LOGO INSERITO QUI (FOOTER) ---
                    SizedBox(
                      height: 120,
                      child: Image.asset(
                        'assets/Logo_interreg_PRIMES.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget page, {
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: const Color(0xFF0D47A1)),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: 12,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- ALERT STATUS WIDGET ---
class AlertStatusCard extends StatelessWidget {
  final String level;
  final Color color;
  final String statusLabel;
  final String zoneLabel;
  const AlertStatusCard({
    super.key,
    required this.level,
    required this.color,
    required this.statusLabel,
    required this.zoneLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -30,
              child: Icon(
                Icons.water_drop,
                size: 180,
                color: color.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: color),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                          zoneLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DOCUMENTS SCREEN ---
//
// Archivio locale: i documenti arrivano dagli allegati scaricati dalle
// notifiche (e, per ora, dalla lista iniziale in `archivioDocumenti`).
class DocumentiScreen extends StatefulWidget {
  const DocumentiScreen({super.key});
  @override
  State<DocumentiScreen> createState() => _DocumentiScreenState();
}

class _DocumentiScreenState extends State<DocumentiScreen> {
  final Set<String> _selectedFiles = {};
  bool get _isSelectionMode => _selectedFiles.isNotEmpty;

  void _toggleSelection(String fileName) {
    setState(() {
      if (_selectedFiles.contains(fileName)) {
        _selectedFiles.remove(fileName);
      } else {
        _selectedFiles.add(fileName);
      }
    });
  }

  void _deleteSelected() {
    final l10n = AppLocalizations.of(context);
    final currentList = List<Map<String, String>>.from(archivioDocumenti.value);
    currentList.removeWhere((doc) => _selectedFiles.contains(doc['nome']));
    archivioDocumenti.value = currentList;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.f('documents_deleted', {'count': _selectedFiles.length}),
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      _selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isSelectionMode
            ? Colors.blueGrey[100]
            : const Color(0xFFE1F5FE),
        title: Text(
          _isSelectionMode
              ? l10n.f('documents_selected', {'count': _selectedFiles.length})
              : l10n.t('documents_title'),
          style: TextStyle(
            color: _isSelectionMode ? Colors.black87 : const Color(0xFF0D47A1),
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black87),
                onPressed: () => setState(() => _selectedFiles.clear()),
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 30,
              ),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, String>>>(
        valueListenable: archivioDocumenti,
        builder: (context, documenti, child) {
          // Due sorgenti distinte: i documenti ufficiali dell'area, che fanno
          // parte del bundle e non si cancellano, e gli allegati scaricati
          // dalle notifiche, che restano gestibili dall'utente.
          final areaDocs =
              areaContentFor(selectedPilotArea.value?.id)?.documents ??
              const <AreaDocument>[];

          if (areaDocs.isEmpty && documenti.isEmpty) {
            return _emptyState(l10n);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (areaDocs.isNotEmpty) ...[
                _sectionTitle(l10n.t('documents_area_section')),
                for (final doc in areaDocs) _areaDocCard(context, doc),
              ],
              if (documenti.isNotEmpty) ...[
                if (areaDocs.isNotEmpty) const SizedBox(height: 8),
                _sectionTitle(l10n.t('documents_downloads_section')),
                for (final doc in documenti) _downloadedDocCard(context, doc),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          l10n.t('documents_empty_title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t('documents_empty_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey[600],
      ),
    ),
  );

  /// Un documento ufficiale dell'area: si apre con il visualizzatore di
  /// sistema, non e' selezionabile ne' cancellabile.
  Widget _areaDocCard(BuildContext context, AreaDocument doc) {
    final l10n = AppLocalizations.of(context);
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.f('documents_opening', {'name': doc.title})),
              duration: const Duration(seconds: 2),
            ),
          );
          if (await AreaLinks.openDocument(doc)) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.f('documents_open_failed', {
                'name': doc.fileName,
              })),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: doc.isPdf ? Colors.red[50] : Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              doc.isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
              color: doc.isPdf
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF0D47A1),
              size: 32,
            ),
          ),
          title: Text(
            doc.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          subtitle: Text(
            l10n.f('documents_area_meta', {'size': doc.size}),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          trailing: const Icon(
            Icons.visibility,
            color: Color(0xFF0D47A1),
            size: 28,
          ),
        ),
      ),
    );
  }

  /// Un allegato scaricato da una notifica: selezionabile e cancellabile.
  Widget _downloadedDocCard(BuildContext context, Map<String, String> doc) {
    final l10n = AppLocalizations.of(context);
    final nome = doc['nome']!;
    final isSelected = _selectedFiles.contains(nome);

    return GestureDetector(
      onLongPress: () => _toggleSelection(nome),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(nome);
        } else {
          // Gli allegati delle notifiche non sono ancora scaricati su disco:
          // quando lo saranno, qui si aprira' il file come per i documenti
          // ufficiali dell'area.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.f('documents_opening', {'name': nome}))),
          );
        }
      },
      child: Card(
        color: isSelected ? Colors.blue[50] : Colors.white,
        elevation: isSelected ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? const BorderSide(color: Colors.blue, width: 2)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          leading: isSelected
              ? const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.check, color: Colors.white),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(0xFFD32F2F),
                    size: 32,
                  ),
                ),
          title: Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          subtitle: Text(
            l10n.f('documents_meta', {
              'size': doc['dim'] ?? '--',
              'date': doc['data'] ?? '--',
            }),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          trailing: _isSelectionMode
              ? null
              : const Icon(
                  Icons.visibility,
                  color: Color(0xFF0D47A1),
                  size: 28,
                ),
        ),
      ),
    );
  }
}

class NotificationDetailScreen extends StatelessWidget {
  final String title;
  final String body;
  final String time;
  final bool isUrgent;
  final String? attachmentName;
  const NotificationDetailScreen({
    super.key,
    required this.title,
    required this.body,
    required this.time,
    required this.isUrgent,
    this.attachmentName,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Color themeColor = isUrgent
        ? const Color(0xFFD32F2F)
        : const Color(0xFF0D47A1);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(l10n.t('notification_detail_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: themeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    isUrgent
                        ? l10n.t('notification_urgent')
                        : l10n.t('notification_info'),
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.3,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(height: 1),
            const SizedBox(height: 30),
            Text(
              body,
              style: const TextStyle(
                fontSize: 17,
                height: 1.6,
                color: Color(0xFF334155),
              ),
            ),
            if (attachmentName != null) ...[
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('notification_attachment_title'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                          size: 40,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                attachmentName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                "PDF • 1.2 MB",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          aggiungiDocumento(attachmentName!, "1.2 MB");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.t('notification_downloaded')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l10n.t('notification_download')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotificheScreen extends StatefulWidget {
  const NotificheScreen({super.key});
  @override
  State<NotificheScreen> createState() => _NotificheScreenState();
}

class _NotificheScreenState extends State<NotificheScreen> {
  void _markAsRead(AppNotification item) {
    if (!item.isRead) {
      item.isRead = true;
      notificheSalvate.value = [...notificheSalvate.value];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('notifications_title'))),
      body: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: notificheSalvate,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.t('notifications_empty_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.t('notifications_empty_body'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildItem(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildItem(BuildContext context, AppNotification item) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _markAsRead(item);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationDetailScreen(
                  title: item.title,
                  body: item.body,
                  time: item.time,
                  isUrgent: item.isUrgent,
                  attachmentName: item.attachmentName,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                stops: const [0.02, 0.02],
                colors: [
                  item.isUrgent ? const Color(0xFFD32F2F) : const Color(0xFF0D47A1),
                  Colors.white,
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.isUrgent
                                ? l10n.t('notification_urgent_short')
                                : l10n.t('notification_info_short'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: item.isUrgent
                                  ? Colors.red[800]
                                  : Colors.blue[800],
                            ),
                          ),
                          Text(
                            item.time,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      if (item.attachmentName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_file,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.t('notification_attachment_available'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- ARTICOLI SCREEN ---
class ArticoliScreen extends StatelessWidget {
  const ArticoliScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('articles_title')),
          bottom: TabBar(
            indicatorColor: const Color(0xFF0D47A1),
            labelColor: const Color(0xFF0D47A1),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: l10n.t('articles_tab_news')),
              Tab(text: l10n.t('articles_tab_board')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Notizie: per ora c'e' solo il portale del progetto. Gli articoli
            // veri arriveranno dal cruscotto, come le notifiche.
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPortalLinkCard(context),
                const SizedBox(height: 32),
                _emptyTab(
                  Icons.article_outlined,
                  l10n.t('articles_empty_news'),
                ),
              ],
            ),
            // Bacheca: le ordinanze in vigore si leggono nei livelli di
            // allerta e nei documenti ufficiali dell'area.
            _emptyTab(Icons.campaign_outlined, l10n.t('articles_empty_board')),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalLinkCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 4,
      shadowColor: Colors.blueAccent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF0D47A1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.t('portal_redirect')),
              backgroundColor: Colors.indigo,
              duration: const Duration(seconds: 2),
            ),
          );
          if (await AreaLinks.openUrl(primesPortalUrl)) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.f('link_failed', {'target': primesPortalUrl})),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.public, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('portal_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('portal_subtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Sezione senza contenuti: meglio dirlo che riempire con esempi finti.
  Widget _emptyTab(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    ),
  );
}

class AlertGuidelinesScreen extends StatelessWidget {
  const AlertGuidelinesScreen({super.key});

  /// Livelli generici, usati per le aree che non hanno ancora restituito il
  /// form di configurazione: restano quelli tradotti in `assets/i18n/`.
  List<AlertLevelInfo> _genericLevels(AppLocalizations l10n) => [
    AlertLevelInfo(
      name: l10n.t('alert_level_none'),
      rules: [l10n.t('alert_level_none_desc')],
      color: const Color(0xFF2E7D32),
    ),
    AlertLevelInfo(
      name: l10n.t('alert_level_1'),
      rules: [l10n.t('alert_level_1_desc')],
      color: const Color(0xFFF9A825),
    ),
    AlertLevelInfo(
      name: l10n.t('alert_level_2'),
      rules: [l10n.t('alert_level_2_desc')],
      color: const Color(0xFFEF6C00),
    ),
    AlertLevelInfo(
      name: l10n.t('alert_level_3'),
      rules: [l10n.t('alert_level_3_desc')],
      color: const Color(0xFFD32F2F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final area = selectedPilotArea.value;
    final content = areaContentFor(area?.id);
    final levels = content?.levels ?? _genericLevels(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('alert_levels_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.t('alert_levels_header'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            content?.officialName ?? l10n.t('alert_levels_intro'),
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
          ),
          const SizedBox(height: 25),
          for (final level in levels) _buildCard(level),
          if (content != null && content.permanentRules.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildPermanentCard(
              l10n.t('alert_levels_permanent'),
              content.permanentRules,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(AlertLevelInfo level) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: level.color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.water_drop, color: level.color, size: 28),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: level.color,
                ),
              ),
              const SizedBox(height: 8),
              for (final rule in level.rules) _bullet(rule, level.color),
            ],
          ),
        ),
      ],
    ),
  );

  /// Le regole valide sempre, a prescindere dal livello: stanno in fondo alla
  /// schermata perche' non appartengono a nessuno dei quattro livelli.
  Widget _buildPermanentCard(String title, List<String> rules) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE1F5FE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rule, color: Color(0xFF0D47A1), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final rule in rules) _bullet(rule, const Color(0xFF0D47A1)),
      ],
    ),
  );

  Widget _bullet(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  /// Recapiti generici, per le aree che non hanno ancora restituito il form.
  List<AreaContact> _genericContacts(AppLocalizations l10n) => [
    AreaContact(l10n.t('sos_emergency_line'), '112'),
    AreaContact.email(l10n.t('sos_fault_report'), 'emergency@primes.eu'),
  ];

  Future<void> _open(BuildContext context, AreaContact contact) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = contact.isEmail
        ? await AreaLinks.email(contact.value)
        : await AreaLinks.call(contact.value);
    if (ok) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.f('link_failed', {'target': contact.value})),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = areaContentFor(selectedPilotArea.value?.id);
    final contacts = content?.contacts.isNotEmpty == true
        ? content!.contacts
        : _genericContacts(l10n);
    final hours = content?.contactHours;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('sos_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final contact in contacts)
            _contact(
              contact.label,
              contact.value,
              contact.isEmail ? Icons.email : Icons.phone_in_talk,
              contact.isEmail ? Colors.orange : Colors.green,
              () => _open(context, contact),
            ),
          if (hours != null && hours.isNotEmpty) _hoursCard(l10n, hours),
        ],
      ),
    );
  }

  Widget _contact(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Card(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          subtitle: Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          trailing: Icon(
            icon == Icons.email ? Icons.open_in_new : Icons.call,
            color: color,
          ),
        ),
      ),
    ),
  );

  Widget _hoursCard(AppLocalizations l10n, String hours) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE1F5FE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.schedule, color: Color(0xFF0D47A1), size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('sos_hours'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 6),
              Text(hours, style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}
