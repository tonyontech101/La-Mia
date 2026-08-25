import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../auth/data/user_model.dart';

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

/// Central catalogue for profile achievements. Add a new entry here whenever
/// the app gains a trackable cook action; XP automatically feeds the level.
abstract final class AchievementCatalog {
  static List<AchievementItem> forUser(
    UserModel? user, {
    required bool isChefOfMonth,
  }) {
    final recipes = user?.recipeCount ?? 0;
    final likes = user?.totalLikesReceived ?? 0;
    final followers = user?.followerCount ?? 0;
    final saved = user?.savedCount ?? 0;
    final accountDays = user == null
        ? 0
        : DateTime.now().difference(user.createdAt).inDays.clamp(0, 99999).toInt();
    return [
      _item('first_recipe', 'First Sizzle', 'Share your first recipe.', Icons.soup_kitchen_rounded, 'Culinary', 50, recipes, 1, AppColors.primary),
      _item('home_cook', 'Home Cook', 'Share 5 recipes with the community.', Icons.menu_book_rounded, 'Culinary', 120, recipes, 5, const Color(0xFF8B5CF6)),
      _item('recipe_regular', 'Recipe Regular', 'Share 20 recipes with the community.', Icons.restaurant_menu_rounded, 'Culinary', 350, recipes, 20, const Color(0xFFD97706)),
      _item('kitchen_staple', 'Kitchen Staple', 'Share 50 recipes with the community.', Icons.local_dining_rounded, 'Culinary', 700, recipes, 50, const Color(0xFFB45309)),
      _item('legacy_cook', 'Legacy Cook', 'Share 100 recipes with the community.', Icons.auto_stories_rounded, 'Culinary', 1500, recipes, 100, AppColors.accent),
      _item('first_fan', 'First Fan', 'Earn your first follower.', Icons.person_add_alt_1_rounded, 'Community', 40, followers, 1, AppColors.secondary),
      _item('neighborhood_favorite', 'Neighborhood Favorite', 'Earn 25 followers.', Icons.groups_rounded, 'Community', 200, followers, 25, const Color(0xFF0EA5E9)),
      _item('community_pillar', 'Community Pillar', 'Earn 100 followers.', Icons.diversity_1_rounded, 'Community', 650, followers, 100, const Color(0xFF2563EB)),
      _item('local_legend', 'Local Legend', 'Earn 500 followers.', Icons.celebration_rounded, 'Community', 1800, followers, 500, const Color(0xFF1D4ED8)),
      _item('first_love', 'First Love', 'Receive 10 likes across your recipes.', Icons.favorite_rounded, 'Community', 70, likes, 10, const Color(0xFFE11D48)),
      _item('well_loved', 'Well Loved', 'Receive 100 likes across your recipes.', Icons.favorite_rounded, 'Community', 300, likes, 100, const Color(0xFFDB2777)),
      _item('crowd_pleaser', 'Crowd Pleaser', 'Receive 1,000 likes across your recipes.', Icons.volunteer_activism_rounded, 'Community', 1200, likes, 1000, const Color(0xFFBE185D)),
      _item('beloved_chef', 'Beloved Chef', 'Receive 10,000 likes across your recipes.', Icons.favorite_border_rounded, 'Community', 3500, likes, 10000, const Color(0xFF9D174D)),
      _item('cookbook_starter', 'Cookbook Starter', 'Save 5 recipes for later.', Icons.bookmark_added_rounded, 'Culinary', 75, saved, 5, const Color(0xFF16A34A)),
      _item('grand_cookbook', 'Grand Cookbook', 'Save 25 recipes for later.', Icons.collections_bookmark_rounded, 'Culinary', 220, saved, 25, const Color(0xFF7C3AED)),
      _item('family_archive', 'Family Archive', 'Save 100 recipes for later.', Icons.library_books_rounded, 'Culinary', 700, saved, 100, const Color(0xFF6D28D9)),
      _item('settling_in', 'Settling In', 'Stay part of La Mia for 30 days.', Icons.calendar_month_rounded, 'Milestones', 100, accountDays, 30, AppColors.success),
      _item('one_year_table', 'One-Year Table', 'Stay part of La Mia for one year.', Icons.cake_rounded, 'Milestones', 1500, accountDays, 365, AppColors.success),
      _item('two_year_tradition', 'Two-Year Tradition', 'Stay part of La Mia for two years.', Icons.workspace_premium_rounded, 'Milestones', 4000, accountDays, 730, AppColors.accent),
      _item('monthly_chef', 'Chef of the Month', 'Lead the monthly community recipe spotlight.', Icons.workspace_premium_rounded, 'Community', 2500, isChefOfMonth ? 1 : 0, 1, AppColors.accent),
    ];
  }

  static AchievementItem _item(
    String id,
    String title,
    String description,
    IconData icon,
    String category,
    int xp,
    int progress,
    int target,
    Color color,
  ) => AchievementItem(
    id: id,
    title: title,
    description: description,
    icon: icon,
    category: category,
    xpReward: xp,
    currentProgress: progress,
    maxProgress: target,
    isUnlocked: progress >= target,
    badgeColor: color,
  );
}

class AchievementLevel {
  const AchievementLevel(this.number, this.title, this.requiredXp);

  final int number;
  final String title;
  final int requiredXp;

