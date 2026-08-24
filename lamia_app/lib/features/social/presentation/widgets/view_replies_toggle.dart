import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// "View N replies" / "Hide replies" toggle affordance.
class ViewRepliesToggle extends StatelessWidget {
  const ViewRepliesToggle({
    super.key,
    required this.replyCount,
    required this.isExpanded,
    required this.onToggle,
  });

  final int replyCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              isExpanded
                  ? 'Hide replies'
                  : 'View ${replyCount == 1 ? "1 reply" : "$replyCount replies"}',
              style: AppTypography.label(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
