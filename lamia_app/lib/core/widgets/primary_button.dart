import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Full-width filled primary action button.
///
/// Stays a fixed height in every state; while [isLoading] the label is swapped
/// for an in-button spinner and taps are ignored.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final interactive = !isLoading && onPressed != null;
    final labelColor = interactive ? AppColors.onPrimary : AppColors.textSecondary;
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.button),
          boxShadow: interactive
              ? const [
                  BoxShadow(
                    color: Color(0x47C4462B), // primary @ ~0.28
                    offset: Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor:
                isLoading ? AppColors.primary : AppColors.primaryDisabled,
            foregroundColor: AppColors.onPrimary,
            disabledForegroundColor: AppColors.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Color(0x1AFFFFFF)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (isLoading) return AppColors.primary;
              if (states.contains(WidgetState.pressed)) {
                return AppColors.primaryDark;
              }
              return AppColors.primary;
            }),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onPrimary,
                  ),
                )
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text(
                    label,
                    style: AppTypography.button(color: labelColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
      ),
    );
  }
}
