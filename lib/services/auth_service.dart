import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Errore di autenticazione gia' tradotto in una chiave di `assets/i18n/`.
class AuthFailure implements Exception {
  final String messageKey;
  const AuthFailure(this.messageKey);
  @override
  String toString() => messageKey;
}

/// Login con Firebase Authentication: email e password, oppure Google.
///
/// Il login e' obbligatorio per ricevere qualsiasi notifica. La sessione la
/// conserva Firebase sul dispositivo: chiudendo e riaprendo l'app l'utente
/// resta dentro finche' non fa logout.
///
/// Non solleva se Firebase non e' inizializzato (test, build senza
/// google-services.json): l'utente risulta semplicemente non loggato.
class AuthService {
  /// Lunghezza minima imposta da Firebase Authentication.
  static const int minPasswordLength = 6;

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static FirebaseAuth? get _auth => isAvailable ? FirebaseAuth.instance : null;

  static User? get currentUser => _auth?.currentUser;

  static bool get isSignedIn => currentUser != null;

  /// Attende che Firebase abbia ripristinato la sessione salvata, cosi' chi era
  /// gia' loggato entra direttamente invece di vedere il form di login.
  static Future<void> ready() async {
    final auth = _auth;
    if (auth == null) return;
    try {
      await auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[auth] sessione non ripristinata: $e');
    }
  }

  /// L'email confermata e' la condizione per usare l'app: il backend incrocia
  /// quell'indirizzo con le liste dei destinatari degli operatori.
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// ID token da mandare al backend. Firebase lo rinnova da solo quando scade.
  static Future<String?> idToken() async {
    final user = currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  /// Le email di conferma e di reset arrivano nella lingua dell'area.
  static Future<void> setLanguage(String languageCode) async {
    await _auth?.setLanguageCode(languageCode);
  }

  static Future<User> signIn(String email, String password) =>
      _run((auth) async {
        final cred = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return cred.user!;
      });

  /// Crea l'account e manda subito l'email di conferma.
  static Future<User> register(String email, String password) =>
      _run((auth) async {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await cred.user!.sendEmailVerification();
        return cred.user!;
      });

  static bool _googleReady = false;

  static Future<void> _initGoogle() async {
    if (_googleReady) return;
    // Su Android l'ID client arriva da google-services.json: serve la
    // versione scaricata dopo aver attivato Google e inserito lo SHA-1.
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  /// Accesso con l'account Google. Restituisce null se l'utente chiude la
  /// scelta dell'account senza sceglierne uno.
  ///
  /// L'email di un account Google e' gia' confermata: si entra direttamente.
  static Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) throw const AuthFailure('auth_unavailable');
    try {
      await _initGoogle();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthFailure('auth_google_unavailable');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthFailure('auth_google_unavailable');
      final cred = await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return cred.user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('[auth] google ${e.code}: ${e.description}');
      final misconfigured =
          e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError;
      throw AuthFailure(
        misconfigured ? 'auth_google_unavailable' : 'auth_error_generic',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth] ${e.code}: ${e.message}');
      throw AuthFailure(messageKeyFor(e.code));
    }
  }

  static Future<void> sendPasswordReset(String email) =>
      _run((auth) => auth.sendPasswordResetEmail(email: email.trim()));

  static Future<void> resendVerification() => _run((auth) async {
    await auth.currentUser?.sendEmailVerification();
  });

  /// Ricarica l'utente per sapere se nel frattempo ha confermato l'email.
  ///
  /// Il token va rinnovato a forza: quello vecchio dice ancora
  /// `email_verified: false` e il backend lo respingerebbe.
  static Future<bool> reloadVerification() => _run((auth) async {
    final user = auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;
    await refreshed.getIdToken(true);
    return true;
  });

  static Future<void> signOut() async {
    if (!isAvailable) return;
    // Anche da Google: altrimenti al login successivo verrebbe riproposto lo
    // stesso account senza poterne scegliere un altro.
    try {
      await _initGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('[auth] logout Google non riuscito: $e');
    }
    await _auth?.signOut();
  }

  static Future<T> _run<T>(Future<T> Function(FirebaseAuth auth) action) async {
    final auth = _auth;
    if (auth == null) throw const AuthFailure('auth_unavailable');
    try {
      return await action(auth);
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth] ${e.code}: ${e.message}');
      throw AuthFailure(messageKeyFor(e.code));
    }
  }

  /// Dai codici di Firebase ai messaggi per l'utente.
  @visibleForTesting
  static String messageKeyFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return 'auth_error_invalid_credentials';
      case 'email-already-in-use':
        return 'auth_error_email_in_use';
      case 'account-exists-with-different-credential':
        return 'auth_error_account_exists';
      case 'weak-password':
        return 'auth_error_weak_password';
      case 'invalid-email':
        return 'auth_error_invalid_email';
      case 'user-disabled':
        return 'auth_error_disabled';
      case 'too-many-requests':
        return 'auth_error_too_many';
      case 'network-request-failed':
        return 'auth_error_network';
      default:
        return 'auth_error_generic';
    }
  }
}
