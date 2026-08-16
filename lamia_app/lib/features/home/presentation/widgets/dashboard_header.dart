import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Top header bar matching the wireframe in image.png.
/// Shows brand logo "LaMia" with amber accent on the left, profile avatar on the right.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.displayName,
    this.userPhotoUrl,
    this.onNotificationTap,
  });

  final String displayName;
  final String? userPhotoUrl;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: LaMia brand wordmark + amber accent underline + subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LaMia', style: AppTypography.brandWordmark()),
              const SizedBox(height: AppSpacing.xxs),
              // Amber accent underline — mirrors the auth hero_header motif.
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'FILIPINO RECIPE & MEAL ASSISTANT',
                style: AppTypography.caption(color: AppColors.textSecondary)
                    .copyWith(
                      fontSize: 9,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),

          // Right: Notification icon
          GestureDetector(
            onTap: onNotificationTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
