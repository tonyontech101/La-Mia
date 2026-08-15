import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';

/// Three-segment password strength indicator with a right-aligned label.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.strength});

  final PasswordStrength strength;

  Color get _color => switch (strength) {
    PasswordStrength.empty => AppColors.border,
    PasswordStrength.weak => AppColors.error,
    PasswordStrength.okay => AppColors.accent,
    PasswordStrength.strong => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Password strength',
      value: strength == PasswordStrength.empty ? 'None' : strength.label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength.segments ? _color : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: AppSpacing.xxs),
          ],
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(44),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style: AppTypography.caption(color: _color),
              child: Text(
                strength.label,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
