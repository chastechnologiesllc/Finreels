import 'package:flutter/foundation.dart';

/// Central configuration for Rumuo — by chAs Technologies LLC
class AppConfig {
  AppConfig._();

  static const String appName = 'Rumuo';
  static const String byLine = 'by chAs Technologies LLC';
  static const String company = 'chAs Technologies LLC';
  static const String packageName = 'com.chastechgroup.rumuo';

  // ── AdMob — PRODUCTION IDs (Android) ────────────────────────────────────────
  // Real ads are live via AdMob direct (no mediation). Ad unit IDs match the
  // units created in the AdMob console for the Rumuo app.
  static const bool kDebugAds = false;

  // ── AdSense (Flutter web) — TEST client/slot ────────────────────────────────
  // Official AdSense test publisher ID. Replace with your production ca-pub
  // and data-ad-slot before shipping. Set adsenseTestMode=false in production.
  static const String adsenseClientId = 'ca-pub-3940256099942544';
  static const String adsenseTestSlot = '6300978111';
  static const bool adsenseTestMode = true;

  // iOS production ad units below are TODO placeholders, not real AdMob
  // unit IDs. They previously mirrored the Android production ID, which is
  // invalid in AdMob (units are platform-specific) and was disabled/no-fill
  // risk. Create each iOS unit in AdMob and paste its real ID in place of
  // the REPLACE_WITH_… placeholder — until then, these will safely no-fill
  // rather than crash.
  static String get bannerAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-2492078126313994/7558254910')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'REPLACE_WITH_IOS_BANNER_AD_UNIT_ID');

  static String get interstitialAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-2492078126313994/6245173247')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'REPLACE_WITH_IOS_INTERSTITIAL_AD_UNIT_ID');

  static String get rewardedAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-2492078126313994/7037566074')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'REPLACE_WITH_IOS_REWARDED_AD_UNIT_ID');

