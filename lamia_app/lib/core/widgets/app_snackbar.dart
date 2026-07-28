import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Floating, branded snackbars used for stubbed auth feedback.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    final icon = isError ? Icons.error_outline : Icons.check_circle;
    final iconColor = isError ? AppColors.error : AppColors.success;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body(color: AppColors.surface),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
