import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_model.dart';

/// Full-width social-feed recipe card matching the wireframe layout.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │         [Recipe Cover Photo]         │
/// │         (16:10 aspect ratio)         │
/// ├──────────────────────────────────────┤
/// │ 🟤 @ username   [45 mins] [Breakfast]│
/// │ Dish Name (title, bold)              │
/// │ the description of the dish...       │
/// └──────────────────────────────────────┘
/// ```
class FeedRecipeCard extends StatelessWidget {
  const FeedRecipeCard({super.key, required this.recipe, this.onTap});

  final RecipeModel recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.985,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe cover photo
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: recipe.coverPhotoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.coverPhotoUrl,
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
                          errorWidget: (_, _, _) => _buildPhotoPlaceholder(),
                        )
                      : _buildPhotoPlaceholder(),
                ),
              ),

              // Info section below the photo
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username row + tag pills
                    Row(
                      children: [
                        // Author avatar circle
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: recipe.isSystemRecipe
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.primary.withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: recipe.isSystemRecipe
                                ? const Icon(
                                    Icons.restaurant_rounded,
                                    size: 13,
                                    color: AppColors.primary,
                                  )
                                : Text(
                                    recipe.authorName.isNotEmpty
                                        ? recipe.authorName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Author name
                        Flexible(
                          child: Text(
                            '@ ${recipe.authorName}',
                            style:
                                AppTypography.caption(
                                  color: AppColors.textSecondary,
                                ).copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // System recipe badge
                        if (recipe.isSystemRecipe) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Original',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Tag pills: cook time + category
                        _TagPill(
                          label: recipe.approximateCookTime,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        _TagPill(
                          label: recipe.category,
                          color: AppColors.primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Dish Name
                    Text(
                      recipe.name,
                      style: AppTypography.title(
                        color: AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Description — derived from ingredients/tags as a brief summary
                    Text(
                      _buildDescription(),
                      style: AppTypography.body(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a brief description from recipe data.
  String _buildDescription() {
    // Combine region, difficulty, servings into a readable sentence
    final parts = <String>[];
    if (recipe.region.isNotEmpty && recipe.region != 'Unknown') {
      parts.add('A ${recipe.region} dish');
    } else {
      parts.add('A Filipino dish');
    }
    if (recipe.difficulty.isNotEmpty) {
      parts.add('${recipe.difficulty.toLowerCase()} difficulty');
    }
    if (recipe.servings > 0) {
      parts.add('serves ${recipe.servings}');
    }
    if (recipe.tags.isNotEmpty) {
      final tagStr = recipe.tags.take(3).join(', ');
      parts.add(tagStr);
    }
    return '${parts.join(' · ')}.';
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 48,
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Small rounded tag pill used for cook time and category.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: AppTypography.caption(
          color: color,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
      ),
    );
  }
}
