import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/section_states.dart';
import '../../recipes/data/recipe_category_model.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import 'widgets/categories_section.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/featured_recipes_section.dart';
import 'widgets/hero_action_cards.dart';
import 'widgets/popular_choices_section.dart';
import 'widgets/search_bar_widget.dart';

/// Main Home Dashboard Screen for La Mia, designed based on image.png wireframe.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.isGuest = false,
    this.onNavigateToTab,
  });

  final bool isGuest;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  String? _selectedCategoryId;

  final RecipeRepository _recipeRepository = RecipeRepository();
  late Future<List<RecipeModel>> _featuredFuture;
  late Future<List<RecipeModel>> _popularFuture;

  @override
  void initState() {
    super.initState();
    _featuredFuture = _recipeRepository.featuredRecipes();
    _popularFuture = _recipeRepository.popularChoices();
  }

  /// Retries loading featured recipes after an error.
  void _retryFeatured() {
    setState(() {
      _featuredFuture = _recipeRepository.featuredRecipes();
    });
  }

  /// Retries loading popular choices after an error.
  void _retryPopular() {
    setState(() {
      _popularFuture = _recipeRepository.popularChoices();
    });
  }

  void _showRecipeDetailsDialog(RecipeModel recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
          ),
          child: Column(
            children: [
              // Header Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                    child: CachedNetworkImage(
                      imageUrl: recipe.coverPhotoUrl,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        height: 220,
                        color: AppColors.surfaceAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        height: 220,
                        color: AppColors.surfaceAlt,
                        child: const Icon(Icons.restaurant, size: 48, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),

              // Details Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: ListView(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              recipe.category.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            recipe.region,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Prep: ${recipe.prepTime} | Cook: ${recipe.cookTime}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.group_outlined, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text('${recipe.servings} Servings'),
                        ],
                      ),
                      const Divider(height: 32),

                      // Ingredients
                      const Text(
                        'Ingredients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...recipe.ingredients.map((ing) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Expanded(child: Text(ing)),
                              ],
                            ),
                          )),

                      const SizedBox(height: 20),

                      // Instructions
                      const Text(
                        'Step-by-Step Instructions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...recipe.instructions.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = widget.isGuest
        ? 'Guest'
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Foodie');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Dashboard Top Header Bar
                  DashboardHeader(
                    displayName: displayName,
                    onProfileTap: () => widget.onNavigateToTab?.call(3),
                  ),

                  const SizedBox(height: 16),

                  // 2. Search Bar Widget
                  SearchBarWidget(
                    onTap: () {
                      // Navigate to search / cook tab
                      widget.onNavigateToTab?.call(1);
                    },
                  ),

                  const SizedBox(height: 24),

                  // 3. Hero Action Banners (Cook by Ingredients & Ano Pong Ulam?)
                  HeroActionCards(
                    onCookByIngredientsTap: () => widget.onNavigateToTab?.call(1),
                    onAnoPongUlamTap: () => widget.onNavigateToTab?.call(2),
                  ),

                  const SizedBox(height: 28),

                  // 4. Featured Recipes Section
                  FutureBuilder<List<RecipeModel>>(
                    future: _featuredFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SectionLoadingSkeleton(height: 220);
                      }
                      if (snapshot.hasError) {
                        return SectionErrorState(
                          message:
                              'Could not load featured recipes. Check your connection and try again.',
                          onRetry: _retryFeatured,
                        );
                      }
                      final recipes = snapshot.data ?? [];
                      if (recipes.isEmpty) {
                        return const SectionEmptyState(
                          message: 'No featured recipes yet',
                          subtitle:
                              'Recipes will appear here once they are added.',
                        );
                      }
                      return FeaturedRecipesSection(
                        recipes: recipes,
                        onViewAllTap: () =>
                            widget.onNavigateToTab?.call(1),
                        onRecipeTap: _showRecipeDetailsDialog,
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // 5. Recipe Categories Section
                  CategoriesSection(
                    categories: RecipeCategoryModel.defaultCategories,
                    selectedCategoryId: _selectedCategoryId,
                    onCategoryTap: (cat) {
                      setState(() {
                        _selectedCategoryId =
                            _selectedCategoryId == cat.id ? null : cat.id;
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  // 6. Popular Choices Section
                  FutureBuilder<List<RecipeModel>>(
                    future: _popularFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SectionLoadingSkeleton(
                          height: 360,
                          isHorizontal: false,
                        );
                      }
                      if (snapshot.hasError) {
                        return SectionErrorState(
                          message:
                              'Could not load popular choices. Check your connection and try again.',
                          onRetry: _retryPopular,
                        );
                      }
                      final recipes = snapshot.data ?? [];
                      if (recipes.isEmpty) {
                        return const SectionEmptyState(
                          message: 'No popular choices yet',
                          subtitle:
                              'Popular recipes will appear here as more people cook.',
                        );
                      }
                      return PopularChoicesSection(
                        recipes: recipes,
                        onRecipeTap: _showRecipeDetailsDialog,
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
