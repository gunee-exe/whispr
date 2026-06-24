import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Six colors, each with one job. No color is decorative — every one
/// signals a specific kind of content or state. See Section 3.1 of the
/// implementation plan.
class WhisprColors {
  WhisprColors._();

  /// App background — warm, soft, never stark white.
  static const Color morningPaper = Color(0xFFFFF8F0);

  /// AI-generated content: confirmation cards, parsed text, the AI's
  /// "voice" in the UI.
  static const Color spokenViolet = Color(0xFF7C6FF0);

  /// The mic button, active/recording states, primary CTAs — the one
  /// color users associate with "go".
  static const Color sparkCyan = Color(0xFF00C2D1);

  /// All body text — warmer and softer than pure black.
  static const Color plumInk = Color(0xFF2D2A3D);

  /// Confirmed / done / success states.
  static const Color calmMint = Color(0xFFA8E6CF);

  /// Countdown ring fill, urgency, "coming up soon" states.
  static const Color emberAmber = Color(0xFFFFD166);

  // Supporting neutrals, not part of the named six but needed for borders
  // / disabled states / subtle dividers.
  static const Color borderGray = Color(0xFFD8D4E0);
  static const Color mutedInk = Color(0xFF8A86A0);
}

/// Three deliberately paired typefaces — see Section 3.2.
class WhisprText {
  WhisprText._();

  /// Display face: the wordmark, confirmation card headlines, empty-state
  /// headlines. Used sparingly — never for body copy.
  static TextStyle display({double size = 32, Color? color, FontWeight? weight}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? WhisprColors.plumInk,
    );
  }

  /// Body / UI face: all reminder text, buttons, navigation, settings.
  static TextStyle body({double size = 16, Color? color, FontWeight? weight}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight ?? FontWeight.normal,
      color: color ?? WhisprColors.plumInk,
    );
  }

  /// Countdown / numerals face: every digit-based display, deliberately
  /// distinct texture from prose so a countdown reads as "ticking".
  static TextStyle countdown({double size = 20, Color? color, FontWeight? weight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? WhisprColors.plumInk,
    );
  }
}

ThemeData buildWhisprTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: WhisprColors.morningPaper,
    colorScheme: base.colorScheme.copyWith(
      primary: WhisprColors.sparkCyan,
      secondary: WhisprColors.spokenViolet,
      surface: WhisprColors.morningPaper,
      onPrimary: Colors.white,
      onSurface: WhisprColors.plumInk,
      error: const Color(0xFFE0584A),
    ),
    textTheme: TextTheme(
      displayLarge: WhisprText.display(size: 40),
      displayMedium: WhisprText.display(size: 32),
      displaySmall: WhisprText.display(size: 24),
      bodyLarge: WhisprText.body(size: 17),
      bodyMedium: WhisprText.body(size: 15),
      bodySmall: WhisprText.body(size: 13, color: WhisprColors.mutedInk),
      labelLarge: WhisprText.body(size: 15, weight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: WhisprColors.morningPaper,
      foregroundColor: WhisprColors.plumInk,
      elevation: 0,
      titleTextStyle: WhisprText.display(size: 22),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: WhisprColors.sparkCyan,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        textStyle: WhisprText.body(size: 16, weight: FontWeight.w600, color: Colors.white),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: WhisprColors.mutedInk,
        textStyle: WhisprText.body(size: 15, weight: FontWeight.w500),
      ),
    ),
    useMaterial3: true,
  );
}

/// Shared motion constants — Section 3.3's spring/morph timings, so every
/// widget that animates the Spark Bar uses the same feel.
class WhisprMotion {
  WhisprMotion._();
  static const Duration sparkBarExpand = Duration(milliseconds: 280);
  static const Duration cardMorph = Duration(milliseconds: 320);
  static const Curve springCurve = Curves.easeOutCubic;
}
