import UIKit
import Flutter
import GoogleMobileAds
import workmanager_apple

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var nativeLaunchOverlay: UIView?
    private var nativeLaunchChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // workmanager_apple 0.9.3 auto-registers persisted BGTask launch
        // handlers during plugin initialization; no newer API is required here.
        WorkmanagerPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        GeneratedPluginRegistrant.register(with: self)
        let launched = super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        showNativeLaunchOverlay()
        return launched
    }

    private func showNativeLaunchOverlay() {
        guard let flutterViewController = window?.rootViewController as? FlutterViewController,
              let rootView = flutterViewController.view else { return }

        let overlay = UIView(frame: rootView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.transform = CGAffineTransform(translationX: 0, y: -36)
        overlay.addSubview(stack)

        let mark = UIImageView(image: UIImage(named: "LaunchImage"))
        mark.contentMode = .scaleAspectFit
        mark.clipsToBounds = true
        mark.layer.cornerRadius = 26
        mark.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(mark)

        let name = UILabel()
        name.text = "Rumuo"
        name.textAlignment = .center
        name.textColor = .label
        name.font = .systemFont(ofSize: 38, weight: .bold)
        stack.addArrangedSubview(name)

        let status = UILabel()
        status.text = "Opening your discovery space…"
        status.textAlignment = .center
        status.textColor = UIColor(red: 240.0 / 255.0, green: 170.0 / 255.0, blue: 29.0 / 255.0, alpha: 1)
        status.font = .systemFont(ofSize: 14, weight: .medium)
        stack.addArrangedSubview(status)

        let byline = UILabel()
        byline.text = "by chAs"
        byline.textAlignment = .center
        byline.textColor = .label
        byline.font = .systemFont(ofSize: 16, weight: .semibold)
        byline.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(byline)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            mark.widthAnchor.constraint(equalToConstant: 96),
            mark.heightAnchor.constraint(equalToConstant: 96),
            byline.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            byline.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -40),
        ])

        rootView.addSubview(overlay)
        nativeLaunchOverlay = overlay

        let channel = FlutterMethodChannel(
            name: "com.chastechgroup.rumuo/native_launch",
            binaryMessenger: flutterViewController.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "ready" {
                self?.hideNativeLaunchOverlay()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        nativeLaunchChannel = channel
    }

    private func hideNativeLaunchOverlay() {
        nativeLaunchOverlay?.removeFromSuperview()
        nativeLaunchOverlay = nil
        nativeLaunchChannel = nil
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
