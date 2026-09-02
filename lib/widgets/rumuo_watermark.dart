import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Rumuo watermark — full-width lower-third (covers YouTube logo)
// ─────────────────────────────────────────────────────────────────────────────
//
// DESIGN (exact match to approved mock)
//   Full-width bar across the bottom of the player.
//   Gold rim along the top with a smooth center notch/curve.
//   Rumuo rounded icon + "Rumuo" text on the RIGHT.
//   Left side of the bar is solid fill (same chrome).
//
// THEME
//   Light → white bar, dark text
//   Dark  → black bar, white text
//   Gold accent always (AppTheme.gold)
//
// POSITIONING (call sites MUST use full width)
//   Positioned(left: 0, right: 0, bottom: 0, child: RumuoWatermark())
//
// VISIBILITY (owned by each screen)
//   ~4 s after play starts + while paused (same window as YouTube logo)
// ─────────────────────────────────────────────────────────────────────────────

class RumuoWatermark extends StatelessWidget {
  const RumuoWatermark({super.key});

  static const double barHeight = 40;
  static const double _iconSize = 22;
  static const Color _gold = AppTheme.gold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF2000000) : const Color(0xF2FFFFFF);
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return SizedBox(
      height: barHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _FullBarPainter(bg: bg, gold: _gold),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rounded Rumuo icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: _iconSize,
                    height: _iconSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: _iconSize,
                      height: _iconSize,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: isDark ? Colors.black : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rumuo',
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width bar with gold top rim and a smooth center notch (matches mock).
class _FullBarPainter extends CustomPainter {
  final Color bg;
  final Color gold;

  const _FullBarPainter({required this.bg, required this.gold});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Notch geometry — smooth valley in the center of the top edge.
    final notchCenter = w * 0.42;
    final notchHalfW = w * 0.13;
    final notchDepth = h * 0.55;

    final path = Path();

    path.moveTo(0, h);
    path.lineTo(0, 0);

    // Top edge left segment
    path.lineTo(notchCenter - notchHalfW, 0);

    // Smooth notch (cubic curves down then up)
    path.cubicTo(
      notchCenter - notchHalfW * 0.45,
      0,
      notchCenter - notchHalfW * 0.35,
      notchDepth,
      notchCenter,
      notchDepth,
    );
    path.cubicTo(
      notchCenter + notchHalfW * 0.35,
      notchDepth,
      notchCenter + notchHalfW * 0.45,
      0,
      notchCenter + notchHalfW,
      0,
    );

    // Top edge right segment → top-right corner
    path.lineTo(w, 0);
    path.lineTo(w, h);
    path.close();

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = bg
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Gold rim along the entire top edge (including the notch curve)
    final goldPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final rim = Path();
    rim.moveTo(0, 0.9);
    rim.lineTo(notchCenter - notchHalfW, 0.9);
    rim.cubicTo(
      notchCenter - notchHalfW * 0.45,
      0.9,
      notchCenter - notchHalfW * 0.35,
      notchDepth + 0.5,
      notchCenter,
      notchDepth + 0.5,
    );
    rim.cubicTo(
      notchCenter + notchHalfW * 0.35,
      notchDepth + 0.5,
      notchCenter + notchHalfW * 0.45,
      0.9,
      notchCenter + notchHalfW,
      0.9,
    );
    rim.lineTo(w, 0.9);

    canvas.drawPath(rim, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _FullBarPainter old) =>
      old.bg != bg || old.gold != gold;
}
