import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/fade_in_view.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_model.dart';

/// 2-column grid of Dish Cards matching the wireframe layout.
///
/// Displays Dish Image top section and Dish Name + Description bottom block.
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
              Icon(
                Icons.restaurant_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: AppTypography.body(color: AppColors.textSecondary),
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
        crossAxisCount: 2,
        childAspectRatio: 0.76,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return FadeInView(
          key: ValueKey<String>('dish-${recipe.name}'),
          delay: Duration(milliseconds: (index % 4) * 70),
          duration: const Duration(milliseconds: 420),
          offset: const Offset(0, 16),
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

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.96,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Dish Image Section
              Expanded(
                child: Container(
                  color: AppColors.surfaceAlt,
                  child: recipe.coverPhotoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.coverPhotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.surfaceAlt,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.soup_kitchen_rounded,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),

              // 2. Dish Name & Description Container (Wireframe style)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.name,
                      style: AppTypography.label(
                        color: AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recipe.category} • ${recipe.cookTime}',
                      style: AppTypography.caption(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 11),
                      maxLines: 1,
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Dish Image',
            style: AppTypography.caption(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
