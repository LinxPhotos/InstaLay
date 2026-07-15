import 'package:flutter/material.dart';

/// Calm photographic UI — charcoal ink on warm off-white / soft charcoal dark,
/// not purple/glow AI defaults.
abstract final class AppTheme {
  // Light
  static const ink = Color(0xFF1A1A18);
  static const paper = Color(0xFFF5F4F1);
  static const mist = Color(0xFFE8E6E1);

  // Dark — warm charcoal paper, soft ink (readable, not pure black/white)
  static const inkDark = Color(0xFFE8E6E1);
  static const paperDark = Color(0xFF161614);
  static const mistDark = Color(0xFF2C2B28);
  static const elevatedDark = Color(0xFF1E1E1B);

  static const accent = Color(0xFF3D5A4C);
  static const accentMuted = Color(0xFF6B7F74);
  static const accentOnDark = Color(0xFF8FA89A);
  static const warn = Color(0xFF8B4513);
  static const warnOnDark = Color(0xFFD4A574);

  /// Muted on-surface text/icons for the active brightness.
  static Color muted(BuildContext context, [double alpha = 0.55]) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha);

  /// Hairline / panel chrome for the active brightness.
  static Color chrome(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        seed: accent,
        surface: paper,
        onSurface: ink,
        outline: mist,
        cardColor: Colors.white.withValues(alpha: 0.72),
        chipBg: mist,
        primary: accent,
        secondary: accentMuted,
        warnColor: warn,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        seed: accentOnDark,
        surface: paperDark,
        onSurface: inkDark,
        outline: mistDark,
        cardColor: elevatedDark.withValues(alpha: 0.9),
        chipBg: mistDark,
        primary: accentOnDark,
        secondary: accentMuted,
        warnColor: warnOnDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color surface,
    required Color onSurface,
    required Color outline,
    required Color cardColor,
    required Color chipBg,
    required Color primary,
    required Color secondary,
    required Color warnColor,
  }) {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
    );
    final scheme = base.copyWith(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: onSurface,
      outlineVariant: outline,
      error: warnColor,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      dividerColor: outline,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 14,
          height: 1.35,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: brightness == Brightness.dark ? paperDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        selectedColor: primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(fontSize: 12, color: onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
