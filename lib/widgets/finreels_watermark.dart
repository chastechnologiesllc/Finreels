import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FinReels watermark — rounded corner chip, covers YouTube native logo
// ─────────────────────────────────────────────────────────────────────────────
//
// SHAPE
//   Fully rounded pill (all four corners) so the watermark reads as a
//   polished chip rather than a flush corner plate.
//
// POSITIONING (call sites own the offsets)
//   • shorts / inline : right: 0–8, bottom: 0–8
//   • portrait player : right slightly inset (covers YT logo)
//   • landscape       : right + bottom inset (covers YT logo)
//
// THEME
//   Adapts bg/fg to dark/light mode so the chip stays legible on any
//   thumbnail or background.
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
        // Fully rounded on all corners.
        borderRadius: BorderRadius.circular(12),
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
