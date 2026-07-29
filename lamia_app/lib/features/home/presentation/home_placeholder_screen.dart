import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../core/utils/page_transitions.dart';

/// Temporary home screen used to verify the auth flow works end-to-end.
///
/// Shows the signed-in user's name and email, plus a sign-out button that
/// returns to the login screen. Will be replaced by the real browse/dashboard
/// in a future milestone.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key, this.isGuest = false});

  /// Whether the user entered as a guest (no Firebase user).
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
    final email = isGuest ? 'Browsing without an account' : (user?.email ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar circle
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Text(
                        isGuest
                            ? '👋'
                            : (displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?'),
                        style: TextStyle(
                          fontSize: isGuest ? 40 : 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Welcome text
                  Text(
                    'Welcome, $displayName!',
                    style: AppTypography.headline(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    email,
                    style: AppTypography.body(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.field),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isGuest ? Icons.explore_outlined : Icons.check_circle,
                          size: 40,
                          color: isGuest
                              ? AppColors.secondary
                              : const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          isGuest
                              ? 'Browsing as Guest'
                              : 'Authentication Successful',
                          style: AppTypography.bodyStrong(),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          isGuest
                              ? 'Sign in to share recipes and save favorites.'
                              : 'Your account is connected. The home dashboard is coming soon!',
                          style: AppTypography.caption(
                              color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Sign out / Sign in button
                  PrimaryButton(
                    label: isGuest ? 'Sign In' : 'Sign Out',
                    onPressed: () => _onSignOut(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
