import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../../core/utils/page_transitions.dart';

/// Wireframe-matching app bar for the Home Feed screen.
///
/// Layout: [Avatar]  —  [La Mia + subtitle]  —  [☰ Hamburger]
class FeedAppBar extends StatelessWidget {
  const FeedAppBar({
    super.key,
    required this.displayName,
    this.isGuest = false,
  });

  final String displayName;
  final bool isGuest;

  void _showOptionsMenu(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                  'Options',
                  style: AppTypography.title(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded,
                      color: AppColors.primary),
                  title: const Text('Edit Profile'),
                  subtitle: Text(
                      isGuest ? 'Guest user' : (user?.email ?? '')),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Edit profile coming soon!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined,
                      color: AppColors.secondary),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Notifications coming soon!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined,
                      color: AppColors.textSecondary),
                  title: const Text('Preferences & Dietary Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Preferences coming soon!')),
                    );
                  },
                ),
                const Divider(height: 24),
                ListTile(
                  leading: Icon(
                    isGuest ? Icons.login_rounded : Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    isGuest ? 'Sign In / Register' : 'Sign Out',
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w700),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await AuthService().signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      fadePageRoute(const LoginScreen()),
                      (_) => false,
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
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Left: Small circular avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // Center: "La Mia" + subtitle (expanded to push to center)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'La Mia',
                  style: AppTypography.wordmark(color: AppColors.textPrimary)
                      .copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  'Filipino Recipe & Meal Assistant',
                  style:
                      AppTypography.caption(color: AppColors.textSecondary)
                          .copyWith(
                    fontSize: 9,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Right: Hamburger menu
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
    );
  }
}
