import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Shared shimmer treatment for every FinReels loading surface.
///
/// The palette is deliberately more separated than the normal surface colors:
/// a loading state should remain visibly animated on both pure black and pure
/// white app backgrounds. The 950ms period keeps the sweep noticeable without
/// feeling distracting on cards, grids, and full-page skeletons.
class FinreelsShimmer extends StatelessWidget {
  static const Duration animationPeriod = Duration(milliseconds: 950);

  final Widget child;
  final bool enabled;

  const FinreelsShimmer({
    required this.child,
    super.key,
    this.enabled = true,
  });

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color baseColor(BuildContext context) => isDark(context)
      ? const Color(0xFF242424)
      : const Color(0xFFD9D9D9);

  static Color highlightColor(BuildContext context) => isDark(context)
      ? const Color(0xFF5A5A5A)
      : AppTheme.lightBg;

  static Color fillColor(BuildContext context) => isDark(context)
      ? const Color(0xFF171717)
      : const Color(0xFFECECEC);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor(context),
      highlightColor: highlightColor(context),
      period: animationPeriod,
      direction: ShimmerDirection.ltr,
      enabled: enabled,
      child: child,
    );
  }
}
