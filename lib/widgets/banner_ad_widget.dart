import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../services/ad_service.dart';

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
// SIZING: both widgets now request a full-width ADAPTIVE anchored banner
// (AdSize.getAnchoredAdaptiveBannerAdSize) sized to the ACTUAL width
// available to the widget (measured via LayoutBuilder, so it automatically
// matches whatever horizontal padding/margins the surrounding screen
// applies — video cards, book grid rows, etc.) instead of the old fixed
// 320×50 AdSize.banner, which rendered as a narrow strip that looked out
// of place next to full-width content. Falls back to AdSize.banner only
// if the adaptive API can't resolve a size for the given width.
//
// Two widgets exported:
//   LabelledBannerAd  — inline list placement (creates its own BannerAd)
//   StickyBannerBar   — bottom of screen (uses AdService's shared instance)
// ─────────────────────────────────────────────────────────────────────────────

/// Inline banner — safe to place multiple times in a ListView/GridView.
/// Each instance creates and owns its own [BannerAd], sized adaptively to
/// the width available to it.
class LabelledBannerAd extends StatefulWidget {
  /// Pass a [fixedSize] (e.g. [AdSize.mediumRectangle] for the 300×250 large
  /// banner used on the Channels screen) to request a fixed format instead of
  /// the default anchored-adaptive banner that fills available width.
  const LabelledBannerAd({super.key, this.fixedSize});
  final AdSize? fixedSize;

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
    final AdSize size;
    if (widget.fixedSize != null) {
      size = widget.fixedSize!;
    } else {
      final adaptive = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        width.truncate(),
      );
      if (!mounted) return;
      size = adaptive ?? AdSize.banner; // graceful fallback
    }

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

        if (!_loaded || _ad == null) return const SizedBox.shrink();

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
              width:  _ad!.size.width.toDouble(),
              height: _ad!.size.height.toDouble(),
              child:  AdWidget(ad: _ad!),
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
