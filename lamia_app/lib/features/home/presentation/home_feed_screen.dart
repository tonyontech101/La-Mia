import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import 'widgets/feed_app_bar.dart';
import 'widgets/feed_recipe_card.dart';
import 'widgets/search_bar_widget.dart';

/// New Home Feed Screen — social-style recipe feed with
/// "Following" / "For You" tabs, matching the wireframe.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    super.key,
    this.isGuest = false,
    this.onNavigateToTab,
  });

  final bool isGuest;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int _activeTab = 1; // 0 = Following, 1 = For You (default)
  final RecipeRepository _recipeRepository = RecipeRepository();

  List<RecipeModel> _recipes = [];
  bool _isLoading = true;
  bool _hasError = false;

  /// Dummy Filipino usernames for visual variety in the feed.
  static const _dummyUsernames = [
    'Chef Maria',
    'Lola Rosa',
    'Kuya Ben',
    'Ate Carla',
    'Tita Joy',
    'Nanay Luz',
    'Chef Paolo',
    'Inay Dina',
    'Tito Romy',
    'Manang Cely',
    'Chef Andrei',
    'Ate Bea',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final recipes = await _recipeRepository.allRecipes(limit: 20);
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Returns a shuffled/filtered subset depending on the active tab.
  List<RecipeModel> _getTabRecipes() {
    if (_recipes.isEmpty) return [];
    if (_activeTab == 0) {
      // "Following" — show a subset (simulate followed users' posts)
      return _recipes.where((r) => r.tags.contains('Comfort Food') ||
          r.tags.contains('Traditional')).toList();
    }
    // "For You" — show all recipes
    return _recipes;
  }

  String _getDummyUsername(int index) {
    return _dummyUsernames[index % _dummyUsernames.length];
  }

  void _onRecipeTap(RecipeModel recipe) {
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

    final tabRecipes = _getTabRecipes();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: Column(
              children: [
                // Fixed header section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Column(
                    children: [
                      // 1. App Bar (avatar, La Mia, hamburger)
                      FeedAppBar(
                        displayName: displayName,
                        isGuest: widget.isGuest,
                      ),

                      const SizedBox(height: 12),

                      // 2. Search Bar (hybrid element retained from old Home)
                      SearchBarWidget(
                        onTap: () {
                          // Navigate to Cook tab (former dashboard)
                          widget.onNavigateToTab?.call(1);
                        },
                      ),

                      const SizedBox(height: 16),

                      // 3. Following / For You tab switcher
                      _FeedTabSwitcher(
                        activeTab: _activeTab,
                        onTabChanged: (tab) =>
                            setState(() => _activeTab = tab),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Scrollable feed
                Expanded(
                  child: _isLoading
                      ? _buildLoadingSkeleton()
                      : _hasError
                          ? _buildErrorState()
                          : tabRecipes.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  color: AppColors.primary,
                                  onRefresh: _loadRecipes,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.screenH,
                                      vertical: 8,
                                    ),
                                    itemCount: tabRecipes.length,
                                    itemBuilder: (context, index) {
                                      final recipe = tabRecipes[index];
                                      return FeedRecipeCard(
                                        recipe: recipe,
                                        dummyUsername:
                                            _getDummyUsername(index),
                                        onTap: () => _onRecipeTap(recipe),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 260,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load the feed',
              style: AppTypography.title(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadRecipes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _activeTab == 0
                  ? 'No posts from people you follow'
                  : 'No recipes to show yet',
              style: AppTypography.title(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _activeTab == 0
                  ? 'Follow home cooks to see their dishes here.'
                  : 'Recipes will appear once they are added.',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Following" / "For You" tab switcher matching the wireframe.
///
/// Centered text with an underline on the active tab.
class _FeedTabSwitcher extends StatelessWidget {
  const _FeedTabSwitcher({
    required this.activeTab,
    required this.onTabChanged,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TabItem(
          label: 'Following',
          isActive: activeTab == 0,
          onTap: () => onTabChanged(0),
        ),
        const SizedBox(width: 28),
        _TabItem(
          label: 'For You',
          isActive: activeTab == 1,
          onTap: () => onTabChanged(1),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodyStrong(
            color: isActive
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ).copyWith(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
