import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../services/ad_service.dart';
import 'adsense_banner_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BannerAdWidget
//
// The original banner_ad_widget.dart shared ONE BannerAd instance from
// AdService across every placement in the list. AdMob does not allow the
// same AdWidget to appear more than once in the widget tree simultaneously —
// doing so throws "This AdWidget is already in the Widget tree" at runtime.
//
// Fix: each _InlineBannerAd creates and owns its own BannerAd instance.
// The global AdService banner is kept for the sticky bottom bar only.
//
// SIZING: inline placements use fixed, standard ad geometries so their
// rows reserve stable space before an asynchronous ad response arrives.
// Large content placements use 300×250 medium rectangles; compact book and
// utility placements use 320×50 banners. This prevents late ad layout shifts
// from moving the surrounding ListView while keeping each source intentional.
// The sticky bottom bar remains independently adaptive because it is outside
// the scrolling content.
//
// Two widgets exported:
//   LabelledBannerAd  — inline list placement (creates its own BannerAd)
//   StickyBannerBar   — bottom of screen (uses AdService's shared instance)
// ─────────────────────────────────────────────────────────────────────────────

/// The two supported inline placements. Large placements are used between
/// video/blog content; compact placements are used for books and utility bars.
enum InlineBannerPlacement { compact, large }

/// Inline banner — safe to place multiple times in a ListView/GridView.
/// Each instance owns its own ad and reserves its final height before the ad
/// finishes loading, preventing a late ad response from moving the scroll.
class LabelledBannerAd extends StatefulWidget {
  /// [fixedSize] remains available for callers that need an exact AdMob size.
  /// Otherwise compact is a 320×50 banner and large is a 300×250 rectangle.
  const LabelledBannerAd({
    super.key,
    this.fixedSize,
    this.placement = InlineBannerPlacement.compact,
  });
  final AdSize? fixedSize;
  final InlineBannerPlacement placement;

  AdSize get requestedSize => fixedSize ??
      (placement == InlineBannerPlacement.large
          ? AdSize.mediumRectangle
          : AdSize.banner);

  @override
  State<LabelledBannerAd> createState() => _LabelledBannerAdState();
}

class _LabelledBannerAdState extends State<LabelledBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _sizeRequested = false;
  int  _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_onAdsServiceChanged);
  }

  /// Fires the instant a purchase completes (or status is otherwise
  /// re-checked) — disposes the now-unwanted ad immediately instead of
  /// leaving it loaded in memory until some unrelated rebuild hides it.
  void _onAdsServiceChanged() {
    if (!mounted) return;
    if (AdService.instance.adsRemoved && _ad != null) {
      _ad!.dispose();
      setState(() { _ad = null; _loaded = false; _sizeRequested = false; });
    }
  }

  Future<void> _load(double width) async {
    if (!mounted) return;
    final size = widget.requestedSize;

    await _ad?.dispose();
    _ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size:     size,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
          _retryCount = 0;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
          if (_retryCount < _maxRetries) {
            _retryCount++;
            final delay = Duration(seconds: 15 * _retryCount);
            unawaited(Future.delayed(delay, () {
              if (mounted) unawaited(_load(width));
            }));
          }
        },
      ),
    );
    unawaited(_ad!.load());
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_onAdsServiceChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService.instance.adsRemoved) return const SizedBox.shrink();

    // Web: AdMob is unavailable. Keep the same fixed slot contract and let
    // the Web implementation render the responsive AdSense creative inside it.
    if (kIsWeb) {
      final size = widget.requestedSize;
      final slotWidth = size.width.toDouble();
      final slotHeight = size.height.toDouble();
      // Keep the label and fixed creative inside a finite, centered row. The
      // outer SizedBox is deliberate: an HtmlElementView must not be allowed
      // to report an intrinsic iframe height into a scrolling ListView.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: double.infinity,
          height: slotHeight + 22,
          child: Align(
            alignment: Alignment.center,
            child: AdSenseBanner(
              width: slotWidth,
              height: slotHeight,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Request the adaptive size exactly once, after this frame commits
        // (never as a synchronous side effect of build()) — the moment the
        // real available width is known.
        if (!_sizeRequested && width.isFinite && width > 0) {
          _sizeRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_load(width));
          });
        }

        final reservedSize = widget.requestedSize;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Advertisement',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9, letterSpacing: 0.5),
              ),
            ),
            SizedBox(
              width: reservedSize.width.toDouble(),
              height: reservedSize.height.toDouble(),
              child: _loaded && _ad != null
                  ? AdWidget(ad: _ad!)
                  : const ColoredBox(color: Colors.transparent),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

/// Sticky bottom banner — owns its own [BannerAd] instance, sized
/// adaptively to fill the full screen width. Safe to place once per
/// screen. Rebuilds itself when the ad loads.
class StickyBannerBar extends StatefulWidget {
  const StickyBannerBar({super.key});

  @override
  State<StickyBannerBar> createState() => _StickyBannerBarState();
}

class _StickyBannerBarState extends State<StickyBannerBar> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _sizeRequested = false;
  int  _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_onAdsServiceChanged);
  }

  void _onAdsServiceChanged() {
    if (!mounted) return;
    if (AdService.instance.adsRemoved && _ad != null) {
      _ad!.dispose();
      setState(() { _ad = null; _loaded = false; _sizeRequested = false; });
    }
  }

  Future<void> _load(double width) async {
    if (!mounted) return;
    final adaptiveSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width.truncate(),
    );
    if (!mounted) return;
    final size = adaptiveSize ?? AdSize.banner;

    await _ad?.dispose();
    _ad     = null;
    _loaded = false;

    _ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size:     size,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
          _retryCount = 0;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _loaded = false);
          if (_retryCount < _maxRetries) {
            _retryCount++;
            final delay = Duration(seconds: 15 * _retryCount);
            unawaited(Future.delayed(delay, () {
              if (mounted) unawaited(_load(width));
            }));
          }
        },
      ),
    );
    unawaited(_ad!.load());
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_onAdsServiceChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService.instance.adsRemoved) return const SizedBox.shrink();

    if (kIsWeb) {
      return const Material(
        elevation: 4,
        child: SafeArea(
          top: false,
          child: AdSenseBanner(height: 70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!_sizeRequested && width.isFinite && width > 0) {
          _sizeRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_load(width));
          });
        }

        if (!_loaded || _ad == null) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1),
            SizedBox(
              width:  _ad!.size.width.toDouble(),
              height: _ad!.size.height.toDouble(),
              child:  AdWidget(ad: _ad!),
            ),
          ],
        );
      },
    );
  }
}
