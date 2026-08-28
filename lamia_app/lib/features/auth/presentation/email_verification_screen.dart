import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../../../core/providers/auth_service_provider.dart';
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
///
/// Can also be used for sensitive action verification (password/email change)
/// by passing [onVerified] and [verificationTitle].
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.onVerified,
    this.verificationTitle,
    this.verificationSubtitle,
    this.navigateToOnVerified,
    this.requireManualConfirm = false,
  });

  /// Called when verification is complete. If null, navigates to HomePlaceholderScreen.
  final Future<void> Function(BuildContext context)? onVerified;

  /// Custom title for the verification screen.
  final String? verificationTitle;

  /// Custom subtitle shown below the title.
  final String? verificationSubtitle;

  /// Route to navigate to after verification if [onVerified] is null.
  final Widget Function()? navigateToOnVerified;

  /// When true, the screen will NOT auto-poll [isEmailVerified].
  /// Instead it shows a "Done" button the user must tap after clicking
  /// the email link. Used for sensitive operations (password/email change)
  /// where the email is already verified from signup.
  final bool requireManualConfirm;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  AuthService get _authService => ref.read(authServiceProvider);
  Timer? _pollTimer;
  bool _resending = false;
  bool _navigated = false;
  bool _isManuallyVerifying = false;

  // Resend cooldown.
  static const int _cooldownSeconds = 60;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  // Success animation.
  late final AnimationController _successAnimController;
  late final Animation<double> _successScaleAnim;
  late final Animation<double> _successFadeAnim;

  String get _userEmail => _authService.currentUser?.email ?? 'your email';

  @override
  void initState() {
    super.initState();
    // Kick off an initial reload so fresh sign-ups get the latest state.
    _authService.reloadUser();

    // Only auto-poll when NOT in manual-confirm mode. For sensitive operations
    // (password/email change) the email is already verified from signup, so
    // polling isEmailVerified would immediately trigger a false positive.
    if (!widget.requireManualConfirm) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkVerification(),
      );
    }

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

      if (widget.onVerified != null) {
        await widget.onVerified!(context);
        if (mounted) Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                widget.navigateToOnVerified?.call() ??
                const HomePlaceholderScreen(),
          ),
          (_) => false,
        );
      }
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

  /// Called when the user taps "Done" in manual-confirm mode.
  /// Reloads the user, runs [onVerified], then navigates on success.
  Future<void> _onManualConfirm() async {
    if (_isManuallyVerifying || _navigated) return;
    setState(() => _isManuallyVerifying = true);

    try {
      // Reload user to get fresh state from Firebase.
      await _authService.reloadUser();

      if (!mounted) return;

      if (widget.onVerified != null) {
        // Let the caller perform the actual operation (change password, etc.).
        // If the operation fails (e.g. email not yet verified), the callback
        // should throw so we can show an error.
        await widget.onVerified!(context);
      }

      if (!mounted) return;

      // Operation succeeded — play success animation and dismiss.
      _navigated = true;
      await _successAnimController.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      if (widget.onVerified != null) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                widget.navigateToOnVerified?.call() ??
                const HomePlaceholderScreen(),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      setState(() => _isManuallyVerifying = false);
    }
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
                  color: _navigated
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _navigated
                      ? Icons.check_circle_outline
                      : (widget.onVerified != null
                            ? Icons.shield_outlined
                            : Icons.mark_email_unread_outlined),
                  size: 40,
                  color: _navigated ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // -- Title ----------------------------------------------
          Text(
            _navigated
                ? 'Verified!'
                : (widget.verificationTitle ?? 'Verify your email'),
            style: AppTypography.headline(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // -- Body -----------------------------------------------
          if (_navigated) ...[
            Text(
              widget.onVerified != null
                  ? 'Verifying...'
                  : 'Taking you to the app...',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            if (widget.verificationSubtitle != null) ...[
              Text(
                widget.verificationSubtitle!,
                style: AppTypography.body(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                "We've sent a verification link to",
                style: AppTypography.body(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _userEmail,
              style: AppTypography.bodyStrong(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.requireManualConfirm
                  ? 'Click the link in your inbox, then tap Done below to complete the process.'
                  : 'Click the link in your inbox, then come back here. '
                        'This screen will update automatically.',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.snackbar),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      "If you don't see the email, please check your Spam/Junk folder and click \"Report as not spam\".\n\nWhen a few users do this, email providers (like Gmail) learn that our emails are legitimate, and they will begin delivering them to the main Inbox for everyone else.",
                      style: AppTypography.caption(
                        color: AppColors.textPrimary,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (widget.requireManualConfirm) ...[
              // -- "Done" button for manual confirm mode --------
              PrimaryButton(
                label: 'Done — I\'ve clicked the link',
                isLoading: _isManuallyVerifying,
                onPressed: _isManuallyVerifying ? null : _onManualConfirm,
              ),
              const SizedBox(height: AppSpacing.sm),
              // -- Resend (secondary) ----------------------------
              Center(
                child: TextButton(
                  onPressed: (_resending || _cooldownRemaining > 0)
                      ? null
                      : _resendEmail,
                  child: Text(
                    _cooldownRemaining > 0
                        ? 'Resend in $_cooldownText'
                        : 'Resend verification email',
                    style: AppTypography.body(color: AppColors.secondary),
                  ),
                ),
              ),
            ] else ...[
              // -- Resend button with cooldown (auto mode) ------
              PrimaryButton(
                label: _cooldownRemaining > 0
                    ? 'Resend in $_cooldownText'
                    : 'Resend verification email',
                isLoading: _resending,
                onPressed: (_resending || _cooldownRemaining > 0)
                    ? null
                    : _resendEmail,
              ),
            ],
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
