import 'package:flutter/material.dart';

import '../data/auth_service.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/auth_text_field.dart';
import '../../../core/widgets/google_button.dart';
import '../../../core/widgets/guest_link.dart';
import '../../../core/widgets/or_divider.dart';
import '../../../core/widgets/primary_button.dart';
import 'sign_up_screen.dart';
import '../../home/presentation/home_placeholder_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Login screen. All auth actions go through [AuthService] which is
/// fully wired to Firebase Auth and Google Sign-In.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  bool _loggingIn = false;
  bool _googleLoading = false;

  bool get _busy => _loggingIn || _googleLoading;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(markTouched: true);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword(markTouched: true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _validateEmail({bool markTouched = false}) {
    if (markTouched) _emailTouched = true;
    if (!_emailTouched) return;
    setState(() => _emailError = Validators.email(_emailController.text));
  }

  void _validatePassword({bool markTouched = false}) {
    if (markTouched) _passwordTouched = true;
    if (!_passwordTouched) return;
    setState(
      () => _passwordError = Validators.loginPassword(_passwordController.text),
    );
  }

  Future<void> _onLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _emailTouched = true;
      _passwordTouched = true;
      _emailError = Validators.email(_emailController.text);
      _passwordError = Validators.loginPassword(_passwordController.text);
    });

    if (_emailError != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (_passwordError != null) {
      _passwordFocus.requestFocus();
      return;
    }

    setState(() => _loggingIn = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Navigation is handled by the StreamBuilder in app.dart.
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _onGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _authService.signInWithGoogle();
      // Navigation is handled by the StreamBuilder in app.dart.
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _onGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      fadePageRoute(const HomePlaceholderScreen(isGuest: true)),
      (_) => false,
    );
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Enter your email above, then tap Forgot password.',
      );
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Password reset email sent. Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _goToSignUp() {
    Navigator.of(context).pushReplacement(fadePageRoute(const SignUpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome back', style: AppTypography.headline()),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Sign in to share recipes, save favorites, and join the kitchen.',
              style: AppTypography.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Email',
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              enabled: !_busy,
              errorText: _emailError,
              onChanged: (_) => _validateEmail(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: 'Password',
              hint: 'Enter your password',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !_busy,
              errorText: _passwordError,
              onChanged: (_) => _validatePassword(),
              onSubmitted: (_) => _onLogin(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _onForgotPassword,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  foregroundColor: AppColors.secondary,
                ),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.bodyStrong(color: AppColors.secondary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Log In',
              isLoading: _loggingIn,
              onPressed: _busy ? null : _onLogin,
            ),
            const SizedBox(height: AppSpacing.lg),
            const OrDivider(),
            const SizedBox(height: AppSpacing.lg),
            GoogleButton(
              label: 'Continue with Google',
              isLoading: _googleLoading,
              onPressed: _busy ? null : _onGoogle,
            ),
            const SizedBox(height: AppSpacing.md),
            GuestLink(onTap: _onGuest),
            const SizedBox(height: AppSpacing.xl),
            PromptLink(
              prompt: 'New here?',
              linkText: 'Create an account',
              onTap: _goToSignUp,
            ),
          ],
        ),
      ),
    );
  }
}
