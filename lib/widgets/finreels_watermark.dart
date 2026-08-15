import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FinReels watermark — covers YouTube native logo (bottom-right)
// ─────────────────────────────────────────────────────────────────────────────
//
// DESIGN (matches approved mock)
//   Dark bar segment with gold top accent edge.
//   FinReels app icon + "FinReels" text aligned to the RIGHT.
//   Curved / angled leading edge so it reads as a deliberate lower-third
//   rather than a plain rectangle.
//
//   ┌────────────────────────────────────────────┐
//   │              video content                 │
//   │                                            │
//   │         ╭──────────────────────────────────┤
//   │         │  (gold edge)     🎬 FinReels     │
//   └─────────┴──────────────────────────────────┘
//
// POSITIONING (call sites)
//   • inline card      : Positioned(right: 0, bottom: 0)
//   • video player     : Positioned(right: 0, bottom: 0)  [was offset]
//   • landscape        : Positioned(right: 0, bottom: 0)  [was offset]
//   • shorts           : Positioned(right: 0, bottom: …)
//
// VISIBILITY (owned by each screen — do not hardcode timers here)
//   Appears while the YouTube logo is expected on-screen:
//     • first ~4 s after play starts  (_showYtCover)
//     • while paused
//   Disappears when the YouTube logo is hidden by the official player.
//
// THEME
//   Always dark chrome + gold accent so it stays legible on any frame.
// ─────────────────────────────────────────────────────────────────────────────

class FinReelsWatermark extends StatelessWidget {
  const FinReelsWatermark({super.key});

  static const double _barHeight = 36;
  static const double _iconSize = 20;
  static const Color _barBg = Color(0xF2000000); // near-opaque black
  static const Color _gold = AppTheme.gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: CustomPaint(
        painter: _WatermarkBarPainter(),
        child: Padding(
          // Push content to the right; leave room for the angled leading edge.
          padding: const EdgeInsets.only(left: 28, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Image.asset(
                'assets/icons/app_icon.png',
                width: _iconSize,
                height: _iconSize,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.play_arrow_rounded,
                  color: _gold,
                  size: _iconSize,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'FinReels',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the dark bar body + gold accent edge with an angled leading cut.
class _WatermarkBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Angled leading edge (mirrors the mock: left side curves up).
    // The cut starts ~18 px in from the left at the top and meets the
    // bottom-left corner, giving the bar its distinctive shape.
    const cut = 18.0;

    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(cut, 0)
      ..close();

    // Fill
    final fill = Paint()
      ..color = FinReelsWatermark._barBg
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    // Gold accent along the top edge only (the visible “rim”).
    final gold = Paint()
      ..color = FinReelsWatermark._gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final topEdge = Path()
      ..moveTo(cut, 0.8)
      ..lineTo(w, 0.8);
    canvas.drawPath(topEdge, gold);

    // Subtle gold highlight on the angled leading edge.
    final leadEdge = Path()
      ..moveTo(0, h)
      ..lineTo(cut, 0.8);
    canvas.drawPath(
      leadEdge,
      Paint()
        ..color = FinReelsWatermark._gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
