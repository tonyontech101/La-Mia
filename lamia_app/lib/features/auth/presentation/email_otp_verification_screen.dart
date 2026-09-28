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
import 'widgets/otp_pin_input.dart';

/// Screen for 6-digit OTP verification sent to the user's email.
///
/// Used for:
/// - New user email verification after sign-up
/// - Identity verification before password change
/// - New email confirmation before updating email
class EmailOtpVerificationScreen extends ConsumerStatefulWidget {
  const EmailOtpVerificationScreen({
    super.key,
    this.purpose = 'signup',
    this.targetEmail,
    this.newEmail,
    this.onVerified,
    this.verificationTitle,
    this.verificationSubtitle,
    this.navigateToOnVerified,
  });

  /// 'signup' | 'change_password' | 'change_email'
  final String purpose;

  /// The email address receiving the OTP code.
  final String? targetEmail;

  /// The new email address (only applicable when [purpose] == 'change_email').
  final String? newEmail;

  /// Optional callback executed when verification succeeds.
  final Future<void> Function(BuildContext context)? onVerified;

  /// Custom title.
  final String? verificationTitle;

  /// Custom subtitle.
  final String? verificationSubtitle;

  /// Custom navigation target after successful verification if [onVerified] is null.
  final Widget Function()? navigateToOnVerified;

  @override
  ConsumerState<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends ConsumerState<EmailOtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  AuthService get _authService => ref.read(authServiceProvider);

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isVerifying = false;
  bool _isResending = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _navigated = false;

  // Resend cooldown timer
  static const int _cooldownSeconds = 60;
  int _cooldownRemaining = _cooldownSeconds;
  Timer? _cooldownTimer;

  // Success animation
  late final AnimationController _successAnimController;
  late final Animation<double> _successScaleAnim;
  late final Animation<double> _successFadeAnim;

  String get _displayEmail {
    if (widget.purpose == 'change_email' && widget.newEmail != null) {
      return widget.newEmail!;
    }
    return widget.targetEmail ??
        _authService.currentUser?.email ??
        'your email';
  }

  @override
  void initState() {
    super.initState();
    _startCooldown();

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
    _cooldownTimer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    _successAnimController.dispose();
    super.dispose();
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

  Future<void> _resendCode() async {
    if (_cooldownRemaining > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await _authService.sendEmailOtp(
        purpose: widget.purpose,
        targetEmail: widget.purpose == 'change_email'
            ? widget.newEmail
            : widget.targetEmail,
      );
      if (!mounted) return;
      _startCooldown();
      AppSnackbar.show(
        context,
        message: 'A new verification code has been sent.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp([String? codeToVerify]) async {
    final code = codeToVerify ?? _pinController.text.trim();
    if (code.length != 6 || _isVerifying || _navigated) return;

    setState(() {
      _isVerifying = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final success = await _authService.verifyEmailOtp(
        code: code,
        purpose: widget.purpose,
        newEmail: widget.newEmail,
      );

      if (!success) {
        throw Exception('Verification code was rejected.');
      }

      if (!mounted) return;

      if (widget.onVerified != null) {
        await widget.onVerified!(context);
      }

      if (!mounted) return;

      // Play success check animation
      _navigated = true;
      await _successAnimController.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      if (widget.onVerified != null) {
        Navigator.of(context).pop(true);
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
      setState(() {
        _isVerifying = false;
        _hasError = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _backToLogin() {
    _authService.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String get _title {
    if (widget.verificationTitle != null) return widget.verificationTitle!;
    if (widget.purpose == 'change_password') return 'Security Verification';
    if (widget.purpose == 'change_email') return 'Verify New Email';
    return 'Verify Your Email';
  }

  String get _subtitle {
    if (widget.verificationSubtitle != null) return widget.verificationSubtitle!;
    if (widget.purpose == 'change_password') {
      return 'Enter the 6-digit code sent to your email to verify your identity before changing your password:';
    }
    if (widget.purpose == 'change_email') {
      return 'Enter the 6-digit code sent to your new email address to complete the update:';
    }
    return "We've sent a 6-digit verification code to:";
  }

  @override
  Widget build(BuildContext context) {
    final isCodeComplete = _pinController.text.length == 6;

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
                      : (widget.purpose == 'change_password'
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
            _navigated ? 'Verified!' : _title,
            style: AppTypography.headline(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // -- Subtitle & Target Email ---------------------------
          if (_navigated) ...[
            Text(
              widget.onVerified != null
                  ? 'Completing update...'
                  : 'Taking you to La Mia...',
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              _subtitle,
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _displayEmail,
              style: AppTypography.bodyStrong(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // -- 6-Digit OTP Pin Input ---------------------------
            OtpPinInput(
              controller: _pinController,
              focusNode: _pinFocusNode,
              hasError: _hasError,
              onChanged: (_) {
                if (_hasError) {
                  setState(() {
                    _hasError = false;
                    _errorMessage = null;
                  });
                } else {
                  setState(() {});
                }
              },
              onCompleted: (code) {
                _verifyOtp(code);
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _errorMessage!,
                style: AppTypography.caption(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // -- Verify button -----------------------------------
            PrimaryButton(
              label: 'Verify & Continue',
              isLoading: _isVerifying,
              onPressed: (isCodeComplete && !_isVerifying) ? () => _verifyOtp() : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // -- Resend timer / button ---------------------------
            Center(
              child: TextButton(
                onPressed: (_isResending || _cooldownRemaining > 0)
                    ? null
                    : _resendCode,
                child: Text(
                  _cooldownRemaining > 0
                      ? 'Resend code in $_cooldownText'
                      : 'Resend verification code',
                  style: AppTypography.body(
                    color: _cooldownRemaining > 0
                        ? AppColors.textDisabled
                        : AppColors.secondary,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // -- Bottom Navigation (Back to Login / Cancel) ---------
          Center(
            child: TextButton(
              onPressed: () {
                if (widget.onVerified != null || widget.purpose != 'signup') {
                  Navigator.of(context).pop(false);
                } else {
                  _backToLogin();
                }
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 40),
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                (widget.onVerified != null || widget.purpose != 'signup')
                    ? 'Cancel'
                    : 'Back to login',
                style: AppTypography.body(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
