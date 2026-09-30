import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Senza queste due righe iOS non chiede mai il token APNs ad Apple, quindi
    // FCM non ha nulla da mappare e getToken() non restituisce un token
    // utilizzabile: il dispositivo non si registra e nessuna notifica arriva.
    // Non basta chiedere il permesso all'utente dal lato Dart.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
