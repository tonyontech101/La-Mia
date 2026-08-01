import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Top header bar matching the wireframe in image.png.
/// Shows avatar, brand logo "LaMia", and subtitle.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.displayName,
    this.userPhotoUrl,
    this.onProfileTap,
  });

  final String displayName;
  final String? userPhotoUrl;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: User Avatar + LaMia Brand Title
          GestureDetector(
            onTap: onProfileTap,
            child: Row(
              children: [
                Container(
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
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LaMia',
                      style: AppTypography.wordmark(color: AppColors.textPrimary),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
