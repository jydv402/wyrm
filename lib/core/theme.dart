import 'package:flutter/material.dart';

/// Palette extracted directly from the retro-futuristic bento design reference.
class AppColors {
  // Base Canvas & Neutral Surfaces
  static const Color background = Color(0xFF000000); // Void black master canvas
  static const Color surface = Color(0xFF121418); // Dark card background
  static const Color surfaceElevated = Color(0xFF1B1E26);
  static const Color borderDark = Color(0xFF222631);

  // Bento Card Hero Colors
  static const Color cardSage = Color(
    0xFFA0D2B4,
  ); // Pastel mint/sage green card
  static const Color cardYellow = Color(0xFFFEE15F); // Warm golden yellow card
  static const Color cardCream = Color(
    0xFFFCF7CB,
  ); // Pale vanilla cream pill bar
  static const Color cardOrange = Color(
    0xFFE06E3F,
  ); // Burnt / safety orange card
  static const Color cardWhite = Color(0xFFFFFFFF); // High-contrast white card

  // Accents & Hardware Details
  static const Color accentOrange = Color(
    0xFFFF7F00,
  ); // Visor glow / cyberware highlight
  static const Color accentRed = Color(0xFFFF3B30);

  // Typography
  static const Color textPrimary = Color(
    0xFFFFFFFF,
  ); // White text on dark surfaces
  static const Color textSecondary = Color(0xFF8E95A5);
  static const Color textMuted = Color(0xFF535868);
  static const Color textOnLight = Color(
    0xFF111111,
  ); // Deep black text on pastel cards
}

/// ThemeExtension enabling clean access to the bento color tokens via Theme.of(context).
class BentoPalette extends ThemeExtension<BentoPalette> {
  final Color cardSage;
  final Color cardYellow;
  final Color cardCream;
  final Color cardOrange;
  final Color cardWhite;
  final Color textOnLight;
  final Color accentOrange;

  const BentoPalette({
    required this.cardSage,
    required this.cardYellow,
    required this.cardCream,
    required this.cardOrange,
    required this.cardWhite,
    required this.textOnLight,
    required this.accentOrange,
  });

  static const BentoPalette dark = BentoPalette(
    cardSage: AppColors.cardSage,
    cardYellow: AppColors.cardYellow,
    cardCream: AppColors.cardCream,
    cardOrange: AppColors.cardOrange,
    cardWhite: AppColors.cardWhite,
    textOnLight: AppColors.textOnLight,
    accentOrange: AppColors.accentOrange,
  );

  @override
  BentoPalette copyWith({
    Color? cardSage,
    Color? cardYellow,
    Color? cardCream,
    Color? cardOrange,
    Color? cardWhite,
    Color? textOnLight,
    Color? accentOrange,
  }) {
    return BentoPalette(
      cardSage: cardSage ?? this.cardSage,
      cardYellow: cardYellow ?? this.cardYellow,
      cardCream: cardCream ?? this.cardCream,
      cardOrange: cardOrange ?? this.cardOrange,
      cardWhite: cardWhite ?? this.cardWhite,
      textOnLight: textOnLight ?? this.textOnLight,
      accentOrange: accentOrange ?? this.accentOrange,
    );
  }

  @override
  BentoPalette lerp(ThemeExtension<BentoPalette>? other, double t) {
    if (other is! BentoPalette) return this;
    return BentoPalette(
      cardSage: Color.lerp(cardSage, other.cardSage, t) ?? cardSage,
      cardYellow: Color.lerp(cardYellow, other.cardYellow, t) ?? cardYellow,
      cardCream: Color.lerp(cardCream, other.cardCream, t) ?? cardCream,
      cardOrange: Color.lerp(cardOrange, other.cardOrange, t) ?? cardOrange,
      cardWhite: Color.lerp(cardWhite, other.cardWhite, t) ?? cardWhite,
      textOnLight: Color.lerp(textOnLight, other.textOnLight, t) ?? textOnLight,
      accentOrange:
          Color.lerp(accentOrange, other.accentOrange, t) ?? accentOrange,
    );
  }
}

/// AppTheme definition configuring Flutter Material ThemeData.
class AppTheme {
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.cardYellow,
      onPrimary: AppColors.textOnLight,
      secondary: AppColors.cardSage,
      onSecondary: AppColors.textOnLight,
      tertiary: AppColors.cardCream,
      onTertiary: AppColors.textOnLight,
      error: AppColors.accentRed,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.borderDark, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: AppColors.textOnLight, width: 1.2),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          color: AppColors.textOnLight,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardYellow,
          foregroundColor: AppColors.textOnLight,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[BentoPalette.dark],
    );
  }
}

/// Convenience extension on BuildContext to quickly access the BentoPalette.
extension BentoThemeContext on BuildContext {
  BentoPalette get bento =>
      Theme.of(this).extension<BentoPalette>() ?? BentoPalette.dark;
}
