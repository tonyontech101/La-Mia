import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_states.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import 'recipe_detail_screen.dart';

/// Displays all dataset/seeded recipes in a grid using the same card style
/// as the Featured Recipes section on the Cook tab.
///
/// This screen is reached by tapping "View All" on the Featured Recipes
/// section header.
class AllRecipesScreen extends ConsumerStatefulWidget {
  const AllRecipesScreen({super.key});

  @override
  ConsumerState<AllRecipesScreen> createState() => _AllRecipesScreenState();
}

class _AllRecipesScreenState extends ConsumerState<AllRecipesScreen> {
  RecipeRepository get _recipeRepository => ref.read(recipeRepositoryProvider);
  late Future<List<RecipeModel>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _loadRecipes();
  }

  Future<List<RecipeModel>> _loadRecipes() =>
      _recipeRepository.systemRecipes(limit: 500);

  Future<void> _refresh() async {
    setState(() => _recipesFuture = _loadRecipes());
    await _recipesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: FutureBuilder<List<RecipeModel>>(
              future: _recipesFuture,
              builder: (context, snapshot) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader()),
                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH,
                        8,
                        AppSpacing.screenH,
                        28,
                      ),
                      sliver: _buildContent(snapshot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH - 8,
        4,
        AppSpacing.screenH,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back to Cook',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: const Icon(Icons.restaurant_menu, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Recipes',
                  style: AppTypography.title(
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Browse our complete collection of Filipino recipes',
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AsyncSnapshot<List<RecipeModel>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SliverToBoxAdapter(
        child: SectionLoadingSkeleton(height: 420, isHorizontal: false),
      );
    }
    if (snapshot.hasError) {
      return SliverToBoxAdapter(
        child: SectionErrorState(
          message: 'Could not load recipes. Try again.',
          onRetry: _refresh,
        ),
      );
    }
    final recipes = snapshot.data ?? const <RecipeModel>[];
    if (recipes.isEmpty) {
      return const SliverToBoxAdapter(
        child: SectionEmptyState(
          message: 'No recipes yet',
          subtitle: 'Recipes will appear here once they are added.',
        ),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final recipe = recipes[index];
          return FadeInView(
            key: ValueKey('all-recipes-${recipe.id ?? recipe.name}'),
            delay: Duration(milliseconds: (index % 6) * 50),
            duration: const Duration(milliseconds: 400),
            offset: const Offset(0, 16),
            child: _RecipeCard(
              recipe: recipe,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipe),
                ),
              ),
            ),
          );
        },
        childCount: recipes.length,
      ),
    );
  }
}

/// Compact recipe card matching the Featured Recipes section style.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, this.onTap});

  final RecipeModel recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.97,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish Image with Tag
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.card),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: recipe.coverPhotoUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 110,
                        color: AppColors.surfaceAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 110,
                        color: const Color(0xFFE5DDD0),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF63564D),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        recipe.category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            recipe.ratingAvg > 0
                                ? recipe.ratingAvg.toStringAsFixed(1)
                                : '4.9',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: AppTypography.bodyStrong(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recipe.ingredients.take(3).join(', '),
                            style: AppTypography.caption(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.cookTime,
                            style: AppTypography.caption(
                              color: AppColors.textSecondary,
                            ).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              recipe.difficulty,
                              style: AppTypography.caption(
                                color: AppColors.textPrimary,
                              ).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
