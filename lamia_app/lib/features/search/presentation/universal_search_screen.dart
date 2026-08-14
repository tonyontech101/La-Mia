import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../home/presentation/widgets/feed_recipe_card.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import 'widgets/chef_search_tile.dart';

/// Full Universal Search screen for finding both Recipes and Chefs/Users.
class UniversalSearchScreen extends StatefulWidget {
  const UniversalSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RecipeRepository _recipeRepo = RecipeRepository();
  final UserRepository _userRepo = UserRepository();

  Timer? _debounceTimer;
  int _activeTab = 0; // 0: All, 1: Recipes, 2: Chefs
  bool _isLoading = false;
  bool _hasSearched = false;

  List<RecipeModel> _matchingRecipes = [];
  List<UserModel> _matchingChefs = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _matchingRecipes = [];
        _matchingChefs = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    // Debounce search query by 300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      // Execute recipe and chef search in parallel
      final results = await Future.wait([
        _recipeRepo.searchRecipes(q),
        _userRepo.searchUsers(q),
      ]);

      var recipes = results[0] as List<RecipeModel>;
      final chefs = results[1] as List<UserModel>;

      // Fallback: if Firestore prefix search on recipe name returns empty,
      // search in-memory over category/tag names from allRecipes
      if (recipes.isEmpty) {
        final all = await _recipeRepo.allRecipes(limit: 50);
        final lower = q.toLowerCase();
        recipes = all.where((r) {
          return r.name.toLowerCase().contains(lower) ||
              r.category.toLowerCase().contains(lower) ||
              r.tags.any((t) => t.toLowerCase().contains(lower)) ||
              r.region.toLowerCase().contains(lower);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _matchingRecipes = recipes;
          _matchingChefs = chefs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _matchingRecipes = [];
      _matchingChefs = [];
      _hasSearched = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              children: [
                // 1. Search Bar Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    12,
                    AppSpacing.screenH,
                    8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadii.field,
                            ),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: _onSearchChanged,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _performSearch,
                                  style: AppTypography.body(
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search recipes or chefs...',
                                    hintStyle: AppTypography.body(
                                      color: AppColors.textSecondary,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: _clearSearch,
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Filter Pills (All, Recipes, Chefs)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _FilterTabPill(
                        label: 'All',
                        count: _matchingRecipes.length + _matchingChefs.length,
                        isSelected: _activeTab == 0,
                        onTap: () => setState(() => _activeTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _FilterTabPill(
                        label: 'Recipes',
                        count: _matchingRecipes.length,
                        isSelected: _activeTab == 1,
                        onTap: () => setState(() => _activeTab = 1),
                      ),
                      const SizedBox(width: 8),
                      _FilterTabPill(
                        label: 'Chefs',
                        count: _matchingChefs.length,
                        isSelected: _activeTab == 2,
                        onTap: () => setState(() => _activeTab = 2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // 3. Search Content Body
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : !_hasSearched
                          ? _buildInitialPrompt()
                          : _buildSearchResults(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Discover Dishes & Chefs',
            style: AppTypography.title(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Type a dish name, category, or chef\'s name to search',
            style: AppTypography.caption(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final showRecipes = _activeTab == 0 || _activeTab == 1;
    final showChefs = _activeTab == 0 || _activeTab == 2;

    final hasRecipes = showRecipes && _matchingRecipes.isNotEmpty;
    final hasChefs = showChefs && _matchingChefs.isNotEmpty;

    if (!hasRecipes && !hasChefs) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: AppTypography.title(
                color: AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with a different keyword',
              style: AppTypography.caption(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenH,
        vertical: 8,
      ),
      children: [
        // Chefs Section
        if (showChefs && _matchingChefs.isNotEmpty) ...[
          _buildSectionHeader('CHEFS / USERS (${_matchingChefs.length})'),
          const SizedBox(height: 8),
          for (final user in _matchingChefs)
            ChefSearchTile(
              user: user,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(targetUserId: user.uid),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],

        // Recipes Section
        if (showRecipes && _matchingRecipes.isNotEmpty) ...[
          _buildSectionHeader('RECIPES (${_matchingRecipes.length})'),
          const SizedBox(height: 8),
          for (final recipe in _matchingRecipes)
            FeedRecipeCard(
              recipe: recipe,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: recipe),
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.caption(
        color: AppColors.textSecondary,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.8),
    );
  }
}

class _FilterTabPill extends StatelessWidget {
  const _FilterTabPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textPrimary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.onPrimary.withValues(alpha: 0.25)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