  static const tiers = <AchievementLevel>[
    AchievementLevel(1, 'Kitchen Starter', 0),
    AchievementLevel(2, 'Line Cook', 600),
    AchievementLevel(3, 'Sous Chef', 2000),
    AchievementLevel(4, 'Head Chef', 4500),
    AchievementLevel(5, 'Executive Chef', 7500),
    AchievementLevel(6, 'Master Chef', 10500),
    AchievementLevel(7, 'Culinary Artisan', 13500),
    AchievementLevel(8, 'Kitchen Virtuoso', 15500),
    AchievementLevel(9, 'Grand Master', 17500),
    AchievementLevel(10, 'La Mia Legend', 19000),
  ];

  static AchievementLevel fromXp(int xp) {
    return tiers.lastWhere((tier) => xp >= tier.requiredXp);
  }
}

/// A dedicated, beautiful Achievements & Badges screen for La Mia cooks.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({
    super.key,
    this.isGuest = false,
    this.user,
    this.isChefOfMonth = false,
  });

  final bool isGuest;
  final UserModel? user;
  final bool isChefOfMonth;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Culinary, 2: Community, 3: Milestones

  List<AchievementItem> _achievements = const [
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

  @override
  void initState() {
    super.initState();
    _achievements = AchievementCatalog.forUser(
      widget.user,
      isChefOfMonth: widget.isChefOfMonth,
    );
  }

  List<AchievementItem> get _filteredList {
    if (widget.isGuest) {
      // Guests can browse the catalogue but cannot earn progress yet.
      return _achievements;
    }
    switch (_selectedFilterIndex) {
      case 1:
        return _achievements.where((a) => a.category == 'Culinary').toList();
      case 2:
        return _achievements.where((a) => a.category == 'Community').toList();
      case 3:
        return _achievements.where((a) => a.category == 'Milestones').toList();
      default:
        return _achievements;
    }
  }

  int get _unlockedCount => widget.isGuest || widget.user == null
      ? 0
      : _achievements.where((a) => a.isUnlocked).length;

  int get _totalXp => widget.isGuest || widget.user == null
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

  void _showAchievementDetails(AchievementItem item) {
    final remaining = (item.maxProgress - item.currentProgress).clamp(0, item.maxProgress);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              Row(
                children: [
                  Icon(item.icon, color: item.badgeColor, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTypography.title(color: AppColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  Text('+${item.xpReward} XP', style: AppTypography.caption(color: item.badgeColor).copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              Text(item.description, style: AppTypography.body(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              Text('Your progress', style: AppTypography.bodyStrong(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: item.progressPercentage,
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                backgroundColor: AppColors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(item.badgeColor),
              ),
              const SizedBox(height: 8),
              Text(
                item.isUnlocked
                    ? 'Completed: ${item.currentProgress}/${item.maxProgress}'
                    : '${item.currentProgress}/${item.maxProgress} — $remaining more to unlock',
                style: AppTypography.caption(color: AppColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelRoadmap() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            children: [
              Text('Chef level roadmap', style: AppTypography.title(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Earn XP by completing achievements. Your current total is $_totalXp XP.', style: AppTypography.caption(color: AppColors.textSecondary).copyWith(height: 1.35)),
              const SizedBox(height: 12),
              ...AchievementLevel.tiers.map((tier) {
                final reached = _totalXp >= tier.requiredXp;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(reached ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: reached ? AppColors.success : AppColors.textDisabled),
                  title: Text('Level ${tier.number} · ${tier.title}', style: AppTypography.bodyStrong(color: reached ? AppColors.textPrimary : AppColors.textSecondary)),
                  trailing: Text('${tier.requiredXp} XP', style: AppTypography.caption(color: reached ? AppColors.success : AppColors.textSecondary).copyWith(fontWeight: FontWeight.w700)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyHeader(int unlocked, int total) {
    final level = AchievementLevel.fromXp(_totalXp);
    final levelIndex = AchievementLevel.tiers.indexOf(level);
    final nextLevel = levelIndex < AchievementLevel.tiers.length - 1
        ? AchievementLevel.tiers[levelIndex + 1]
        : null;
    final xpToNextLevel = nextLevel == null
        ? 0
        : nextLevel.requiredXp - _totalXp;
    final levelProgress = nextLevel == null
        ? 1.0
        : ((_totalXp - level.requiredXp) /
                (nextLevel.requiredXp - level.requiredXp))
            .clamp(0.0, 1.0);
    return PressableScale(
      onTap: _showLevelRoadmap,
      child: Container(
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
                        widget.isGuest || widget.user == null
                            ? 'Guest Chef'
                            : '${level.title} · Level ${level.number}',
                        style: AppTypography.title(
                          color: AppColors.onPrimary,
                        ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalXp XP Earned • $unlocked of $total Badges Unlocked',
                        style: AppTypography.caption(
                          color: AppColors.onPrimary.withValues(alpha: 0.85),
                        ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onPrimary.withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Next Level progression info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nextLevel != null
                      ? '$xpToNextLevel XP to Level ${nextLevel.number} (${nextLevel.title})'
                      : 'Max Level Reached',
                  style: AppTypography.caption(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(levelProgress * 100).toInt()}%',
                  style: AppTypography.caption(
                    color: AppColors.accent,
                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: levelProgress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['All Badges', 'Culinary', 'Community', 'Milestones'];
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

    return PressableScale(
      onTap: () => _showAchievementDetails(item),
      child: Container(
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
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: isUnlocked ? item.badgeColor : AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
