import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/page_transitions.dart';
import '../../../../core/widgets/banig_divider.dart';
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

/// The right-side sidebar — household ledger aesthetic.
///
/// Monochrome icons, Fraunces chapter headings, BanigDivider at the hinge,
/// no rainbow chips, no emoji, no Tailwind literals.
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
        ? 'Guest'
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Chef');
    final email = isGuest ? 'Browsing mode' : (user?.email ?? '');
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
              // 1. Header — avatar, name (Fraunces), email, status, close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar — ring in border (guest) or primary (signed-in)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceAlt,
                        border: Border.all(
                          color: isGuest
                              ? AppColors.border
                              : AppColors.primary,
                          width: isGuest ? 1 : 1.5,
                        ),
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
                                errorWidget: (_, _, _) => _avatarInitial(
                                  displayName,
                                ),
                              )
                            : _avatarInitial(displayName),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name + email + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            displayName,
                            style: GoogleFonts.fraunces(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: AppTypography.caption(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (isGuest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                'Guest',
                                style: AppTypography.caption(
                                  color: AppColors.textSecondary,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Active',
                                  style: AppTypography.caption(
                                    color: AppColors.textSecondary,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Close
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // BanigDivider — the app's signature ornament at the hinge
              const BanigDivider(),

              // 2. Nav list — ledger tiles, hairline dividers
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    const SizedBox(height: 14),
                    _sectionLabel('Account'),
                    _ledgerTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
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
                    _ledgerTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      badge: isGuest ? null : '4 badges',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AchievementsScreen(isGuest: isGuest),
                          ),
                        );
                      },
                    ),
                    _ledgerTile(
                      icon: Icons.leaderboard_rounded,
                      title: 'Rank',
                      badge: isGuest ? null : '#34',
                      onTap: () => _onLeaderboardTap(context),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel('Kitchen tools'),
                    _ledgerTile(
                      icon: Icons.soup_kitchen_rounded,
                      title: 'Ano Pong Ulam?',
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
                    _ledgerTile(
                      icon: Icons.kitchen_rounded,
                      title: 'Cook by Ingredients',
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

              // 3. Bottom auth bar
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
                                side:
                                    const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.button,
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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
                            borderRadius:
                                BorderRadius.circular(AppRadii.button),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarInitial(String name) {
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

  /// Fraunces section label — the chapter heading of the ledger.
  static Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.fraunces(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Single ledger tile — monochrome icon, no subtitle, border hairline above.
  static Widget _ledgerTile({
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: AppColors.surfaceAlt,
            splashColor: AppColors.textSecondary.withValues(alpha: 0.08),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodyStrong(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        badge,
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textDisabled,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