  static String get rewardedInterstitialAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/5354046379'
          : 'ca-app-pub-2492078126313994/3749771769')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/6978759866'
          : 'REPLACE_WITH_IOS_REWARDED_INTERSTITIAL_AD_UNIT_ID');

  // Unused anywhere in the app today (no native ad widget calls this) —
  // fixed for consistency with the getters above, left in place in case
  // it's wired up later.
  static String get nativeAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-2492078126313994/4874437160')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/3986624511'
          : 'REPLACE_WITH_IOS_NATIVE_AD_UNIT_ID');

  // App Open ad unit — production unit created in AdMob.
  // Android unit ID: ca-app-pub-2492078126313994/4740519888
  // iOS: create a separate App Open unit in AdMob for iOS and paste its ID
  // into the iOS branch below (currently mirrors Android as a placeholder).
  static String? get appOpenAdUnitId {
    if (kDebugAds) {
      return defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/9257395921'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'ca-app-pub-2492078126313994/4740519888'
        : null; // TODO(dev): create iOS App Open unit and paste its ID here
  }

  // ── In-App Purchase Product IDs ──────────────────────────────────────────────
  static const String iapNoAds1Day    = 'rumuo_no_ads_1day';
  static const String iapNoAdsWeekly  = 'rumuo_no_ads_weekly';
  static const String iapNoAdsMonthly = 'rumuo_no_ads_monthly';

  static const Set<String> iapProductIds = {
    iapNoAds1Day,
    iapNoAdsWeekly,
    iapNoAdsMonthly,
  };

  // ── Paystack — fallback IAP for installs NOT from the Play Store ────────────
  // Google Play Billing only works reliably for apps installed through the
  // Play Store. For sideloaded APKs or installs from chastechgroup.com, the
  // app detects that at startup (see InstallSourceService) and uses this
  // Paystack flow instead — same products, same durations, different rail.
  //
  // This is the PUBLIC/publishable key — safe to ship inside the app, by
  // design (identical trust model to Stripe's `pk_*` keys). The Paystack
  // SECRET key must NEVER appear anywhere in this app's source; it belongs
  // only on a backend. A ready-to-deploy example backend for the optional
  // server-side verification step below lives in /server in this repo.
  static const String paystackPublicKey =
      'pk_live_d145dd30b0e40a54e3d2533dfc544e41ea63fe94';

  // Must match the currency your Paystack account actually settles in
  // (Paystack Dashboard → Settings → Preferences) or the popup will error.
  // Common values: NGN, GHS, ZAR, KES, USD.
  static const String paystackCurrency = 'NGN';

  // Amounts in the SMALLEST currency unit (kobo for NGN, pesewas for GHS,
  // cents for ZAR/KES/USD) — Paystack always expects subunits, never major
  // units. These intentionally do NOT auto-convert from the USD Play Store
  // prices above (a hardcoded FX rate would just go stale) — edit them
  // directly to your desired local pricing.
  static const Map<String, int> paystackAmounts = {
    iapNoAds1Day: 150000, // e.g. ₦1,500
    iapNoAdsWeekly: 450000, // e.g. ₦4,500
    iapNoAdsMonthly: 1200000, // e.g. ₦12,000
  };

  // Optional backend endpoint for server-side verification of a completed
  // Paystack reference: the app calls `GET {endpoint}/{reference}` and
  // expects back `{"verified": true|false}`. Leave empty to use interim
  // client-trust mode (the app grants ad-free directly off Paystack's own
  // success redirect, with no second server-side check). See CHECKLIST.md
  // → "Paystack Fallback" before shipping long-term with this left empty.
  static const String paystackVerifyEndpoint = '';

  // ── SharedPreferences Keys ───────────────────────────────────────────────────
  // ── In-app notification inbox ─────────────────────────────────────────────────
  /// JSON-encoded list of [NotificationItem] — written by both the background
  /// WorkManager isolate (via NotificationStore.appendToPrefsStatic) and the
  /// main isolate.
  static const String prefInAppNotifications = 'in_app_notifications';

  /// Persisted unread badge count — incremented by the background isolate,
  /// reset to 0 by the main isolate when the user opens the inbox.
  static const String prefNotifUnreadCount   = 'notif_unread_count';

  /// Maximum number of notification items kept in the inbox.
  static const int notifInboxMaxItems = 50;

  static const String prefAdsRemoved           = 'ads_removed';
  static const String prefAdsRemovedUntil      = 'ads_removed_until';
  static const String prefLastSeenVideos       = 'last_seen_videos_';
  static const String prefNotificationsEnabled = 'notifications_enabled';
  static const String prefSavedVideos          = 'saved_videos';
  static const String prefSavedBookmarks       = 'saved_bookmarks';
  static const String prefAdBlockChecked       = 'adblock_last_check_ms';
  static const String prefSelectedCategoryIds  = 'selected_resource_category_ids';
  static const String prefOnboardingComplete   = 'onboarding_complete';
  static const String prefChannelEngagement    = 'channel_engagement_scores';
  static const String prefCategoryEngagement   = 'category_engagement_scores';
  static const String prefEngagementDecayAt    = 'engagement_last_decay_ms';

  // ── Connectivity ─────────────────────────────────────────────────────────────
  static const List<String> connectivityEndpoints = [
    'https://www.gstatic.com/generate_204',
    'https://connectivitycheck.gstatic.com/generate_204',
    'https://clients3.google.com/generate_204',
    'https://www.google.com/favicon.ico',
  ];

  /// Browser-safe probes. Google generate_204 responses omit
  /// Access-Control-Allow-Origin, so XHR from github.io is blocked and
  /// every probe appears to fail → false "No internet". These endpoints
  /// return ACAO and work from a browser origin.
  static const List<String> connectivityEndpointsWeb = [
    'https://httpbin.org/status/204',
    'https://cloudflare.com/cdn-cgi/trace',
  ];

  // ── Ad-Block Detection ────────────────────────────────────────────────────────
  static const List<String> adCheckEndpoints = [
    'https://pagead2.googlesyndication.com/pagead/show_ads.js',
    'https://static.doubleclick.net/instream/ad_status.js',
    'https://adservice.google.com/adsid/google/ui',
    'https://tpc.googlesyndication.com/simgad/1',
  ];

  // ── Ad Frequency ─────────────────────────────────────────────────────────────
  /// Videos tab — fires on video OPEN (tap 4, 8, 12 …).
  static const int interstitialVideoEvery = 4;

  /// Video player — fires on play/pause TAP (tap 6, 12, 18 …).
  static const int interstitialVideoPlayPauseEvery = 6;

  /// Blog articles — fires on article OPEN (tap 4, 8, 12 …).
  static const int interstitialBlogEvery = 4;

  /// Books — fires on BookDetailScreen OPEN (tap 4, 8, 12 …).
  static const int interstitialBookEvery = 4;

  /// Books / blogs — fires on "Read" / "Continue Reading" tap (6, 12, 18 …).
  static const int interstitialBookReadEvery = 6;

  /// Channels page grid taps — every 12.
  static const int interstitialEveryNChannelsPage = 12;

  // Shared cycle for shorts thumbnail-taps and channel switching.
  // interstitialCycleLength = 4 → fires on tap 4, 8, 12 …
  static const int interstitialCycleLength = 4;

  // Shorts: show ad every N pages scrolled.
  static const int interstitialEveryNShorts = 4;

  // Legacy kept for onChannelSwitched path.
  static const int interstitialEveryNChannelSwitches = 4;
  static const Duration appOpenAdCooldown = Duration(hours: 2);

  // ── Background Task ───────────────────────────────────────────────────────────
  // Must match Info.plist → BGTaskSchedulerPermittedIdentifiers
  static const String rssCheckTaskId      = 'com.chastechgroup.rumuo.rsscheck';
  static const String rssCheckTaskName    = 'rssCheckTask';
  static const Duration rssCheckFrequency = Duration(minutes: 15);

  // ── Notification Channel ──────────────────────────────────────────────────────
  static const int    notifIdBase      = 1000;
  static const String notifChannelId   = 'rumuo_new_content';
  static const String notifChannelName = 'New Videos';
  static const String notifChannelDesc =
      'Get notified when your favourite channels post new content';
}
