import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/page_transitions.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the app-wide Material 3 theme from the La Mia design tokens.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(),
      splashFactory: InkRipple.splashFactory,
      // Fluid fade + zoom + rise on every MaterialPageRoute push/pop.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: LaMiaPageTransitionsBuilder(),
          TargetPlatform.iOS: LaMiaPageTransitionsBuilder(),
          TargetPlatform.macOS: LaMiaPageTransitionsBuilder(),
          TargetPlatform.windows: LaMiaPageTransitionsBuilder(),
          TargetPlatform.linux: LaMiaPageTransitionsBuilder(),
          TargetPlatform.fuchsia: LaMiaPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.body(color: AppColors.surface),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.snackbar),
        ),
      ),
    );
  }
}
