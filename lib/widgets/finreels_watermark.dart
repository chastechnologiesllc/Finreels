import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FinReels watermark — static corner chip, covers YouTube native logo
// ─────────────────────────────────────────────────────────────────────────────
//
// SHAPE
//   Flush to the bottom-right corner of the player.
//   Only the top-left corner is rounded — the other three are square so the
//   chip sits clean against the player edges with no visible gap.
//
//   ┌────────────────────────────────┐  ← player top
//   │                                │
//   │                                │
//   │                    ╭───────────┤  ← top-left of chip is rounded
//   │                    │ 🎬FinReels│
//   └────────────────────┴───────────┘  ← bottom edge flush
//                                  └── right edge flush
//
// POSITIONING
//   Always: Positioned(right: 0, bottom: 0, child: FinReelsWatermark())
//
// VISIBILITY (static — no timer needed)
//   • inline card    : _expanded && !_ended && _revealPlayer
//   • video player   : _hasStartedPlaying && !_ended
//   • landscape      : _hasStarted && !_ended
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
        // Only the top-left corner is rounded — all other edges are flush
        // with the bottom-right corner of the player frame.
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
        ),
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
