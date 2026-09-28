import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_model.dart';

/// Popular Choices section matching image.png wireframe:
/// Header ("Popular Choices")
/// Vertical list of dish cards (thumbnail on left, title & details on right).
class PopularChoicesSection extends StatelessWidget {
  const PopularChoicesSection({
    super.key,
    required this.recipes,
    this.onRecipeTap,
    this.showTitle = true,
  });

  final List<RecipeModel> recipes;
  final ValueChanged<RecipeModel>? onRecipeTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Popular Choices',
            style: AppTypography.title(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recipes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return _PopularChoiceCard(
              recipe: recipe,
              onTap: () => onRecipeTap?.call(recipe),
            );
          },
        ),
      ],
    );
  }
}

class _PopularChoiceCard extends ConsumerStatefulWidget {
  const _PopularChoiceCard({required this.recipe, this.onTap});

  final RecipeModel recipe;
  final VoidCallback? onTap;

  @override
  ConsumerState<_PopularChoiceCard> createState() => _PopularChoiceCardState();
}

class _PopularChoiceCardState extends ConsumerState<_PopularChoiceCard> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSaveState();
  }

  Future<void> _loadSaveState() async {
    final userId = ref.read(currentUserIdProvider);
    final recipeId = widget.recipe.id;
    if (userId == null || recipeId == null || recipeId.isEmpty) return;
    try {
      final saved = await ref
          .read(favoritesRepositoryProvider)
          .isSaved(recipeId: recipeId, userId: userId);
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {}
  }

  Future<void> _handleBookmarkTap() async {
    final userId = ref.read(currentUserIdProvider);
    final recipeId = widget.recipe.id;
    if (userId == null) {
      AppSnackbar.show(
        context,
        message: 'Sign in to save recipes',
        isError: true,
      );
      return;
    }
    if (recipeId == null || recipeId.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Cannot save this recipe',
        isError: true,
      );
      return;
    }
    try {
      final newState = await ref
          .read(favoritesRepositoryProvider)
          .toggleSave(recipeId: recipeId, userId: userId);
      if (!mounted) return;
      setState(() => _isSaved = newState);
      AppSnackbar.show(
        context,
        message: newState ? 'Recipe saved' : 'Recipe removed from saved',
      );
    } catch (e, st) {
      AppLogger.error(
        'Error toggling bookmark from popular choices: $e',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not save recipe',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Pic of Food
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                    imageUrl: widget.recipe.coverPhotoUrl,
                  width: 90,
                  height: 85,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: 90,
                    height: 85,
                    color: AppColors.surfaceAlt,
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 90,
                    height: 85,
                    color: AppColors.surfaceAlt,
                    child: const Icon(
                      Icons.fastfood,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Right: Name of Food + Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.recipe.name,
                            style: AppTypography.bodyStrong(
                              color: AppColors.textPrimary,
                            ).copyWith(fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleBookmarkTap,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: _isSaved
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.recipe.instructions.isNotEmpty
                          ? widget.recipe.instructions.first
                          : widget.recipe.ingredients.join(', '),
                      style: AppTypography.caption(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Prep ${widget.recipe.prepTime} • Cook ${widget.recipe.cookTime}',
                            style:
                                AppTypography.caption(
                                  color: AppColors.textSecondary,
                                ).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.recipe.region,
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}
