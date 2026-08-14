import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import 'widgets/chef_of_month_card.dart';
import 'widgets/ranked_chef_tile.dart';
import 'widgets/your_ranking_card.dart';

/// Leaderboard Screen matching the wireframe.
///
/// Sections:
/// 1. App Bar (Back, "Leaderboard" title, Hamburger)
/// 2. Chef of the Month featured card
/// 3. "Top Contributors" / "Most Cooked" tab switcher
/// 4. Top 3 ranked chefs (card-style rows)
/// 5. "TRENDING COOKS" section with compact rows
/// 6. "Your Ranking" bottom card
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _activeTab = 0; // 0 = Top Contributors, 1 = Most Cooked
  final UserRepository _userRepo = UserRepository();

  List<UserModel> _topContributors = [];
  List<UserModel> _mostLiked = [];
  bool _isLoading = true;

  /// Fallback demo data when Firestore has no registered users yet.
  static const _demoChefs = [
    _ChefData('Chef Maria Santos', 42),
    _ChefData('Lola Rosa Reyes', 38),
    _ChefData('Kuya Ben Cruz', 35),
    _ChefData('Ate Carla Domingo', 31),
    _ChefData('Tita Joy Navarro', 28),
    _ChefData('Nanay Luz Garcia', 25),
  ];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final results = await Future.wait([
        _userRepo.topContributors(limit: 10),
        _userRepo.mostLiked(limit: 10),
      ]);
      if (mounted) {
        setState(() {
          _topContributors = results[0];
          _mostLiked = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    Icons.filter_list_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Filter by Category'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category filter coming soon!'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.secondary,
                  ),
                  title: const Text('View Past Rankings'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Past rankings coming soon!'),
                      ),
                    );
                  },
                ),
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
    // Convert real user models to chef entry data, or fallback to demo list
    final realUsers = _activeTab == 0 ? _topContributors : _mostLiked;
    final List<_ChefData> data;

    if (realUsers.isNotEmpty) {
      data = realUsers
          .map(
            (u) => _ChefData(
              u.displayName,
              _activeTab == 0 ? u.recipeCount : u.totalLikesReceived,
              uid: u.uid,
            ),
          )
          .toList();
    } else {
      data = _demoChefs;
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
                          decoration: BoxDecoration(
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
                          decoration: BoxDecoration(
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
                          child: CircularProgressIndicator(color: AppColors.primary),
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
                              ChefOfMonthCard(
                                chefName: data.first.name,
                                dishName: 'Chicken Adobo sa Gata',
                                likes: data.first.count,
                                onViewProfile: () {
                                  if (data.first.uid != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          targetUserId: data.first.uid,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              const SizedBox(height: 20),

                              // 2. Tab Switcher: Top Contributors / Most Cooked
                              _LeaderboardTabSwitcher(
                                activeTab: _activeTab,
                                onTabChanged: (tab) =>
                                    setState(() => _activeTab = tab),
                              ),

                              const SizedBox(height: 16),

                              // 3. Top 3 Ranked Chefs
                              for (int i = 0; i < top3.length; i++)
                                RankedChefTile(
                                  rank: i + 1,
                                  chefName: top3[i].name,
                                  recipesShared: top3[i].count,
                                  isTopThree: true,
                                  onTap: () {
                                    if (top3[i].uid != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                            targetUserId: top3[i].uid,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),

                              const SizedBox(height: 20),

                              // 4. TRENDING COOKS header + See All
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TRENDING COOKS',
                                    style:
                                        AppTypography.caption(
                                          color: AppColors.textSecondary,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Full trending list coming soon!',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'See All',
                                      style:
                                          AppTypography.caption(
                                            color: AppColors.secondary,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
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

                              // 5. Trending Cooks rows (4, 5, 6...)
                              for (int i = 0; i < trending.length; i++)
                                RankedChefTile(
                                  rank: i + 4,
                                  chefName: trending[i].name,
                                  recipesShared: trending[i].count,
                                  isTopThree: false,
                                  onTap: () {
                                    if (trending[i].uid != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(
                                            targetUserId: trending[i].uid,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),

                              const SizedBox(height: 24),

                              // 6. Your Ranking card
                              YourRankingCard(
                                rank: 0,
                                title: 'Cooking Enthusiast',
                                spotsChange: 0,
                                onSeeFullRank: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Full ranking view coming soon!',
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
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Top Contributors',
              isActive: activeTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: 'Most Cooked',
              isActive: activeTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style:
                AppTypography.caption(
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ).copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
          ),
        ),
      ),
    );
  }
}

/// Simple data class for chef leaderboard entries.
class _ChefData {
  const _ChefData(this.name, this.count, {this.uid});
  final String name;
  final int count;
  final String? uid;
}
