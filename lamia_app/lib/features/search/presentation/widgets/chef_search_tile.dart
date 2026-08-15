import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/data/user_model.dart';

/// List item displaying a chef/user search result.
class ChefSearchTile extends StatelessWidget {
  const ChefSearchTile({
    super.key,
    required this.user,
    this.onTap,
  });

  final UserModel user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // User Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: ClipOval(
                child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _buildFallback(initial),
                      )
                    : _buildFallback(initial),
              ),
            ),
            const SizedBox(width: 14),

            // User Info (Name, Bio, Stats)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: AppTypography.bodyStrong(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.bio!,
                      style: AppTypography.caption(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${user.recipeCount} recipes',
                        style: AppTypography.caption(
                          color: AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${user.followerCount} followers',
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
