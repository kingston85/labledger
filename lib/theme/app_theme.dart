import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Colour tokens for LabLedger. Two palettes: Lab (dark, default) and
/// Daylight (high contrast).
@immutable
class LBColors extends ThemeExtension<LBColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color ink;
  final Color inkDim;
  final Color accent;
  final Color onAccent;
  final Color good;
  final Color fair;
  final Color poor;
  final Color glass;
  final bool isSunlight;

  const LBColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.inkDim,
    required this.accent,
    required this.onAccent,
    required this.good,
    required this.fair,
    required this.poor,
    required this.glass,
    required this.isSunlight,
  });

  static const lab = LBColors(
    bg: Color(0xFF0E1116),
    surface: Color(0xFF181D25),
    surface2: Color(0xFF222935),
    line: Color(0xFF2C3442),
    ink: Color(0xFFE8ECF2),
    inkDim: Color(0xFF8C96A8),
    accent: Color(0xFF7AA2FF),
    onAccent: Color(0xFF081430),
    good: Color(0xFF2BD38A),
    fair: Color(0xFFFFB020),
    poor: Color(0xFFFF5A5F),
    glass: Color(0xD9131820),
    isSunlight: false,
  );

  static const daylight = LBColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F4F7),
    surface2: Color(0xFFE6E9EF),
    line: Color(0xFFC9CFD9),
    ink: Color(0xFF0E1116),
    inkDim: Color(0xFF4A5468),
    accent: Color(0xFF2F5BD3),
    onAccent: Color(0xFFFFFFFF),
    good: Color(0xFF0F8A55),
    fair: Color(0xFFB45309),
    poor: Color(0xFFC62828),
    glass: Color(0xF2FFFFFF),
    isSunlight: true,
  );

  @override
  LBColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? ink,
    Color? inkDim,
    Color? accent,
    Color? onAccent,
    Color? good,
    Color? fair,
    Color? poor,
    Color? glass,
    bool? isSunlight,
  }) {
    return LBColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkDim: inkDim ?? this.inkDim,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      good: good ?? this.good,
      fair: fair ?? this.fair,
      poor: poor ?? this.poor,
      glass: glass ?? this.glass,
      isSunlight: isSunlight ?? this.isSunlight,
    );
  }

  @override
  LBColors lerp(ThemeExtension<LBColors>? other, double t) {
    if (other is! LBColors) return this;
    return LBColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkDim: Color.lerp(inkDim, other.inkDim, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      good: Color.lerp(good, other.good, t)!,
      fair: Color.lerp(fair, other.fair, t)!,
      poor: Color.lerp(poor, other.poor, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      isSunlight: t < 0.5 ? isSunlight : other.isSunlight,
    );
  }
}

extension LBContext on BuildContext {
  LBColors get lb => Theme.of(this).extension<LBColors>() ?? LBColors.lab;
}

/// Type helpers. Inter for interface text, JetBrains Mono for readings.
class LBText {
  LBText._();

  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';

  static TextStyle reading(double size, Color color,
          {FontWeight weight = FontWeight.w500}) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        color: color,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      );

  /// Small capitals label, like an instrument panel.
  static TextStyle label(Color color, {double size = 11}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      );

  static TextStyle title(Color color, {double size = 20}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle body(Color color, {double size = 14, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: sans, fontSize: size, color: color, fontWeight: weight, height: 1.4);
}

class AppTheme {
  AppTheme._();

  static ThemeData build(LBColors c) {
    final brightness = c.isSunlight ? Brightness.light : Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.ink,
      error: c.poor,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: LBText.sans,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LBText.title(c.ink, size: 18),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      cardTheme: CardTheme(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        labelStyle: TextStyle(color: c.inkDim),
        hintStyle: TextStyle(color: c.inkDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(56, 56),
          textStyle: const TextStyle(
              fontFamily: LBText.sans, fontWeight: FontWeight.w700, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(56, 56),
          side: BorderSide(color: c.line),
          textStyle: const TextStyle(
              fontFamily: LBText.sans, fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onAccent : c.inkDim),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.accent : c.surface2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        thumbColor: c.accent,
        inactiveTrackColor: c.surface2,
        overlayColor: c.accent.withOpacity(0.15),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: LBText.body(c.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
