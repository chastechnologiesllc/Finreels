import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FinReels watermark — covers the native YouTube logo
// ─────────────────────────────────────────────────────────────────────────────
//
// CONFIRMED POSITIONS (from device screenshots — do not change without
// re-testing on physical hardware):
//
//   Inline feed card (16:9)   → Positioned(right: 27,  bottom: 17)
//   Video player — portrait   → Positioned(right: 58,  bottom: 18)
//   Video player — landscape  → Positioned(right: 56,  bottom: 28)
//   Landscape screen          → Positioned(right: 56,  bottom: 28)
//
// YouTube places its logo at a fixed CSS pixel position inside the IFrame.
// The values above map those CSS pixels to Flutter dp and have been verified
// across 360 dp, 393 dp, and 412 dp phones.
//
// SIZING: icon 22 dp | gap 8 dp | "FinReels" at 14 dp bold ≈ 130 × 40 dp
// chip — deliberately larger than the YouTube logo (~68 × 15 dp) so the
// chip fully covers it at every screen density.
//
// ─────────────────────────────────────────────────────────────────────────────

class FinReelsWatermark extends StatelessWidget {
  const FinReelsWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF2000000) : const Color(0xF2FFFFFF);
    final fg = isDark ? AppTheme.gold : const Color(0xFF1A1A1A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => Icon(
              Icons.play_arrow_rounded,
              color: fg,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'FinReels',
            style: TextStyle(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
