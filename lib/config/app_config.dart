import 'package:flutter/foundation.dart';

/// Central configuration for FinReels — by chAs Tech Group
class AppConfig {
  AppConfig._();

  static const String appName = 'FinReels';
  static const String byLine = 'by chAs';
  static const String company = 'chAs Tech Group';
  static const String packageName = 'com.chastechgroup.finreels';

  // ── AdMob — PRODUCTION IDs (Android) ────────────────────────────────────────
  // Real ads are now live: AdMob direct + Unity Ads mediation (configured
  // via the AdMob mediation dashboard — see android/app/build.gradle for
  // the native Unity Ads SDK + adapter dependencies that make Unity Ads
  // actually able to serve impressions through that mediation group).
  static const bool kDebugAds = false;

  static String get admobAppId => defaultTargetPlatform == TargetPlatform.android
      ? 'ca-app-pub-2492078126313994\~7729948254'
      : 'ca-app-pub-2492078126313994\~7729948254';

  static String get bannerAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-2492078126313994/9210550883')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-2492078126313994/9210550883');

  static String get interstitialAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-2492078126313994/2175580693')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-2492078126313994/2175580693');

  static String get rewardedAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-2492078126313994/3017889074')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-2492078126313994/3017889074');

  static String get rewardedInterstitialAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/5354046379'
          : 'ca-app-pub-2492078126313994/5422743877')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/6978759866'
          : 'ca-app-pub-2492078126313994/5422743877');

  static String get nativeAdUnitId => defaultTargetPlatform == TargetPlatform.android
      ? (kDebugAds
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-2492078126313994/1332060862')
      : (kDebugAds
          ? 'ca-app-pub-3940256099942544/3986624511'
          : 'ca-app-pub-2492078126313994/1332060862');

  // App Open ad unit — production unit now created in AdMob.
  // Android unit ID: ca-app-pub-2492078126313994/7947671149
  // iOS: create a separate App Open unit in AdMob for iOS and paste its ID
  // into the iOS branch below (currently mirrors Android as a placeholder).
  static String? get appOpenAdUnitId {
    if (kDebugAds) {
      return defaultTargetPlatform == TargetPlatform.android
          ? 'ca-app-pub-3940256099942544/9257395921'
          : 'ca-app-pub-3940256099942544/5575463023';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'ca-app-pub-2492078126313994/7947671149'
        : null; // TODO(dev): create iOS App Open unit and paste its ID here
  }

  // ── In-App Purchase Product IDs ──────────────────────────────────────────────
  static const String iapNoAds1Day    = 'finreels_no_ads_1day';
  static const String iapNoAdsWeekly  = 'finreels_no_ads_weekly';
  static const String iapNoAdsMonthly = 'finreels_no_ads_monthly';

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

  /// Free public JSONP-capable RSS→JSON bridge used only on web (CORS).
  /// Native Android/iOS never use this — they fetch YouTube/blog RSS directly.
  static const String webRss2JsonEndpoint =
      'https://api.rss2json.com/v1/api.json';

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
  static const String rssCheckTaskId      = 'com.chastechgroup.finreels.rsscheck';
  static const String rssCheckTaskName    = 'rssCheckTask';
  static const Duration rssCheckFrequency = Duration(minutes: 15);

  // ── Notification Channel ──────────────────────────────────────────────────────
  static const int    notifIdBase      = 1000;
  static const String notifChannelId   = 'finreels_new_content';
  static const String notifChannelName = 'New Videos';
  static const String notifChannelDesc =
      'Get notified when your favourite channels post new content';
}
