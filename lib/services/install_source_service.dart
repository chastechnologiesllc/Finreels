import 'dart:io';

import 'package:flutter/services.dart';

/// Detects whether this install came from the Google Play Store, so the
/// app can pick the right purchase rail:
///   • Play Store install  → Google Play Billing (lib/services/iap_service.dart)
///   • anything else        → Paystack fallback (same products, same
///                            durations, different payment rail — see
///                            IapService.purchaseViaPaystack)
///
/// Play Billing only works reliably for apps installed through the Play
/// Store, so this check runs once at startup and the result is cached —
/// it's a deliberate, lightweight signal, not a tamper-proof integrity
/// check (Play Integrity API exists for that and is a heavier lift; this
/// is enough to route to the right checkout, which is all that's needed
/// here).
class InstallSourceService {
  InstallSourceService._();
  static final InstallSourceService instance = InstallSourceService._();

  static const MethodChannel _channel =
      MethodChannel('com.chastechgroup.finreels/install_source');
  static const String _playStorePackage = 'com.android.vending';

  bool? _cachedIsPlayStore;

  /// iOS has no equivalent ambiguity — the App Store is the only realistic
  /// distribution channel, so standard StoreKit IAP always applies there.
  Future<bool> isPlayStoreInstall() async {
    if (!Platform.isAndroid) return true;
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
