import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/auth_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'login_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Dedicated screen for requesting a password-reset email.
///
/// Shows an email input field and a "Send reset link" button. After sending,
/// displays a success state with clear instructions. The user taps
/// "I've reset my password — Log in" when they're ready, since the reset
/// happens in an external browser and we can't detect it automatically.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  String? _emailError;
  bool _emailTouched = false;
  bool _sending = false;
  bool _emailSent = false;

  // Cooldown timer for resend button.
  static const int _cooldownSeconds = 60;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  // Success animation.
  late final AnimationController _successAnimController;
  late final Animation<double> _successScaleAnim;
  late final Animation<double> _successFadeAnim;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(markTouched: true);
    });

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
    _cooldownTimer?.cancel();
    _successAnimController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _validateEmail({bool markTouched = false}) {
    if (markTouched) _emailTouched = true;
    if (!_emailTouched) return;
    setState(() => _emailError = Validators.email(_emailController.text));
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

  Future<void> _onSendResetLink() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _emailTouched = true;
      _emailError = Validators.email(_emailController.text);
    });

    if (_emailError != null) {
      _emailFocus.requestFocus();
      return;
    }

    setState(() => _sending = true);
    try {
      await _authService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() => _emailSent = true);
      _startCooldown();
      // Play success animation.
      await _successAnimController.forward();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onResend() async {
    if (_cooldownRemaining > 0) return;
    setState(() => _sending = true);
    try {
      await _authService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      _startCooldown();
      AppSnackbar.show(
        context,
        message: 'Reset link sent again. Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _goToLogin() {
    _cooldownTimer?.cancel();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                  color: _emailSent
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _emailSent
                      ? Icons.check_circle_outline
                      : Icons.lock_reset_outlined,
                  size: 40,
                  color: _emailSent ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // -- Title ----------------------------------------------
          Text(
            _emailSent ? 'Check your email' : 'Forgot password?',
            style: AppTypography.headline(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),

          // -- Body -----------------------------------------------
          if (!_emailSent) ...[
            Text(
              'Enter the email address you used to create your account '
              "and we'll send you a link to reset your password.",
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Email field
            AuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Email',
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              enabled: !_sending,
              errorText: _emailError,
              onChanged: (_) => _validateEmail(),
              onSubmitted: (_) => _onSendResetLink(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Send button
            PrimaryButton(
              label: 'Send reset link',
              isLoading: _sending,
              onPressed: _sending ? null : _onSendResetLink,
            ),
          ] else ...[
            // Success state
            Text(
              "We've sent a password reset link to",
              style: AppTypography.body(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _emailController.text,
              style: AppTypography.bodyStrong(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Open your inbox, click the link, and set a new password. '
              'The link expires in 1 hour.',
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

            // Resend button with cooldown
            PrimaryButton(
              label: _cooldownRemaining > 0
                  ? 'Resend in $_cooldownText'
                  : 'Resend reset link',
              isLoading: _sending,
              onPressed: (_sending || _cooldownRemaining > 0)
                  ? null
                  : _onResend,
            ),
            const SizedBox(height: AppSpacing.md),

            // Prominent "done" button — user taps after resetting
            PrimaryButton(
              label: "I've reset my password \u2014 Log in",
              isLoading: false,
              onPressed: _goToLogin,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // -- Back to login (always visible) ---------------------
          Center(
            child: TextButton(
              onPressed: _goToLogin,
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
