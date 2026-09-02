import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/rumuo_mark.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({required this.onComplete, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Deliberately held for 1.5s so the branded moment has real presence on
    // mobile — longer than the animation strictly needs, by product choice.
    // Web is untouched: its static boot screen has no artificial hold and
    // stays only as long as actual load/init genuinely takes.
    Future.delayed(const Duration(milliseconds: 1500), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // ── Logo Mark ─────────────────────────────────────────────────────
            const RumuoMark(size: 96, borderRadius: 26)
                .animate()
                .scale(begin: const Offset(0.6, 0.6), duration: 600.ms,
                    curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // ── App Name ──────────────────────────────────────────────────────
            Text(
              'Rumuo',
              style: TextStyle(
                color: textColor,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────────────────────────
            const Text(
              'Opening your discovery space…',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            )
                .animate(delay: 500.ms)
                .fadeIn(duration: 500.ms),

            const Spacer(flex: 3),

            // ── By Chas ───────────────────────────────────────────────────────
            Text(
              'by chAs',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            )
                .animate(delay: 800.ms)
                .fadeIn(duration: 600.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
