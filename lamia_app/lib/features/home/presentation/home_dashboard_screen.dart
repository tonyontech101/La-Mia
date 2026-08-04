import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/section_states.dart';
import '../../recipes/data/recipe_category_model.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
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
