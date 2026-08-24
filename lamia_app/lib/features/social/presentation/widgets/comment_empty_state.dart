import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/fade_in_view.dart';

/// Empty state shown when a recipe has no comments yet.
class CommentEmptyState extends StatelessWidget {
  const CommentEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return FadeInView(
      duration: const Duration(milliseconds: 380),
      offset: const Offset(0, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No comments yet',
              style: AppTypography.bodyStrong(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Be the first to share your cooking experience with this dish!',
              textAlign: TextAlign.center,
              style: AppTypography.caption(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
