import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_repository.dart';

/// "Chef of the Month" featured card at the top of the Leaderboard.
///
/// Shows a large dish image area, crown icon, chef name, dish name,
/// like count, and a "View Profile" button.
class ChefOfMonthCard extends StatelessWidget {
  const ChefOfMonthCard({
    super.key,
    required this.chefName,
    required this.dishName,
    required this.likes,
    this.recipeId,
    this.imageUrl,
    this.onViewProfile,
    this.onViewDish,
  });

  final String chefName;
  final String dishName;
  final int likes;
  final String? recipeId;
  final String? imageUrl;
  final VoidCallback? onViewProfile;
  final VoidCallback? onViewDish;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dish image area with crown overlay
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: GestureDetector(
              onTap: onViewDish,
              child: Stack(
                children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: AppColors.surfaceAlt,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, _, _) => _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                  ),
                ),
                // Crown icon centered
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),

          // Info section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "CHEF OF THE MONTH" badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    'CHEF OF THE MONTH',
                    style: AppTypography.caption(color: AppColors.onPrimary)
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),

                const SizedBox(height: 10),

                // Chef name, dish, likes + View Profile button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Featured Chef\'s Name',
                            style:
                                AppTypography.caption(
                                  color: AppColors.textSecondary,
                                ).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chefName,
                            style:
                                AppTypography.title(
                                  color: AppColors.textPrimary,
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dishName,
                            style: AppTypography.body(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              _LiveLikeCount(
                                recipeId: recipeId,
                                initialLikes: likes,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // View Profile button
                    PressableScale(
                      pressedScale: 0.92,
                      child: GestureDetector(
                        onTap: onViewProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            'View Profile',
                            style:
                                AppTypography.caption(
                                  color: AppColors.onPrimary,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ),
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

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_rounded,
              size: 40,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Dish Image with\nOverlay',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveLikeCount extends StatelessWidget {
  const _LiveLikeCount({required this.recipeId, required this.initialLikes});

  final String? recipeId;
  final int initialLikes;

  @override
  Widget build(BuildContext context) {
    if (recipeId == null) return _label(initialLikes);
    return StreamBuilder(
      stream: RecipeRepository().watchRecipe(recipeId!),
      builder: (context, snapshot) => _label(
        snapshot.data?.likeCount ?? initialLikes,
      ),
    );
  }

  Widget _label(int count) => Text(
    '$count Likes',
    style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
      fontSize: 11,
    ),
  );
}
