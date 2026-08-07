import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'consent_service.dart';

/// AdService — interstitial patterns:
///
/// FEED TAPS (videos, blogs, books):
///   Show ad on every 4th tap: taps 4, 8, 12, 16 …
///   i.e. user browses 1-2-3 freely, ad on 4th, free 5-6-7, ad on 8th, etc.
///
/// VIDEO PAUSE:
///   Show ad on every 4th pause: pauses 4, 8, 12 …
///   Independent counter per session — resets when app restarts.
///
/// BLOGS / BOOKS:
///   Same counter as feed taps (shared _contentTapCount).
///   Tapping any blog article or book triggers the same every-4th pattern.
///
/// BANNER:
///   Placed after every 3rd item in the video feed list and blog list.
///   Also pinned at the bottom of all content screens.
///   A single BannerAd instance is reused across all placements via
///   AdWidget — the SDK handles correct rendering.
///
/// SHORTS: untouched — scroll-based counter unchanged.
///
/// Extends ChangeNotifier purely so screens can react instantly the moment
/// ads are removed/restored (notifyListeners() fires from grantAdFree(),
/// revokeAdFree(), and refreshStatus()) — every `AdService.instance.xxx()`
/// call site elsewhere in the app is untouched and keeps working exactly
/// as a plain singleton.
class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad objects ────────────────────────────────────────────────────────────
  BannerAd?               _bannerAd;
  InterstitialAd?         _interstitialAd;
  AppOpenAd?              _appOpenAd;
  RewardedAd?             _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;

  bool _bannerReady               = false;
  bool _interstitialReady         = false;
  bool _appOpenReady              = false;
  bool _rewardedReady             = false;
  bool _rewardedInterstitialReady = false;

  // ── Counters ──────────────────────────────────────────────────────────────

  /// Video tap counter — fires interstitial on tap 8, 16, 24 …
  int _videoTapCount = 0;

  /// Blog tap counter — fires interstitial on tap 8, 16, 24 …
  int _blogTapCount = 0;

  /// Book open counter — fires interstitial on open 4, 8, 12 …
  int _bookReadCount = 0;

  /// Video play/pause tap counter — fires interstitial on tap 6, 12, 18 …
  int _videoPlayPauseCount = 0;

  /// Shorts thumbnail-tap counter — fires interstitial on tap 4, 8, 12 …
  int _shortTapCount = 0;

  /// Shorts scroll counter — fires interstitial on scroll 4, 8, 12 …
  int _shortScrollCount = 0;

  int _channelSwitchCount = 0;
  DateTime? _lastAppOpenShown;

  bool _adsRemoved  = false;
  bool _initialized = false;

  bool get adsRemoved => _adsRemoved;
  /// Legacy getter — StickyBannerBar and LabelledBannerAd each own their
  /// own BannerAd instances now. Kept for any external callers.
  BannerAd? get bannerAd => (_bannerReady && !_adsRemoved) ? _bannerAd : null;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadAdsRemovedStatus();
    if (_adsRemoved) return;

    // GDPR/UK/Swiss consent MUST be gathered before the Mobile Ads SDK
    // initializes — see ConsentService and the manifest's
    // DELAY_APP_MEASUREMENT_INIT flag, which exists for exactly this
    // ordering requirement. Time-boxed internally; never blocks startup.
    await ConsentService.instance.requestAndLoadConsent();

    await MobileAds.instance.initialize();
    _initialized = true;

    await Future.wait([
      _loadBanner(),
      _loadInterstitial(),
      _loadAppOpen(),
      _loadRewarded(),
      _loadRewardedInterstitial(),
    ]);
  }

  // ── Ads-removed status ────────────────────────────────────────────────────
  Future<void> _loadAdsRemovedStatus() async {
    final prefs   = await SharedPreferences.getInstance();
    final removed = prefs.getBool(AppConfig.prefAdsRemoved) ?? false;
    final wasRemoved = _adsRemoved;
    if (removed) {
      final until = prefs.getInt(AppConfig.prefAdsRemovedUntil);
      if (until != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(until);
        _adsRemoved = DateTime.now().isBefore(expiry);
        if (!_adsRemoved) {
          await prefs.remove(AppConfig.prefAdsRemoved);
          await prefs.remove(AppConfig.prefAdsRemovedUntil);
        }
      } else {
        _adsRemoved = true;
      }
    } else {
      _adsRemoved = false;
    }
    if (_adsRemoved != wasRemoved) notifyListeners();
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  Future<void> _loadBanner() async {
    if (_bannerAd != null) { unawaited(_bannerAd!.dispose()); }
    _bannerAd    = null;
    _bannerReady = false;

    _bannerAd = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size:     AdSize.banner,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => _bannerReady = true,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerReady = false;
          Timer(const Duration(seconds: 30), () => unawaited(_loadBanner()));
        },
      ),
    );
    await _bannerAd!.load();
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  int _interstitialRetry = 0;
  static const int _maxInterstitialRetries = 5;

  Future<void> _loadInterstitial() async {
    _interstitialReady = false;
    await InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request:  const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd    = ad;
          _interstitialReady = true;
          _interstitialRetry = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              unawaited(_loadInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              unawaited(_loadInterstitial());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitialReady = false;
          if (_interstitialRetry < _maxInterstitialRetries) {
            _interstitialRetry++;
            final delay = Duration(seconds: 15 * _interstitialRetry);
            Timer(delay, () => unawaited(_loadInterstitial()));
          } else {
            // Cap at 5-minute retry after max back-off.
            Timer(const Duration(minutes: 5),
                () => unawaited(_loadInterstitial()));
          }
        },
      ),
    );
  }

  // ── Rewarded ──────────────────────────────────────────────────────────────
  Future<void> _loadRewarded() async {
    _rewardedReady = false;
    await RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd    = ad;
          _rewardedReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd    = null;
              _rewardedReady = false;
              unawaited(_loadRewarded());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedAd    = null;
              _rewardedReady = false;
              unawaited(_loadRewarded());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _rewardedReady = false;
          Timer(const Duration(minutes: 2), () => unawaited(_loadRewarded()));
        },
      ),
    );
  }

  Future<void> showRewardedAd({required void Function() onRewarded}) async {
    if (_adsRemoved || !_rewardedReady || _rewardedAd == null) return;
    try {
      await _rewardedAd!.show(onUserEarnedReward: (_, __) => onRewarded());
    } on Object catch (e) {
      debugPrint('[ads] Rewarded show() failed, reloading: $e');
      unawaited(_rewardedAd?.dispose() ?? Future.value());
      _rewardedAd = null;
      unawaited(_loadRewarded());
      return;
    }
    _rewardedReady = false;
  }

  // ── Rewarded Interstitial ─────────────────────────────────────────────────
  Future<void> _loadRewardedInterstitial() async {
    _rewardedInterstitialReady = false;
    await RewardedInterstitialAd.load(
      adUnitId: AppConfig.rewardedInterstitialAdUnitId,
      request:  const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd    = ad;
          _rewardedInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedInterstitialAd    = null;
              _rewardedInterstitialReady = false;
              unawaited(_loadRewardedInterstitial());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedInterstitialAd    = null;
              _rewardedInterstitialReady = false;
              unawaited(_loadRewardedInterstitial());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _rewardedInterstitialReady = false;
          Timer(const Duration(minutes: 2),
              () => unawaited(_loadRewardedInterstitial()));
        },
      ),
    );
  }

  Future<void> showRewardedInterstitialAd({
    required void Function() onRewarded,
  }) async {
    if (_adsRemoved || !_rewardedInterstitialReady ||
        _rewardedInterstitialAd == null) { return; }
    try {
      await _rewardedInterstitialAd!.show(
          onUserEarnedReward: (_, __) => onRewarded());
    } on Object catch (e) {
      debugPrint('[ads] Rewarded interstitial show() failed, reloading: $e');
      unawaited(_rewardedInterstitialAd?.dispose() ?? Future.value());
      _rewardedInterstitialAd = null;
      unawaited(_loadRewardedInterstitial());
      return;
    }
    _rewardedInterstitialReady = false;
  }

  // ── App Open ──────────────────────────────────────────────────────────────
  Future<void> _loadAppOpen() async {
    final unitId = AppConfig.appOpenAdUnitId;
    if (unitId == null) {
      // No production App Open unit configured (and not in kDebugAds mode)
      // — intentionally a no-op rather than ever loading Google's test
      // creative for a real user. See AppConfig.appOpenAdUnitId.
      _appOpenReady = false;
      return;
    }
    _appOpenReady = false;
    await AppOpenAd.load(
      adUnitId: unitId,
      request:  const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd    = ad;
          _appOpenReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _appOpenAd    = null;
              _appOpenReady = false;
              unawaited(_loadAppOpen());
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _appOpenAd    = null;
              _appOpenReady = false;
              unawaited(_loadAppOpen());
            },
          );
        },
        onAdFailedToLoad: (_) {
          _appOpenReady = false;
          Timer(const Duration(minutes: 5), () => unawaited(_loadAppOpen()));
        },
      ),
    );
  }

  Future<void> showAppOpenAd() async {
    if (_adsRemoved || !_appOpenReady || _appOpenAd == null) return;
    if (_lastAppOpenShown != null) {
      if (DateTime.now().difference(_lastAppOpenShown!) <
          AppConfig.appOpenAdCooldown) { return; }
    }
    _lastAppOpenShown = DateTime.now();
    try {
      await _appOpenAd!.show();
    } on Object catch (e) {
      debugPrint('[ads] App Open show() failed, reloading: $e');
      unawaited(_appOpenAd?.dispose() ?? Future.value());
      _appOpenAd = null;
      unawaited(_loadAppOpen());
      return;
    }
    _appOpenReady = false;
  }

  // ── VIDEO TAP TRIGGER ─────────────────────────────────────────────────────
  /// Fires on tap 8, 16, 24 … in the Videos tab.
  /// Uses [AppConfig.interstitialVideoEvery] — isolated from the shared cycle
  /// so adjusting video frequency doesn't affect shorts or blog ads.
  Future<void> onVideoTapped() async {
    if (_adsRemoved || !_initialized) return;
    _videoTapCount++;
    if (_videoTapCount % AppConfig.interstitialVideoEvery == 0) {
      await showInterstitial();
    }
  }

  // ── VIDEO PLAY/PAUSE TRIGGER ─────────────────────────────────────────────────
  /// Fires on every 6th play/pause tap inside the video player.
  /// Uses its own counter so it never interferes with video-open frequency.
  Future<void> onVideoPlayPauseTapped() async {
    if (_adsRemoved || !_initialized) return;
    _videoPlayPauseCount++;
    if (_videoPlayPauseCount % AppConfig.interstitialVideoPlayPauseEvery == 0) {
      await showInterstitial();
    }
  }

  // ── BOOK READ TRIGGER ─────────────────────────────────────────────────────
  /// Fires on every 8th book open — same cadence as videos and blogs.
  /// Polls for up to 2 s in case the ad is still loading from a prior dismiss.
  Future<void> onBookRead() async {
    if (_adsRemoved) return;
    _bookReadCount++;
    if (_bookReadCount % AppConfig.interstitialBookReadEvery != 0) return;
    const maxWaitMs  = 2000;
    const pollMs     = 150;
    var   waited     = 0;
    while (waited < maxWaitMs) {
      if (_adsRemoved) return;
      if (_interstitialReady && _interstitialAd != null) {
        await showInterstitial();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: pollMs));
      waited += pollMs;
    }
    // Interstitial not available after 2 s — proceed silently.
  }

  /// Fires on tap 8, 16, 24 … in the Blogs tab.
  Future<void> onBlogTapped() async {
    if (_adsRemoved || !_initialized) return;
    _blogTapCount++;
    if (_blogTapCount % AppConfig.interstitialBlogEvery == 0) {
      await showInterstitial();
    }
  }

  // ── SHORT THUMBNAIL TAP TRIGGER ───────────────────────────────────────────
  /// Fires on tap 4, 8, 12 … when user opens a short from the grid.
  Future<void> onShortTapped() async {
    if (_adsRemoved || !_initialized) return;
    _shortTapCount++;
    if (_shortTapCount % AppConfig.interstitialCycleLength == 0) {
      await showInterstitial();
    }
  }

  // ── SHORTS SCROLL TRIGGER ─────────────────────────────────────────────────
  /// Fires on scroll 4, 8, 12 … inside the Shorts player.
  Future<void> onShortScrolled() async {
    if (_adsRemoved || !_initialized) return;
    _shortScrollCount++;
    if (_shortScrollCount % AppConfig.interstitialEveryNShorts == 0) {
      await showInterstitial();
    }
  }

  // ── CHANNEL SWITCH ────────────────────────────────────────────────────────
  Future<void> onChannelSwitched() async {
    if (_adsRemoved || !_initialized) return;
    _channelSwitchCount++;
    if (_channelSwitchCount % AppConfig.interstitialEveryNChannelSwitches == 0) {
      await showInterstitial();
    }
  }

  Future<void> showInterstitial() async {
    if (_adsRemoved || _interstitialAd == null || !_interstitialReady) return;

    // Use a Completer so this method properly AWAITS the ad being DISMISSED —
    // not just shown.  This prevents the caller (e.g. onShortScrolled) from
    // returning while the ad is still playing, which was causing the shorts
    // player to resume underneath the ad video.
    final completer = Completer<void>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd    = null;
        _interstitialReady = false;
        if (!completer.isCompleted) completer.complete();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[ads] Interstitial failed to show: $err');
        ad.dispose();
        _interstitialAd    = null;
        _interstitialReady = false;
        if (!completer.isCompleted) completer.complete();
        unawaited(_loadInterstitial());
      },
    );

    try {
      unawaited(_interstitialAd!.show());
    } on Object catch (e) {
      debugPrint('[ads] Interstitial show() threw: $e');
      if (!completer.isCompleted) completer.complete();
      unawaited(_interstitialAd?.dispose() ?? Future.value());
      _interstitialAd    = null;
      _interstitialReady = false;
      unawaited(_loadInterstitial());
      return;
    }

    _interstitialReady = false;
    await completer.future; // Block until ad is dismissed
  }

  // ── Legacy compat ─────────────────────────────────────────────────────────
  Future<void> onContentTapped() => onVideoTapped();
  Future<void> onVideoOpened()   => onVideoTapped();

  // ── IAP: grant / revoke ad-free ───────────────────────────────────────────
  Future<void> grantAdFree(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration);
    await prefs.setBool(AppConfig.prefAdsRemoved, true);
    await prefs.setInt(
        AppConfig.prefAdsRemovedUntil, until.millisecondsSinceEpoch);
    _adsRemoved = true;
    unawaited(_bannerAd?.dispose()              ?? Future.value());
    _bannerAd              = null; _bannerReady           = false;
    unawaited(_interstitialAd?.dispose()        ?? Future.value());
    _interstitialAd        = null; _interstitialReady     = false;
    unawaited(_appOpenAd?.dispose()             ?? Future.value());
    _appOpenAd             = null; _appOpenReady          = false;
    unawaited(_rewardedAd?.dispose()            ?? Future.value());
    _rewardedAd            = null; _rewardedReady         = false;
    unawaited(_rewardedInterstitialAd?.dispose() ?? Future.value());
    _rewardedInterstitialAd = null; _rewardedInterstitialReady = false;
    // Tells every LabelledBannerAd / StickyBannerBar / gated screen to
    // rebuild and drop its ad RIGHT NOW, instead of waiting for whatever
    // screen happens to rebuild next for an unrelated reason.
    notifyListeners();
  }

  Future<void> revokeAdFree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.prefAdsRemoved);
    await prefs.remove(AppConfig.prefAdsRemovedUntil);
    _adsRemoved = false;
    if (_initialized) {
      await Future.wait([
        _loadBanner(), _loadInterstitial(), _loadAppOpen(),
        _loadRewarded(), _loadRewardedInterstitial(),
      ]);
    }
    notifyListeners();
  }

  /// Re-checks expiry against the wall clock (a purchased ad-free window
  /// can lapse mid-session) and notifies listeners if the status actually
  /// changed. Called on every app resume — see main.dart.
  Future<void> refreshStatus() => _loadAdsRemovedStatus();

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }
}
