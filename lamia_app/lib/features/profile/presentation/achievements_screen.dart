import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Model representing a single user achievement / badge.
class AchievementItem {
  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.xpReward,
    required this.currentProgress,
    required this.maxProgress,
    required this.isUnlocked,
    this.badgeColor = AppColors.primary,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final int xpReward;
  final int currentProgress;
  final int maxProgress;
  final bool isUnlocked;
  final Color badgeColor;

  double get progressPercentage =>
      (currentProgress / maxProgress).clamp(0.0, 1.0);
}

/// A dedicated, beautiful Achievements & Badges screen for La Mia cooks.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Culinary, 2: Community, 3: Classics

  final List<AchievementItem> _achievements = const [
    AchievementItem(
      id: 'first_dish',
      title: 'First Sizzle',
      description: 'Publish your very first recipe to the community.',
      icon: Icons.soup_kitchen_rounded,
      category: 'Culinary',
      xpReward: 50,
      currentProgress: 1,
      maxProgress: 1,
      isUnlocked: true,
      badgeColor: AppColors.primary,
    ),
    AchievementItem(
      id: 'adobo_master',
      title: 'Adobo Master',
      description: 'Cook or share 3 different variations of classic Adobo.',
      icon: Icons.restaurant_rounded,
      category: 'Classics',
      xpReward: 100,
      currentProgress: 2,
      maxProgress: 3,
      isUnlocked: false,
      badgeColor: Color(0xFFD97706),
    ),
    AchievementItem(
      id: 'crowd_favorite',
      title: 'Crowd Favorite',
      description: 'Receive 50 total likes across your shared recipes.',
      icon: Icons.favorite_rounded,
      category: 'Community',
      xpReward: 150,
      currentProgress: 34,
      maxProgress: 50,
      isUnlocked: false,
      badgeColor: Color(0xFFE11D48),
    ),
    AchievementItem(
      id: 'sinigang_expert',
      title: 'Sour Power',
      description: 'Explore and bookmark 5 tangy Sinigang variations.',
      icon: Icons.ramen_dining_rounded,
      category: 'Classics',
      xpReward: 75,
      currentProgress: 5,
      maxProgress: 5,
      isUnlocked: true,
      badgeColor: Color(0xFF16A34A),
    ),
    AchievementItem(
      id: 'recipe_collector',
      title: 'Grand Cookbook',
      description: 'Save 15 mouthwatering recipes to your personal collection.',
      icon: Icons.bookmark_added_rounded,
      category: 'Culinary',
      xpReward: 120,
      currentProgress: 15,
      maxProgress: 15,
      isUnlocked: true,
      badgeColor: Color(0xFF8B5CF6),
    ),
    AchievementItem(
      id: 'top_contributor',
      title: 'Leaderboard Contender',
      description: 'Break into the Top 20 on the monthly Chef Leaderboard.',
      icon: Icons.workspace_premium_rounded,
      category: 'Community',
      xpReward: 250,
      currentProgress: 1,
      maxProgress: 1,
      isUnlocked: true,
      badgeColor: Color(0xFFF59E0B),
    ),
    AchievementItem(
      id: 'kakanin_crafter',
      title: 'Kakanin Crafter',
      description: 'Cook or share 2 traditional sweet Filipino kakanin dishes.',
      icon: Icons.cake_rounded,
      category: 'Classics',
      xpReward: 90,
      currentProgress: 1,
      maxProgress: 2,
      isUnlocked: false,
      badgeColor: Color(0xFFEC4899),
    ),
    AchievementItem(
      id: 'helpful_critic',
      title: 'Kitchen Mentor',
      description: 'Leave 10 helpful tips or reviews on other chefs’ recipes.',
      icon: Icons.chat_bubble_rounded,
      category: 'Community',
      xpReward: 80,
      currentProgress: 4,
      maxProgress: 10,
      isUnlocked: false,
      badgeColor: Color(0xFF0EA5E9),
    ),
  ];

  List<AchievementItem> get _filteredList {
    if (widget.isGuest) {
      // Show locked states with demo values for guests
      return _achievements;
    }
    switch (_selectedFilterIndex) {
      case 1:
        return _achievements.where((a) => a.category == 'Culinary').toList();
      case 2:
        return _achievements.where((a) => a.category == 'Community').toList();
      case 3:
        return _achievements.where((a) => a.category == 'Classics').toList();
      default:
        return _achievements;
    }
  }

  int get _unlockedCount => widget.isGuest
      ? 0
      : _achievements.where((a) => a.isUnlocked).length;

  int get _totalXp => widget.isGuest
      ? 0
      : _achievements
          .where((a) => a.isUnlocked)
          .fold<int>(0, (sum, a) => sum + a.xpReward);

  @override
  Widget build(BuildContext context) {
    final unlocked = _unlockedCount;
    final total = _achievements.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              children: [
                // 1. App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH - 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        tooltip: 'Back',
                      ),
                      Text(
                        'Achievements',
                        style: AppTypography.headline(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // 2. Main Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                      vertical: 8,
                    ),
                    children: [
                      // Hero Level & XP Card
                      _buildTrophyHeader(unlocked, total),

                      const SizedBox(height: 20),

                      // Category Filters
                      _buildFilterRow(),

                      const SizedBox(height: 16),

                      // List of Badges
                      ...List.generate(_filteredList.length, (index) {
                        final item = _filteredList[index];
                        return FadeInView(
                          key: ValueKey(item.id),
                          delay: Duration(milliseconds: index * 40),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAchievementCard(item),
                          ),
                        );
                      }),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyHeader(int unlocked, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent,
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.accent,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isGuest ? 'Guest Chef' : 'Executive Chef Level 3',
                      style: AppTypography.title(
                        color: AppColors.onPrimary,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_totalXp XP Earned • $unlocked of $total Unlocked',
                      style: AppTypography.caption(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: total > 0 ? (unlocked / total) : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['All Badges', 'Culinary', 'Community', 'Classics'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PressableScale(
              onTap: () => setState(() => _selectedFilterIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border.withValues(alpha: 0.8),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filters[index],
                  style: AppTypography.caption(
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAchievementCard(AchievementItem item) {
    final isUnlocked = !widget.isGuest && item.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: isUnlocked
              ? item.badgeColor.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.6),
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge Icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? item.badgeColor.withValues(alpha: 0.14)
                  : AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: isUnlocked
                    ? item.badgeColor.withValues(alpha: 0.45)
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Icon(
              item.icon,
              color: isUnlocked ? item.badgeColor : AppColors.textDisabled,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Details & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.bodyStrong(
                        color: isUnlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? AppColors.accentSoft
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnlocked
                                ? Icons.check_circle_rounded
                                : Icons.lock_outline_rounded,
                            size: 11,
                            color: isUnlocked
                                ? AppColors.primary
                                : AppColors.textDisabled,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUnlocked ? '+${item.xpReward} XP' : 'Locked',
                            style: AppTypography.caption(
                              color: isUnlocked
                                  ? AppColors.textPrimary
                                  : AppColors.textDisabled,
                            ).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 8),
                // Progress indicator
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          value: isUnlocked ? 1.0 : item.progressPercentage,
                          minHeight: 5,
                          backgroundColor: AppColors.border.withValues(
                            alpha: 0.5,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUnlocked ? item.badgeColor : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUnlocked
                          ? 'Completed'
                          : '${item.currentProgress}/${item.maxProgress}',
                      style: AppTypography.caption(
                        color: isUnlocked
                            ? item.badgeColor
                            : AppColors.textSecondary,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
