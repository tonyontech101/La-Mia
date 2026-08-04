import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../recipes/presentation/ano_pong_ulam_screen.dart';
import '../../recipes/presentation/cook_by_ingredients_screen.dart';
import 'home_dashboard_screen.dart';

/// Navigation Shell hosting the 4 bottom tabs from image.png wireframe:
/// 1. Home
/// 2. Cook (Cook by Ingredients)
/// 3. Suggestion (Ano Pong Ulam?)
/// 4. Me (Profile & Saved Recipes)
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      // Tab 0: Home Dashboard
      HomeDashboardScreen(
        isGuest: widget.isGuest,
        onNavigateToTab: _onTabTapped,
      ),

      // Tab 1: Cook by Ingredients
      CookByIngredientsScreen(onNavigateHome: () => _onTabTapped(0)),

      // Tab 2: Suggestion (Ano Pong Ulam?)
      AnoPongUlamScreen(onNavigateHome: () => _onTabTapped(0)),

      // Tab 3: Me (Profile)
      _ProfileTab(isGuest: widget.isGuest),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: Icons.soup_kitchen_outlined,
                  label: 'Cook',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                _NavItem(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Suggestion',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption(color: color).copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.isGuest});
  final bool isGuest;

  Future<void> _onSignOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadePageRoute(const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        isGuest ? 'Guest' : (user?.displayName ?? user?.email ?? 'User');
    final email = isGuest ? 'Browsing as guest' : (user?.email ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: AppTypography.headline(),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: AppTypography.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: isGuest ? 'Sign In / Register' : 'Sign Out',
                onPressed: () => _onSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
