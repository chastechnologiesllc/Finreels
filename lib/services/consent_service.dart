import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google's User Messaging Platform (UMP) SDK — GDPR/UK/Swiss consent flow.
///
/// Required by AdMob policy for any app that could serve ads to EEA/UK/
/// Swiss users — which is any globally-distributed app. This was
/// previously entirely unimplemented: AndroidManifest.xml already had
/// `DELAY_APP_MEASUREMENT_INIT` set (anticipating exactly this flow), but
/// nothing on the Dart side ever actually requested or showed a consent
/// form. Every user was seeing personalised ads with no consent gathered.
///
/// Must run to completion BEFORE MobileAds.instance.initialize() — see
/// AdService.init(), which now calls this first. Pattern matches Google's
/// own official Flutter integration guide exactly:
/// https://developers.google.com/admob/flutter/privacy
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  /// Requests the latest consent status from Google and, if required for
  /// this user's detected region, shows the consent form. Resolves once
  /// the flow is fully done — whether a form was actually shown or not
  /// (most users outside EEA/UK/Switzerland will see nothing, and this
  /// resolves near-instantly for them).
  ///
  /// Defensively time-boxed: a UMP network hiccup (e.g. briefly offline at
  /// cold start) must never be able to strand the splash screen forever —
  /// matching the same defensive pattern already used for every other
  /// service in main.dart's startup sequence. On timeout or any error,
  /// this simply resolves and ads proceed using Google's own safe
  /// default (non-personalised where required) behaviour for that
  /// session; the flow retries fresh on the next app launch.
  Future<void> requestAndLoadConsent() async {
    final completer = Completer<void>();

    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('[consent] loadAndShowConsentFormIfRequired: '
                  '${formError.errorCode}: ${formError.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        },
        (FormError error) {
          debugPrint('[consent] requestConsentInfoUpdate failed: '
              '${error.errorCode}: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } on Object catch (e) {
      debugPrint('[consent] unexpected error: $e');
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('[consent] flow exceeded 5s ceiling — continuing.');
      },
    );
  }

  /// Whether a "Privacy Options" entry point must be shown somewhere in
  /// the app's UI so EEA/UK/Swiss users can revisit their consent choice
  /// at any time — this is a Google UMP policy requirement, not optional,
  /// for any app whose users might see the initial consent form. Wired to
  /// a Settings entry — see SettingsScreen.
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Re-opens the consent/privacy management form.
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null) {
        debugPrint('[consent] privacy options form error: '
            '${formError.errorCode}: ${formError.message}');
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }
}
