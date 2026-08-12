import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FinReels branded watermark
// ─────────────────────────────────────────────────────────────────────────────
//
// Covers the YouTube native logo that the IFrame API always renders at the
// bottom-right corner of the player, even when controls=0.
//
// SIZING
// The YouTube logo in the IFrame player is approximately 68×15 dp at mdpi.
// This chip is sized to ~116×36 dp — big enough to fully cover it on every
// phone density and screen size.
//
// POSITIONING FORMULA
// YouTube places its logo at roughly:
//   right  ≈ playerWidth  × 0.018  (clamped 5 – 14 dp)
//   bottom ≈ playerHeight × 0.016  (clamped 4 – 12 dp)
// The formula is empirically derived from testing across 360 dp, 393 dp,
// 412 dp, and 430 dp phones in both portrait and landscape.
//
// USAGE — always wrap in a LayoutBuilder + Positioned.fill so the formula
// gets the player's actual pixel dimensions:
//
//   Positioned.fill(
//     child: LayoutBuilder(
//       builder: (_, c) => FinReelsWatermark.layer(c),
//     ),
//   ),
//
// ─────────────────────────────────────────────────────────────────────────────

class FinReelsWatermark extends StatelessWidget {
  const FinReelsWatermark({super.key});

  /// Returns a full-size widget (Padding + Align) that places [FinReelsWatermark]
  /// exactly over the YouTube logo region for a player of size [constraints].
  ///
  /// Drop this inside a [Positioned.fill] → [LayoutBuilder] that is itself a
  /// child of the player's [Stack].
  static Widget layer(BoxConstraints constraints) {
    final right  = (constraints.maxWidth  * 0.018).clamp(5.0,  14.0);
    final bottom = (constraints.maxHeight * 0.016).clamp(4.0,  12.0);
    return Padding(
      padding: EdgeInsets.only(right: right, bottom: bottom),
      child: const Align(
        alignment: Alignment.bottomRight,
        child: FinReelsWatermark(),
      ),
    );
  }

  /// Variant for the Shorts / web full-screen player where the YouTube logo
  /// may be at the very edge. Uses a slightly larger inset so the chip never
  /// gets half-clipped by the device's safe-area notch.
  static Widget layerShorts(BoxConstraints constraints, {required bool isWeb}) {
    if (isWeb) {
      // Web embed: YouTube logo is visible at bottom-right.
      final right  = (constraints.maxWidth  * 0.018).clamp(5.0, 14.0);
      final bottom = (constraints.maxHeight * 0.016).clamp(4.0, 12.0);
      return Padding(
        padding: EdgeInsets.only(right: right, bottom: bottom),
        child: const Align(
          alignment: Alignment.bottomRight,
          child: FinReelsWatermark(),
        ),
      );
    }
    // Mobile: YouTube logo is cropped off-screen because FittedBox.cover
    // zooms the 16:9 video to fill the 9:16 screen, clipping the sides.
    // Show the watermark as branding just above the bottom gradient/title area
    // (~18 % up from the bottom keeps it clear of the title text and
    // progress bar on phones from 667 dp to 932 dp tall).
    return Padding(
      padding: EdgeInsets.only(
        right: 12,
        bottom: constraints.maxHeight * 0.18,
      ),
      child: const Align(
        alignment: Alignment.bottomRight,
        child: FinReelsWatermark(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF2000000) : const Color(0xF2FFFFFF);
    final fg = isDark ? AppTheme.gold : const Color(0xFF1A1A1A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 20,
            height: 20,
            errorBuilder: (_, __, ___) => Icon(
              Icons.play_arrow_rounded,
              color: fg,
              size: 20,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'FinReels',
            style: TextStyle(
              color: fg,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
