import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects whether this install came from the Google Play Store, so the
/// app can pick the right purchase rail:
///   • Play Store install  → Google Play Billing (lib/services/iap_service.dart)
///   • anything else        → Paystack fallback (same products, same
///                            durations, different payment rail)
///
/// Play Billing only works reliably for apps installed through the Play
/// Store, so this check runs once at startup and the result is cached —
/// it's a deliberate, lightweight signal, not a tamper-proof integrity
/// check.
class InstallSourceService {
  InstallSourceService._();
  static final InstallSourceService instance = InstallSourceService._();

  static const MethodChannel _channel =
      MethodChannel('com.chastechgroup.finreels/install_source');
  static const String _playStorePackage = 'com.android.vending';

  bool? _cachedIsPlayStore;

  /// Web: not a Play Store install (no Play Billing).
  /// iOS: App Store only — treat as available so StoreKit path can run on mobile.
  /// Android: query installer package name via platform channel.
  ///
  /// Uses [defaultTargetPlatform] instead of dart:io [Platform] so this file
  /// is safe to compile and run on web.
  Future<bool> isPlayStoreInstall() async {
    if (kIsWeb) {
      _cachedIsPlayStore = false;
      return false;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      _cachedIsPlayStore = true;
      return true;
    }
    if (_cachedIsPlayStore != null) return _cachedIsPlayStore!;

    try {
      final installer =
          await _channel.invokeMethod<String>('getInstallerPackageName');
      _cachedIsPlayStore = installer == _playStorePackage;
    } on Object {
      // Channel or platform failure — fail closed to the Paystack fallback
      // rather than risk handing the user a Play Billing flow that has
      // nothing real to talk to.
      _cachedIsPlayStore = false;
    }
    return _cachedIsPlayStore!;
  }
}
