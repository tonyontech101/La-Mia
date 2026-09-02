import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/fade_in_view.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_model.dart';

/// 3-column grid of Dish Cards matching the wireframe layout.
///
/// Features:
/// - 3 columns of vertical rectangular dish cards
/// - Full-bleed dish cover photo with rounded corners
/// - Bottom shadow gradient overlay (scrim)
/// - Bottom stats row: Heart icon + likes count, Bookmark icon + saves count
/// - Dish name label overlay
class DishCardGrid extends StatelessWidget {
  const DishCardGrid({
    super.key,
    required this.recipes,
    this.onRecipeTap,
    this.onRecipeLongPress,
    this.emptyMessage = 'No items to display',
    this.isLoading = false,
  });

  final List<RecipeModel> recipes;
  final ValueChanged<RecipeModel>? onRecipeTap;
  final ValueChanged<RecipeModel>? onRecipeLongPress;
  final String emptyMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (recipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: AppTypography.body(
                  color: AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: recipes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.70,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return FadeInView(
          key: ValueKey<String>('dish-${recipe.id ?? recipe.name}'),
          delay: Duration(milliseconds: (index % 6) * 50),
          duration: const Duration(milliseconds: 350),
          offset: const Offset(0, 12),
          child: _DishCard(
            recipe: recipe,
            onTap: () => onRecipeTap?.call(recipe),
            onLongPress: onRecipeLongPress != null
                ? () => onRecipeLongPress?.call(recipe)
                : null,
          ),
        );
      },
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.recipe,
    required this.onTap,
    this.onLongPress,
  });

  final RecipeModel recipe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  String _formatStat(int count) {
    if (count >= 1000000) {
      final formatted = (count / 1000000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}M';
    } else if (count >= 1000) {
      final formatted = (count / 1000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final likeCountStr = _formatStat(recipe.likeCount);
    final saveCountStr = _formatStat(recipe.favoriteCount);

    return PressableScale(
      pressedScale: 0.94,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full-bleed Dish Image
              if (recipe.coverPhotoUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: recipe.coverPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // 2. Bottom Shadow Overlay / Scrim
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.30, 0.60, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Overlay Content (Dish Name & Like / Bookmark counters)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dish Name
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 5),

                    // Stats Row: [🤍 Likes]  [🔖 Saves]
                    Row(
                      children: [
                        // Likes counter
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 15.5,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              likeCountStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Saves / Bookmarks counter
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              size: 15.5,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              saveCountStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: 32,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Dish Image',
            style: AppTypography.caption(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ).copyWith(fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
