import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/page_transitions.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../auth/presentation/sign_up_screen.dart';
import '../../../leaderboard/presentation/leaderboard_screen.dart';
import '../../../recipes/presentation/ano_pong_ulam_screen.dart';
import '../../../recipes/presentation/cook_by_ingredients_screen.dart';
import '../achievements_screen.dart';
import '../settings_screen.dart';

/// Opens the modern right-side navigation drawer sheet.
void showAppRightSidebar({
  required BuildContext context,
  bool isGuest = false,
  ValueChanged<int>? onNavigateToTab,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.54),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, _, _) {
      return Align(
        alignment: Alignment.centerRight,
        child: AppRightSidebar(
          isGuest: isGuest,
          onNavigateToTab: onNavigateToTab,
        ),
      );
    },
    transitionBuilder: (context, anim1, _, child) {
      final curved = CurvedAnimation(
        parent: anim1,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// Redesigned modern Hamburger icon button.
class HamburgerButton extends StatelessWidget {
  const HamburgerButton({
    super.key,
    required this.onTap,
    this.size = 40,
    this.iconSize = 22,
    this.backgroundColor,
  });

  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 2.4,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 3.5),
              Container(
                width: 13,
                height: 2.4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 3.5),
              Container(
                width: 18,
                height: 2.4,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The right-side sidebar containing Settings, Achievements, Rank/Leaderboard,
/// kitchen shortcuts, and account controls.
class AppRightSidebar extends StatelessWidget {
  const AppRightSidebar({
    super.key,
    this.isGuest = false,
    this.onNavigateToTab,
  });

  final bool isGuest;
  final ValueChanged<int>? onNavigateToTab;

  Future<void> _onSignOut(BuildContext context) async {
    Navigator.of(context).pop(); // Close sidebar
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadePageRoute(const LoginScreen()), (_) => false);
  }

  void _onLeaderboardTap(BuildContext context) {
    Navigator.of(context).pop(); // Close sidebar
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = isGuest
        ? 'Guest Foodie'
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Chef Foodie');
    final email = isGuest ? 'Browsing Mode' : (user?.email ?? '');
    final photoUrl = isGuest ? null : user?.photoURL;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = (screenWidth * 0.84).clamp(280.0, 360.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 28,
              offset: Offset(-6, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header with User Info and Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceAlt,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: photoUrl != null && photoUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (_, _, _) => _buildAvatarInitial(
                                  displayName,
                                ),
                              )
                            : _buildAvatarInitial(displayName),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name & Email/Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            displayName,
                            style: AppTypography.title(
                              color: AppColors.textPrimary,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: AppTypography.caption(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isGuest
                                  ? AppColors.surfaceAlt
                                  : AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              border: Border.all(
                                color: isGuest
                                    ? AppColors.border
                                    : AppColors.accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              isGuest ? 'Guest User' : '🌟 Active Cook',
                              style: AppTypography.caption(
                                color: isGuest
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close Button
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close Menu',
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // 2. Scrollable Navigation Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  children: [
                    _buildSectionHeader('PRIMARY NAVIGATION'),
                    const SizedBox(height: 6),

                    // 1. Settings
                    _SidebarTile(
                      icon: Icons.settings_outlined,
                      iconColor: AppColors.primary,
                      title: 'Settings',
                      subtitle: 'Preferences & account security',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(isGuest: isGuest),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    // 2. Achievements
                    _SidebarTile(
                      icon: Icons.emoji_events_outlined,
                      iconColor: const Color(0xFFD97706), // Warm Amber
                      title: 'Achievements',
                      subtitle: 'Badges, cooking milestones & XP',
                      badgeText: isGuest ? null : '4 Badges',
                      badgeColor: AppColors.accentSoft,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AchievementsScreen(
                              isGuest: isGuest,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    // 3. Rank / Leaderboard
                    _SidebarTile(
                      icon: Icons.leaderboard_rounded,
                      iconColor: AppColors.secondary,
                      title: 'Rank / Leaderboard',
                      subtitle: 'Top contributors & community stats',
                      badgeText: isGuest ? null : '#34 Rank',
                      badgeColor: AppColors.primary.withValues(alpha: 0.12),
                      onTap: () => _onLeaderboardTap(context),
                    ),

                    const SizedBox(height: 18),
                    _buildSectionHeader('KITCHEN TOOLS'),
                    const SizedBox(height: 6),

                    // Ano Pong Ulam?
                    _SidebarTile(
                      icon: Icons.soup_kitchen_rounded,
                      iconColor: const Color(0xFF16A34A),
                      title: 'Ano Pong Ulam?',
                      subtitle: 'Daily meal recommendation assistant',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnoPongUlamScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    // Cook by Ingredients
                    _SidebarTile(
                      icon: Icons.kitchen_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: 'Cook by Ingredients',
                      subtitle: 'Match what is in your pantry',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CookByIngredientsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // 3. Bottom Action Bar (Sign In / Register for Guest or Sign Out for User)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: isGuest
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.button,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Log In'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.button,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Register'),
                            ),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _onSignOut(context),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.button,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        title,
        style: AppTypography.caption(
          color: AppColors.textSecondary,
        ).copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: AppColors.surfaceAlt,
        splashColor: iconColor.withValues(alpha: 0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyStrong(
                        color: AppColors.textPrimary,
                      ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      style: AppTypography.caption(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    badgeText!,
                    style: AppTypography.caption(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],

              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textDisabled,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
