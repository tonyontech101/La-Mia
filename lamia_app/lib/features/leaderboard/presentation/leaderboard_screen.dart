import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import 'widgets/chef_of_month_card.dart';
import 'widgets/ranked_chef_tile.dart';
import '../presentation/full_ranking_screen.dart';
import 'widgets/your_ranking_card.dart';

/// Leaderboard Screen with three ranking dimensions:
///
/// 1. **Chef of the Month** — resets each calendar month; ranks cooks by the
///    total likes + favorites their recipes received during the current month.
/// 2. **Top Contributors** — ranks cooks by their follower count (community reach).
/// 3. **Most Cooked** — ranks cooks by how many recipes they've shared on the platform.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _activeTab = 0; // 0 = Top Contributors, 1 = Most Cooked
  final UserRepository _userRepo = UserRepository();
  final RecipeRepository _recipeRepo = RecipeRepository();

  List<UserModel> _topContributors = [];
  List<UserModel> _mostCooked = [];
  _ChefOfMonthData? _chefOfMonth;
  bool _isLoading = true;

  /// Generation counter to discard stale leaderboard loads.
  int _loadGeneration = 0;

  /// Current user's ranking info.
  int _currentUserRank = 0;
  String _currentUserTitle = 'Cooking Enthusiast';
  int _currentUserSpotsChange = 0;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final generation = ++_loadGeneration;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userRepo.topContributorsByFollowers(limit: 10),
        _userRepo.mostCookedByUploadedRecipes(limit: 10),
        _computeChefOfMonth(),
        _getCurrentUserRanking(),
      ]);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _topContributors = results[0] as List<UserModel>;
          _mostCooked = results[1] as List<UserModel>;
          _chefOfMonth = results[2] as _ChefOfMonthData?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Picks the author of this month's currently most-popular uploaded dish.
  /// The recipe list is evaluated against the current date whenever the
  /// leaderboard loads, so the winner rolls over automatically each month.
  Future<_ChefOfMonthData?> _computeChefOfMonth() async {
    try {
      final monthRecipes = await _recipeRepo.recipesCreatedThisMonth();
      if (monthRecipes.isEmpty) return null;

      final winningRecipe = monthRecipes.first;
      final authorId = winningRecipe.authorId;
      if (authorId == null) return null;
      final user = await _userRepo.getUser(authorId);

      return _ChefOfMonthData(
        uid: authorId,
        name: user?.displayName ?? winningRecipe.authorName,
        score: winningRecipe.likeCount,
        topRecipeName: winningRecipe.name,
        topRecipeImageUrl: winningRecipe.coverPhotoUrl,
        winningRecipe: winningRecipe,
      );
    } catch (_) {
      return null;
    }
  }

  /// Finds the current user's rank in both tabs.
  Future<void> _getCurrentUserRanking() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final user = await _userRepo.getUser(currentUser.uid);
      if (user == null) return;

      // Find rank in Top Contributors (by followers)
      final allContributors = await _userRepo.topContributorsByFollowers(limit: 100);
      int rank = 0;
      for (int i = 0; i < allContributors.length; i++) {
        if (allContributors[i].uid == currentUser.uid) {
          rank = i + 1;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _currentUserRank = rank;
          _currentUserTitle = _getTitleForRank(rank);
          _currentUserSpotsChange = 0; // TODO: track historical rank for delta
        });
      }
    } catch (_) {}
  }

  String _getTitleForRank(int rank) {
    if (rank <= 0) return 'Newcomer';
    if (rank == 1) return 'Head Chef';
    if (rank <= 3) return 'Sous Chef';
    if (rank <= 10) return 'Line Cook';
    if (rank <= 25) return 'Kitchen Hand';
    return 'Cooking Enthusiast';
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Leaderboard Options',
                  style: AppTypography.title(
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.share_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text('Share Leaderboard'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sharing coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final realUsers = _activeTab == 0 ? _topContributors : _mostCooked;
    final List<_ChefData> data;

    if (realUsers.isNotEmpty) {
      data = realUsers
          .map(
            (u) => _ChefData(
              u.displayName,
              _activeTab == 0 ? u.followerCount : u.recipeCount,
              uid: u.uid,
              photoUrl: u.photoUrl,
            ),
          )
          .toList();
    } else {
      data = [];
    }

    final top3 = data.take(3).toList();
    final trending = data.skip(3).toList();

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
                // ── App Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back arrow
                      GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            widget.onNavigateHome?.call();
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceAlt,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        'Leaderboard',
                        style: AppTypography.title(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                      ),

                      // Hamburger menu
                      GestureDetector(
                        onTap: () => _showOptionsMenu(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceAlt,
                          ),
                          child: const Icon(
                            Icons.menu_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Content ──
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenH,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),

                              // 1. Chef of the Month
                              if (_chefOfMonth != null)
                                ChefOfMonthCard(
                                  chefName: _chefOfMonth!.name,
                                  dishName: _chefOfMonth!.topRecipeName ?? '',
                                  likes: _chefOfMonth!.score,
                                  recipeId: _chefOfMonth!.winningRecipe.id,
                                  imageUrl: _chefOfMonth!.topRecipeImageUrl,
                                  onViewProfile: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          targetUserId: _chefOfMonth!.uid,
                                        ),
                                      ),
                                    );
                                  },
                                  onViewDish: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RecipeDetailScreen(
                                          recipe: _chefOfMonth!.winningRecipe,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else
                                _buildNoChefOfMonth(),

                              const SizedBox(height: 20),

                              // 2. Tab Switcher: Top Contributors / Most Cooked
                              _LeaderboardTabSwitcher(
                                activeTab: _activeTab,
                                onTabChanged: (tab) =>
                                    setState(() => _activeTab = tab),
                              ),

                              const SizedBox(height: 16),

                              // 3. Tab description
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _activeTab == 0
                                      ? 'Ranked by number of followers'
                                      : 'Ranked by number of recipes uploaded',
                                  style: AppTypography.caption(
                                    color: AppColors.textSecondary,
                                  ).copyWith(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                              // 4. Top 3 Ranked Chefs
                              if (top3.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'No chefs ranked yet',
                                      style: AppTypography.body(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                for (int i = 0; i < top3.length; i++)
                                  RankedChefTile(
                                    rank: i + 1,
                                    chefName: top3[i].name,
                                    recipesShared: top3[i].count,
                                    isTopThree: true,
                                    metricLabel: _activeTab == 0
                                        ? 'followers'
                                        : 'recipes uploaded',
                                    photoUrl: top3[i].photoUrl,
                                    onTap: () {
                                      if (top3[i].uid != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                              targetUserId: top3[i].uid!,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),

                              const SizedBox(height: 20),

                              // 5. TRENDING COOKS header + See All
                              if (trending.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TRENDING COOKS',
                                      style: AppTypography.caption(
                                        color: AppColors.textSecondary,
                                      ).copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FullRankingScreen(
                                              initialTab: _activeTab,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'See All',
                                        style: AppTypography.caption(
                                          color: AppColors.secondary,
                                        ).copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Divider
                                const Divider(
                                  height: 16,
                                  color: AppColors.border,
                                ),

                                // 6. Trending Cooks rows (4, 5, 6...)
                                for (int i = 0; i < trending.length; i++)
                                  RankedChefTile(
                                    rank: i + 4,
                                    chefName: trending[i].name,
                                    recipesShared: trending[i].count,
                                    isTopThree: false,
                                    metricLabel: _activeTab == 0
                                        ? 'followers'
                                        : 'recipes uploaded',
                                    photoUrl: trending[i].photoUrl,
                                    onTap: () {
                                      if (trending[i].uid != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                              targetUserId: trending[i].uid!,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                              ],

                              const SizedBox(height: 24),

                              // 7. Your Ranking card
                              YourRankingCard(
                                rank: _currentUserRank,
                                title: _currentUserTitle,
                                spotsChange: _currentUserSpotsChange,
                                onSeeFullRank: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FullRankingScreen(
                                        initialTab: _activeTab,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 32),
                            ],
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

  Widget _buildNoChefOfMonth() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chef of the Month',
            style: AppTypography.title(
              color: AppColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'No recipes shared this month yet.\nBe the first to earn this title!',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Tab switcher for "Top Contributors" / "Most Cooked".
class _LeaderboardTabSwitcher extends StatelessWidget {
  const _LeaderboardTabSwitcher({
    required this.activeTab,
    required this.onTabChanged,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: SlidingTabBar(
        index: activeTab,
        itemCount: 2,
        highlight: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        onChanged: onTabChanged,
        builder: (context, i, isActive) {
          const labels = ['Top Contributors', 'Most Cooked'];
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: AppTypography.caption(
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ).copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                child: Text(labels[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Simple data class for chef leaderboard entries.
class _ChefData {
  const _ChefData(this.name, this.count, {this.uid, this.photoUrl});
  final String name;
  final int count;
  final String? uid;
  final String? photoUrl;
}

/// Data class for the Chef of the Month computation result.
class _ChefOfMonthData {
  const _ChefOfMonthData({
    required this.uid,
    required this.name,
    required this.score,
    this.topRecipeName,
    this.topRecipeImageUrl,
    required this.winningRecipe,
  });

  final String uid;
  final String name;
  final int score;
  final String? topRecipeName;
  final String? topRecipeImageUrl;
  final RecipeModel winningRecipe;
}
