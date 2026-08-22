import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import 'widgets/ranked_chef_tile.dart';

/// Full ranking screen showing all ranked chefs with two tabs:
/// Top Contributors (by followers) and Most Cooked (by recipe count).
///
/// Navigated to from the leaderboard's "See Full Rank" button or
/// "TRENDING COOKS" See All link.
class FullRankingScreen extends StatefulWidget {
  const FullRankingScreen({super.key, this.initialTab = 0});

  /// 0 = Top Contributors, 1 = Most Cooked.
  final int initialTab;

  @override
  State<FullRankingScreen> createState() => _FullRankingScreenState();
}

class _FullRankingScreenState extends State<FullRankingScreen> {
  int _activeTab = 0;
  final UserRepository _userRepo = UserRepository();

  List<UserModel> _topContributors = [];
  List<UserModel> _mostCooked = [];
  bool _isLoading = true;

  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadAllRankings();
  }

  Future<void> _loadAllRankings() async {
    final generation = ++_loadGeneration;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _userRepo.topContributorsByFollowers(limit: 100),
        _userRepo.mostCookedByUploadedRecipes(limit: 100),
      ]);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _topContributors = results[0];
          _mostCooked = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = _activeTab == 0 ? _topContributors : _mostCooked;
    final metricLabel = _activeTab == 0 ? 'followers' : 'recipes uploaded';

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
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
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
                      const SizedBox(width: 12),

                      // Title
                      Text(
                        'Full Ranking',
                        style: AppTypography.title(
                          color: AppColors.textPrimary,
                        ).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab Switcher ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: _FullRankingTabSwitcher(
                    activeTab: _activeTab,
                    onTabChanged: (tab) =>
                        setState(() => _activeTab = tab),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Description ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
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
                ),

                const SizedBox(height: 8),

                // ── Scrollable List ──
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : activeUsers.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No chefs ranked yet',
                                  style: AppTypography.body(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenH,
                                vertical: 8,
                              ),
                              itemCount: activeUsers.length,
                              itemBuilder: (context, index) {
                                final user = activeUsers[index];
                                final count = _activeTab == 0
                                    ? user.followerCount
                                    : user.recipeCount;

                                return RankedChefTile(
                                  rank: index + 1,
                                  chefName: user.displayName,
                                  recipesShared: count,
                                  isTopThree: index < 3,
                                  metricLabel: metricLabel,
                                  photoUrl: user.photoUrl,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          targetUserId: user.uid,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab switcher matching the leaderboard screen style.
class _FullRankingTabSwitcher extends StatelessWidget {
  const _FullRankingTabSwitcher({
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
