import UIKit
import Flutter
import GoogleMobileAds
import workmanager_apple

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // workmanager_apple 0.9.3 auto-registers persisted BGTask launch
        // handlers during plugin initialization; no newer API is required here.

        // Make other plugins (shared_preferences, flutter_local_notifications,
        // http, etc.) available inside the Workmanager background isolate.
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        GeneratedPluginRegistrant.register(with: self)
        // Google Mobile Ads SDK initialised via Flutter plugin
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Delegate per-screen orientation locking to Flutter's
    /// SystemChrome.setPreferredOrientations(). Without this override iOS
    /// ignores runtime orientation requests and locks the whole app to the
    /// orientations listed in UISupportedInterfaceOrientations, making the
    /// video-player landscape toggle a silent no-op.
    override func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .all
    }
}
