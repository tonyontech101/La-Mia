import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/providers/auth_service_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/section_states.dart';
import '../../recipes/data/recipe_category_model.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/ano_pong_ulam_screen.dart';
import '../../recipes/presentation/category_recipes_screen.dart';
import '../../recipes/presentation/cook_by_ingredients_screen.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import 'widgets/categories_section.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/featured_recipes_section.dart';
import 'widgets/hero_action_cards.dart';
import 'widgets/popular_choices_section.dart';

/// Main Home Dashboard Screen for La Mia, designed based on image.png wireframe.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.isGuest = false,
    this.onNavigateToTab,
  });

  final bool isGuest;
  final ValueChanged<int>? onNavigateToTab;

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  RecipeRepository get _recipeRepository => ref.read(recipeRepositoryProvider);

  List<RecipeModel> _featuredRecipes = [];
  List<RecipeModel> _popularRecipes = [];
  bool _isLoadingFeatured = true;
  bool _isLoadingPopular = true;
  bool _hasFeaturedError = false;
  bool _hasPopularError = false;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
    _loadPopular();
  }

  /// Shuffles [recipes] in place for randomized display.
  void _shuffle(List<RecipeModel> recipes) {
    recipes.shuffle(Random());
  }

  Future<void> _loadFeatured() async {
    setState(() {
      _isLoadingFeatured = true;
      _hasFeaturedError = false;
    });
    try {
      final recipes = await _recipeRepository.featuredRecipes();
      _shuffle(recipes);
      if (mounted) {
        setState(() {
          _featuredRecipes = recipes;
          _isLoadingFeatured = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingFeatured = false;
          _hasFeaturedError = true;
        });
      }
    }
  }

  Future<void> _loadPopular() async {
    setState(() {
      _isLoadingPopular = true;
      _hasPopularError = false;
    });
    try {
      final recipes = await _recipeRepository.popularChoices();
      _shuffle(recipes);
      if (mounted) {
        setState(() {
          _popularRecipes = recipes;
          _isLoadingPopular = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPopular = false;
          _hasPopularError = true;
        });
      }
    }
  }

  /// Pull-to-refresh: reloads all sections with a fresh random order.
  Future<void> _onRefresh() async {
    await Future.wait([
      _loadFeatured(),
      _loadPopular(),
    ]);
  }

  /// Opens the category as its own collection rather than changing Cook inline.
  void _onCategoryTap(RecipeCategoryModel cat) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryRecipesScreen(category: cat)),
    );
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
    final user = ref.read(authServiceProvider).currentUser;
    final displayName = widget.isGuest
        ? 'Guest'
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Foodie');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      isGuest: widget.isGuest,
                    ),

                    const SizedBox(height: 20),

                    // 2. Hero Action Banners (Cook by Ingredients & Ano Pong Ulam?)
                    HeroActionCards(
                      onCookByIngredientsTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CookByIngredientsScreen(),
                          ),
                        );
                      },
                      onAnoPongUlamTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnoPongUlamScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // 4. Featured Recipes Section
                    _buildFeaturedSection(),

                    const SizedBox(height: 28),

                    // 5. Recipe Categories Section
                    CategoriesSection(
                      categories: RecipeCategoryModel.defaultCategories,
                      onCategoryTap: _onCategoryTap,
                    ),

                    const SizedBox(height: 28),

                    // 6. Popular Choices Section
                    _buildPopularSection(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    if (_isLoadingFeatured) {
      return const SectionLoadingSkeleton(height: 220);
    }
    if (_hasFeaturedError) {
      return SectionErrorState(
        message:
            'Could not load featured recipes. Check your connection and try again.',
        onRetry: _loadFeatured,
      );
    }
    if (_featuredRecipes.isEmpty) {
      return const SectionEmptyState(
        message: 'No featured recipes yet',
        subtitle: 'Recipes will appear here once they are added.',
      );
    }
    return FadeInView(
      key: ValueKey('featured-${_featuredRecipes.length}'),
      duration: const Duration(milliseconds: 450),
      offset: const Offset(0, 14),
      child: FeaturedRecipesSection(
        recipes: _featuredRecipes,
        onViewAllTap: () => widget.onNavigateToTab?.call(1),
        onRecipeTap: _showRecipeDetailsDialog,
      ),
    );
  }

  Widget _buildPopularSection() {
    if (_isLoadingPopular) {
      return const SectionLoadingSkeleton(
        height: 360,
        isHorizontal: false,
      );
    }
    if (_hasPopularError) {
      return SectionErrorState(
        message:
            'Could not load popular choices. Check your connection and try again.',
        onRetry: _loadPopular,
      );
    }
    if (_popularRecipes.isEmpty) {
      return const SectionEmptyState(
        message: 'No popular choices yet',
        subtitle:
            'Popular recipes will appear here as more people cook.',
      );
    }
    return FadeInView(
      key: ValueKey('popular-${_popularRecipes.length}'),
      duration: const Duration(milliseconds: 450),
      offset: const Offset(0, 14),
      child: PopularChoicesSection(
        recipes: _popularRecipes,
        onRecipeTap: _showRecipeDetailsDialog,
      ),
    );
  }
}
