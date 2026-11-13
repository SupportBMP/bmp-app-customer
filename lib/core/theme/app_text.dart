import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography of the v2 theme: body text is DM Sans, h1–h3 are Playfair
/// Display bold, and Tailwind's `font-sans` (system-ui) is Roboto on Android.
///
/// Sizes follow Tailwind: xs 12, sm 14, base 16, lg 18, xl 20, 2xl 24,
/// 3xl 30, 4xl 36, 5xl 48.
class AppText {
  AppText._();

  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.foreground,
    double? height,
    double? letterSpacing,
    FontStyle? style,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: style,
        decoration: decoration,
        decorationColor: color,
      );

  /// `font-sans` — Tailwind's system-ui stack.
  static TextStyle sans({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.foreground,
    double? height,
    double? letterSpacing,
    FontStyle? style,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.roboto(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: style,
        decoration: decoration,
        decorationColor: color,
      );

  /// h1/h2/h3 inside `.new-v2-theme`.
  static TextStyle heading({
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.foreground,
    double? height = 1.25,
    FontStyle? style,
    double? letterSpacing,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        fontStyle: style,
        letterSpacing: letterSpacing,
      );

  /// Legacy pages (non-v2 chrome) use Poppins.
  static TextStyle poppins({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.foreground,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// `uppercase tracking-widest` labels.
  static TextStyle label({
    double size = 10,
    Color color = AppColors.mutedForeground,
    double letterSpacing = 1.0,
    FontWeight weight = FontWeight.w700,
  }) =>
      body(size: size, weight: weight, color: color, letterSpacing: letterSpacing);
}
