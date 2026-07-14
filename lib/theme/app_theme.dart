import 'package:flutter/material.dart';

/// Calm photographic UI — charcoal ink on warm off-white, not purple/glow AI defaults.
abstract final class AppTheme {
  static const ink = Color(0xFF1A1A18);
  static const paper = Color(0xFFF5F4F1);
  static const mist = Color(0xFFE8E6E1);
  static const accent = Color(0xFF3D5A4C);
  static const accentMuted = Color(0xFF6B7F74);
  static const warn = Color(0xFF8B4513);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: paper,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base.copyWith(
        primary: accent,
        secondary: accentMuted,
        surface: paper,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 14,
          height: 1.35,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.72),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: mist),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mist,
        selectedColor: accent.withValues(alpha: 0.18),
        labelStyle: const TextStyle(fontSize: 12, color: ink),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
