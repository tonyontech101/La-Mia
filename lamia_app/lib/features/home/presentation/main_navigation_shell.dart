import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import 'home_dashboard_screen.dart';
import 'home_feed_screen.dart';

import '../../recipes/presentation/ano_pong_ulam_screen.dart';
import '../../recipes/presentation/cook_by_ingredients_screen.dart';

/// Redesigned Main Navigation Shell based on wireframe.
///
/// Features 5 items:
/// 1. Home
/// 2. Cook
/// 3. Prominent Floating Center Action Button (`+`)
/// 4. Leaderboard
/// 5. Me (Profile Screen)
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    this.isGuest = false,
    this.initialIndex = 0,
  });

  final bool isGuest;
  final int initialIndex;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onPlusActionTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Quick Culinary Actions',
                  style: AppTypography.title(
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text(
                    'Post New Dish / Recipe',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Share your homemade dish & recipe step-by-step',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recipe creation feature opening...'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.soup_kitchen_rounded,
                      color: AppColors.secondary,
                    ),
                  ),
                  title: const Text(
                    'Cook by Ingredients',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Find what to cook with available pantry items',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CookByIngredientsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.casino_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  title: const Text(
                    'Ano Pong Ulam? Randomizer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Get instant meal suggestions for breakfast, lunch, or dinner',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnoPongUlamScreen(),
                      ),
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
    final screens = [
      // 0: Home Feed (social-style recipe feed)
      HomeFeedScreen(isGuest: widget.isGuest, onNavigateToTab: _onTabTapped),

      // 1: Cook (former Home Dashboard content)
      HomeDashboardScreen(
        isGuest: widget.isGuest,
        onNavigateToTab: _onTabTapped,
      ),

      // 2: Leaderboard
      LeaderboardScreen(onNavigateHome: () => _onTabTapped(0)),

      // 3: Me (Profile Screen matching wireframe)
      ProfileScreen(
        isGuest: widget.isGuest,
        onNavigateHome: () => _onTabTapped(0),
      ),
    ];

    // Map nav index to screen index (Center '+' button does not change screen index)
    int getMappedScreenIndex() {
      if (_currentIndex >= 3) return 3;
      return _currentIndex;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      // Crossfade between tabs instead of an instant swap — all screens stay
      // mounted (state preserved) but only the active one is interactive.
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < screens.length; i++)
            IgnorePointer(
              ignoring: i != getMappedScreenIndex(),
              child: AnimatedOpacity(
                opacity: i == getMappedScreenIndex() ? 1 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOut,
                child: TickerMode(
                  enabled: i == getMappedScreenIndex(),
                  child: screens[i],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Redesigned Floating Bottom Navigation Bar Container
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. Home
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isSelected: _currentIndex == 0,
                      onTap: () => _onTabTapped(0),
                    ),

                    // 2. Cook
                    _NavItem(
                      icon: Icons.soup_kitchen_outlined,
                      label: 'Cook',
                      isSelected: _currentIndex == 1,
                      onTap: () => _onTabTapped(1),
                    ),

                    // 3. Center Space reserved for Floating '+' Action Button
                    const SizedBox(width: 48),

                    // 4. Leaderboard
                    _NavItem(
                      icon: Icons.leaderboard_rounded,
                      label: 'Rank',
                      isSelected: _currentIndex == 2,
                      onTap: () => _onTabTapped(2),
                    ),

                    // 5. Me (Profile)
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Me',
                      isSelected: _currentIndex == 3,
                      onTap: () => _onTabTapped(3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Wireframe Prominent Center Floating '+' Button
          Positioned(
            top: -24,
            child: PressableScale(
              pressedScale: 0.90,
              springBackDuration: const Duration(milliseconds: 320),
              child: GestureDetector(
                onTap: _onPlusActionTap,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.cookCardGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.onPrimary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Springy pop on the icon when the tab becomes active.
            AnimatedScale(
              scale: isSelected ? 1.14 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style: AppTypography.caption(color: color).copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
