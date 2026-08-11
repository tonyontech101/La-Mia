import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../home/presentation/home_placeholder_screen.dart';
import 'login_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Screen shown after account creation (or login with an unverified email).
///
/// Displays a "check your inbox" message with the user's email address,
/// provides a "Resend email" action with a 60-second cooldown, and reminds
/// the user to also check their spam/junk folder. Periodically polls Firebase
/// to detect when the user has clicked the verification link, then
/// auto-navigates to the home screen with a success animation.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  Timer? _pollTimer;
  bool _resending = false;
  bool _navigated = false;

  // Resend cooldown.
  static const int _cooldownSeconds = 60;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  // Success animation.
  late final AnimationController _successAnimController;
  late final Animation<double> _successScaleAnim;
  late final Animation<double> _successFadeAnim;

  String get _userEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'your email';

  @override
  void initState() {
    super.initState();
    // Kick off an initial reload so fresh sign-ups get the latest state.
    _authService.reloadUser();
    // Poll every 3 seconds to detect verification without requiring a
    // page refresh (Firebase does not push this state change in real-time
    // on all platforms).
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerification(),
    );

    // Success animation setup.
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut),
    );
    _successFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successAnimController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _successAnimController.dispose();
    super.dispose();
  }

  /// Reloads the user from Firebase and, if [emailVerified] is now true,
  /// plays the success animation and navigates to the home screen.
  Future<void> _checkVerification() async {
    if (_navigated) return;
    await _authService.reloadUser();
    if (_authService.isEmailVerified && mounted && !_navigated) {
      _navigated = true;
      _pollTimer?.cancel();
      // Play success animation before navigating.
      await _successAnimController.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePlaceholderScreen()),
        (_) => false,
      );
    }
  }

  void _startCooldown() {
    _cooldownRemaining = _cooldownSeconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          timer.cancel();
        }
      });
    });
  }

  String get _cooldownText {
    if (_cooldownRemaining <= 0) return '';
    final m = _cooldownRemaining ~/ 60;
    final s = _cooldownRemaining % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  Future<void> _resendEmail() async {
    if (_cooldownRemaining > 0) return;
    setState(() => _resending = true);
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      _startCooldown();
      AppSnackbar.show(
        context,
        message: 'Verification email sent. Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _backToLogin() {
    _authService.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Icon / Success animation ---------------------------
          Center(
            child: AnimatedBuilder(
              animation: _successAnimController,
              builder: (context, child) {
                return Opacity(
                  opacity: _successFadeAnim.value,
                  child: Transform.scale(
                    scale: _successScaleAnim.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _navigated ? AppColors.success.withValues(alpha: 0.15) : AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _navigated ? Icons.check_circle_outline : Icons.mark_email_unread_outlined,
                  size: 40,
                  color: _navigated ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // -- Title ----------------------------------------------
          Text(
            _navigated ? 'Email verified!' : 'Verify your email',
            style: AppTypography.headline(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // -- Body -----------------------------------------------
          if (_navigated) ...[
            Text(
              'Taking you to the app...',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              "We've sent a verification link to",
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _userEmail,
              style: AppTypography.bodyStrong(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Click the link in your inbox, then come back here. '
              'This screen will update automatically.',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Didn't find it? Check your spam or junk folder.",
              style: AppTypography.caption(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // -- Resend button with cooldown ----------------------
            PrimaryButton(
              label: _cooldownRemaining > 0
                  ? 'Resend in $_cooldownText'
                  : 'Resend verification email',
              isLoading: _resending,
              onPressed:
                  (_resending || _cooldownRemaining > 0) ? null : _resendEmail,
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // -- Back to login --------------------------------------
          Center(
            child: TextButton(
              onPressed: _backToLogin,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                foregroundColor: AppColors.secondary,
              ),
              child: Text(
                'Back to login',
                style: AppTypography.bodyStrong(color: AppColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
