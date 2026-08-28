import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Reusable modal loading dialog used for asynchronous actions like deleting,
/// uploading, or syncing data.
abstract final class AppLoadingDialog {
  /// Displays a modal loading indicator that cannot be dismissed by tapping outside.
  static void show(
    BuildContext context, {
    String message = 'Please wait...',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      message,
                      style: AppTypography.body(color: AppColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Closes the currently shown loading dialog if mounted.
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Runs an async [action] while displaying a loading dialog, ensuring the
  /// dialog is always dismissed when the action completes or throws an error.
  static Future<T?> runWithLoading<T>(
    BuildContext context,
    Future<T> Function() action, {
    String message = 'Please wait...',
  }) async {
    show(context, message: message);
    try {
      final result = await action();
      if (context.mounted) {
        hide(context);
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        hide(context);
      }
      rethrow;
    }
  }
}
