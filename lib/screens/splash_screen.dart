import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

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
    // Allow animations to play then call onComplete
    Future.delayed(const Duration(milliseconds: 2800), widget.onComplete);
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
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.goldDark],
                  center: Alignment.topLeft,
                  radius: 1.5,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 54),
            )
                .animate()
                .scale(begin: const Offset(0.6, 0.6), duration: 600.ms,
                    curve: Curves.easeOutBack)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // ── App Name ──────────────────────────────────────────────────────
            Text(
              'FinReels',
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
              'Financial Literacy · Unlocked',
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
