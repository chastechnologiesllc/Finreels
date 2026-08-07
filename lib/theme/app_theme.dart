import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FinReels theme — follows device system theme exactly.
/// Light → pure white surfaces, dark text.
/// Dark  → pure near-black surfaces, pure white text.
/// Gold accent (#F59E0B) on both.
class AppTheme {
  AppTheme._();

  // ── Shared Palette ──────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFFD97706);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  // ── Light Palette ───────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9F9F9);
  static const Color lightSurfaceElevated = Color(0xFFF1F1F1);
  static const Color lightDivider = Color(0xFFE5E5E5);
  static const Color lightText = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF525252);
  static const Color lightTextMuted = Color(0xFF9E9E9E);

  // ── Dark Palette ────────────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0D0D0D);
  static const Color darkSurfaceElevated = Color(0xFF1A1A1A);
  static const Color darkDivider = Color(0xFF1F1F1F);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFA3A3A3);
  static const Color darkTextMuted = Color(0xFF525252);

  // ── Light Theme ─────────────────────────────────────────────────────────────

  /// Status/navigation bar style for a given brightness. Used both inside
  /// the AppBarTheme definitions below AND globally (wrapping every screen,
  /// including ones with no AppBar at all — e.g. MainShell) so the status
  /// bar always renders transparent with correctly-contrasted icons,
  /// letting the Scaffold's own background paint fully through instead of
  /// leaving a visibly different strip behind the time/signal/battery area.
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
      systemNavigationBarColor: isDark ? darkBg : lightBg,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: gold,
        secondary: goldLight,
        surface: lightSurface,
        error: error,
        onSurface: lightText,
        outline: lightDivider,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        // statusBarColor: transparent → the Scaffold's own white background
        // paints fully through the status bar area instead of leaving a
        // visible grey/unstyled strip behind the time/signal/battery icons.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: lightBg,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBg,
        selectedItemColor: gold,
        unselectedItemColor: lightTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightDivider, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceElevated,
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: lightDivider, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: lightText, fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineLarge: TextStyle(
            color: lightText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(
            color: lightText, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        headlineSmall: TextStyle(
            color: lightText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: lightTextSecondary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightTextSecondary),
        bodySmall: TextStyle(color: lightTextMuted, fontSize: 12),
        labelLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: lightTextSecondary),
        labelSmall: TextStyle(color: lightTextMuted, fontSize: 11),
      ),
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldLight,
        surface: darkSurface,
        error: error,
        onSurface: darkText,
        outline: darkDivider,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: darkBg,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: gold,
        unselectedItemColor: darkTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkDivider, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 0.5,
        space: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceElevated,
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: darkDivider, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: darkText, fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineLarge: TextStyle(
            color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(
            color: darkText, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        headlineSmall: TextStyle(
            color: darkText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: darkTextSecondary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkTextSecondary),
        bodySmall: TextStyle(color: darkTextMuted, fontSize: 12),
        labelLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextMuted, fontSize: 11),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  static Color bgColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurface
          : lightSurface;

  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSurfaceElevated
          : lightSurfaceElevated;

  static Color textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : lightText;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : lightTextMuted;

  static Color dividerColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkDivider
          : lightDivider;
}
