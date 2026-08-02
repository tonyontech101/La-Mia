import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// La Mia typography scale.
///
/// Fraunces (serif) carries the brand wordmark + headlines; Inter handles all
/// UI text. Sizes/weights/line-heights match the approved design system.
abstract final class AppTypography {
  /// Hero headline — e.g. "Welcome back".
  static TextStyle display({Color color = AppColors.textPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        height: 40 / 34,
        color: color,
      );

  /// Screen title on the card — e.g. "Join La Mia".
  static TextStyle headline({Color color = AppColors.textPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 32 / 26,
        color: color,
      );

  /// Brand wordmark on the hero.
  static TextStyle wordmark({Color color = AppColors.onPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: color,
      );

  /// Prominent brand wordmark for the dashboard header.
  /// Larger and heavier than [wordmark] to anchor the home screen.
  static TextStyle brandWordmark({Color color = AppColors.textPrimary}) =>
      GoogleFonts.fraunces(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: color,
      );

  static TextStyle title({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: color,
      );

  static TextStyle body({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: color,
      );

  static TextStyle bodyStrong({Color color = AppColors.textPrimary}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 22 / 15,
        color: color,
      );

  static TextStyle label({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 18 / 13,
        color: color,
      );

  static TextStyle button({Color color = AppColors.onPrimary}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 20 / 16,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: color,
      );
}
