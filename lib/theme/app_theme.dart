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

  /// Pasteboard behind live artboards — a well that sits between UI chrome and
  /// a pure-black matte so canvas edges stay readable (Figma/PS-like stage).
  static Color artboardPasteboard(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF2A2926)
          : const Color(0xFFE3E1DB);

  /// Absolute relative-luminance delta between [matte] and pasteboard (0–1).
  static double artboardContrast(Color matte, Brightness brightness) =>
      (matte.computeLuminance() -
              artboardPasteboard(brightness).computeLuminance())
          .abs();

  /// Lift strength from matte↔pasteboard contrast: full at 0, cut out at ≥ 0.5.
  static double artboardLiftStrength(Color matte, Brightness brightness) =>
      (1.0 - (artboardContrast(matte, brightness) / 0.5)).clamp(0.0, 1.0);

  /// Soft lift under an artboard: light relief in dark mode, Material-like
  /// dark shadow in light mode. Alphas scale by [matte]↔pasteboard contrast.
  static List<BoxShadow> artboardLift(Brightness brightness, Color matte) {
    final strength = artboardLiftStrength(matte, brightness);
    if (strength <= 0) return const [];
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.12 * strength),
          blurRadius: 22,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.07 * strength),
          blurRadius: 5,
          spreadRadius: 0,
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.14 * strength),
        blurRadius: 14,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 1px rim when soft lift alone is not enough; opacity scales with lift strength.
  static BorderSide artboardRim(Brightness brightness, Color matte) {
    final strength = artboardLiftStrength(matte, brightness);
    if (strength <= 0) return BorderSide.none;
    return BorderSide(
      color: brightness == Brightness.dark
          ? const Color(0xFFFFFFFF).withValues(alpha: 0.10 * strength)
          : const Color(0xFF000000).withValues(alpha: 0.08 * strength),
    );
  }

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
