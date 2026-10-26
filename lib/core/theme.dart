import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dusk Glass destination tone definition matching assets/web/style.css.
class DuskTone {
  final Color top;
  final Color bottom;
  final Color accent;
  final Color fill;
  final Color ink;
  final Color glow;

  const DuskTone({
    required this.top,
    required this.bottom,
    required this.accent,
    required this.fill,
    required this.ink,
    required this.glow,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      );

  Color get border => accent.withValues(alpha: 0.22);
}

/// Palette tokens extracted directly from assets/web Dusk Glass design system.
class AppColors {
  // Master Canvas & Base Void
  static const Color background = Color(0xFF020305);
  static const Color canvasAlt = Color(0xFF0A0E11);
  static const Color surface = Color(0xFF0E1418);
  static const Color surfaceElevated = Color(0xFF141B20);
  static const Color well = Color(0x4D000000); // 30% black

  // Lines & Glass Alpha Tints
  static const Color line = Color(0x1AFFFFFF); // 10% white
  static const Color lineStrong = Color(0x29FFFFFF); // 16% white
  static const Color glass = Color(0x0FFFFFFF); // 6% white
  static const Color glassHover = Color(0x1CFFFFFF); // 11% white

  // Typography
  static const Color textPrimary = Color(0xFFEEF2F1);
  static const Color textSecondary = Color(0xADE8EEEE); // 68%
  static const Color textMuted = Color(0x75E8EEEE); // 46%
  static const Color textOnLight = Color(0xFF111111);

  // Brand Accents
  static const Color brandDot = Color(0xFFEE7A45);
  static const Color accentOrange = Color(0xFFF2A768);
  static const Color accentRed = Color(0xFFFF6B55);

  // Priority Colors
  static const Color priorityHigh = Color(0xFFFF8F70);
  static const Color priorityMedium = Color(0xFFF3C45E);
  static const Color priorityLow = Color(0xFF8ED5B7);

  // Slate Tone Colors
  static const Color slateTop = Color(0xFF1D262D);
  static const Color slateBottom = Color(0xFF0F1418);
  static const Color slateAccent = Color(0xFFF2A768);
  static const Color slateFill = Color(0xFFF2A768);
  static const Color slateInk = Color(0xFF2A1405);
  static const Color slateGlow = Color(0x26F2A768);

  // Teal Tone Colors
  static const Color tealTop = Color(0xFF29413A);
  static const Color tealBottom = Color(0xFF15262A);
  static const Color tealAccent = Color(0xFF8ED5B7);
  static const Color tealFill = Color(0xFF8ED5B7);
  static const Color tealInk = Color(0xFF0D2A20);
  static const Color tealGlow = Color(0x268ED5B7);

  // Gold Tone Colors
  static const Color goldTop = Color(0xFF3B3725);
  static const Color goldBottom = Color(0xFF1A1A13);
  static const Color goldAccent = Color(0xFFF6E7A1);
  static const Color goldFill = Color(0xFFF6E7A1);
  static const Color goldInk = Color(0xFF2C2710);
  static const Color goldGlow = Color(0x26F6E7A1);

  // Rust Tone Colors
  static const Color rustTop = Color(0xFF4A291B);
  static const Color rustBottom = Color(0xFF22130C);
  static const Color rustAccent = Color(0xFFF27C52);
  static const Color rustFill = Color(0xFFDC582B);
  static const Color rustInk = Color(0xFFFFFFFF);
  static const Color rustGlow = Color(0x26E5693E);

  // Destination Tones
  static const DuskTone slate = DuskTone(
    top: slateTop,
    bottom: slateBottom,
    accent: slateAccent,
    fill: slateFill,
    ink: slateInk,
    glow: slateGlow,
  );

  static const DuskTone teal = DuskTone(
    top: tealTop,
    bottom: tealBottom,
    accent: tealAccent,
    fill: tealFill,
    ink: tealInk,
    glow: tealGlow,
  );

  static const DuskTone gold = DuskTone(
    top: goldTop,
    bottom: goldBottom,
    accent: goldAccent,
    fill: goldFill,
    ink: goldInk,
    glow: goldGlow,
  );

  static const DuskTone rust = DuskTone(
    top: rustTop,
    bottom: rustBottom,
    accent: rustAccent,
    fill: rustFill,
    ink: rustInk,
    glow: rustGlow,
  );

  // Legacy mappings for backwards-compatibility
  static const Color cardSage = Color(0xFF8ED5B7);
  static const Color cardYellow = Color(0xFFF6E7A1);
  static const Color cardCream = Color(0xFFFCF7CB);
  static const Color cardOrange = Color(0xFFDC582B);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderDark = Color(0x29FFFFFF);
}

/// AppTheme definition configuring Material ThemeData with Dusk Glass typography & tokens.
class AppTheme {
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.slateAccent,
      onPrimary: AppColors.slateInk,
      secondary: AppColors.tealAccent,
      onSecondary: AppColors.tealInk,
      tertiary: AppColors.goldAccent,
      onTertiary: AppColors.goldInk,
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
      fontFamily: GoogleFonts.inter().fontFamily,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.lineStrong, width: 1.0),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
