import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;

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
import 'login_screen.dart';
import '../../home/presentation/home_placeholder_screen.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_strength_meter.dart';

/// Sign Up screen. All auth actions go through [AuthService] which is
/// fully wired to Firebase Auth and Google Sign-In.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;

  bool _termsAccepted = false;
  String? _termsError;

  PasswordStrength _strength = PasswordStrength.empty;

  bool _creating = false;
  bool _googleLoading = false;
  bool get _busy => _creating || _googleLoading;

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _validateName(markTouched: true);
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(markTouched: true);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword(markTouched: true);
    });
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus) _validateConfirm(markTouched: true);
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _validateName({bool markTouched = false}) {
    if (markTouched) _nameTouched = true;
    if (!_nameTouched) return;
    setState(() => _nameError = Validators.name(_nameController.text));
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
      () =>
          _passwordError = Validators.signUpPassword(_passwordController.text),
    );
  }

  void _validateConfirm({bool markTouched = false}) {
    if (markTouched) _confirmTouched = true;
    if (!_confirmTouched) return;
    setState(
      () => _confirmError = Validators.confirmPassword(
        _confirmController.text,
        _passwordController.text,
      ),
    );
  }

  void _onPasswordChanged(String value) {
    setState(() => _strength = estimatePasswordStrength(value));
    _validatePassword();
    // Keep the confirm error in sync when the password changes.
    if (_confirmTouched) _validateConfirm();
  }

  Future<void> _onCreateAccount() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _nameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
      _confirmTouched = true;
      _nameError = Validators.name(_nameController.text);
      _emailError = Validators.email(_emailController.text);
      _passwordError = Validators.signUpPassword(_passwordController.text);
      _confirmError = Validators.confirmPassword(
        _confirmController.text,
        _passwordController.text,
      );
      _termsError = _termsAccepted
          ? null
          : 'Please accept the Terms to continue.';
    });

    if (_nameError != null) {
      _nameFocus.requestFocus();
      return;
    }
    if (_emailError != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (_passwordError != null) {
      _passwordFocus.requestFocus();
      return;
    }
    if (_confirmError != null) {
      _confirmFocus.requestFocus();
      return;
    }
    if (!_termsAccepted) {
      _shake();
      return;
    }

    setState(() => _creating = true);
    try {
      await _authService.createAccountWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (!mounted) return;

      // Sign out so the user must log in with their new credentials.
      await _authService.signOut();
      if (!mounted) return;

      // Show a success message while still on this screen.
      AppSnackbar.show(context, message: 'Account created! Please log in.');
      // Small delay so the user can read the snackbar before navigating.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Navigate explicitly — clear the stack and push a fresh LoginScreen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _shake() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return;
    _shakeController.forward(from: 0);
  }

  Future<void> _onGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePlaceholderScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
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

  void _openLegal(String which) {
    AppSnackbar.show(context, message: '$which coming soon.');
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(fadePageRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Join La Mia', style: AppTypography.headline()),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Create an account to share and save your favorite Filipino recipes.',
              style: AppTypography.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            AuthTextField(
              controller: _nameController,
              focusNode: _nameFocus,
              label: 'Full name',
              hint: 'Juan Dela Cruz',
              prefixIcon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              enabled: !_busy,
              errorText: _nameError,
              onChanged: (_) => _validateName(),
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            AuthTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              label: 'Email',
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              enabled: !_busy,
              errorText: _emailError,
              onChanged: (_) => _validateEmail(),
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: 'Password',
              hint: 'At least 8 characters',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_busy,
              errorText: _passwordError,
              onChanged: _onPasswordChanged,
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PasswordStrengthMeter(strength: _strength),
            ),
            AuthTextField(
              controller: _confirmController,
              focusNode: _confirmFocus,
              label: 'Confirm password',
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_busy,
              errorText: _confirmError,
              onChanged: (_) => _validateConfirm(),
              onSubmitted: (_) => _onCreateAccount(),
            ),
            const SizedBox(height: AppSpacing.xs),
            _TermsRow(
              accepted: _termsAccepted,
              error: _termsError,
              enabled: !_busy,
              shakeController: _shakeController,
              onChanged: (v) => setState(() {
                _termsAccepted = v;
                if (v) _termsError = null;
              }),
              onOpenTerms: () => _openLegal('Terms of Service'),
              onOpenPrivacy: () => _openLegal('Privacy Policy'),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Create Account',
              isLoading: _creating,
              onPressed: _busy ? null : _onCreateAccount,
            ),
            const SizedBox(height: AppSpacing.lg),
            const OrDivider(),
            const SizedBox(height: AppSpacing.lg),
            GoogleButton(
              label: 'Sign up with Google',
              isLoading: _googleLoading,
              onPressed: _busy ? null : _onGoogle,
            ),
            const SizedBox(height: AppSpacing.md),
            GuestLink(onTap: _onGuest),
            const SizedBox(height: AppSpacing.xl),
            PromptLink(
              prompt: 'Already have an account?',
              linkText: 'Log in',
              onTap: _goToLogin,
            ),
          ],
        ),
      ),
    );
  }
}

/// Terms/privacy checkbox row with an optional shake animation on submit error.
class _TermsRow extends StatefulWidget {
  const _TermsRow({
    required this.accepted,
    required this.error,
    required this.enabled,
    required this.shakeController,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final String? error;
  final bool enabled;
  final AnimationController shakeController;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<_TermsRow> createState() => _TermsRowState();
}

class _TermsRowState extends State<_TermsRow> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onOpenTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = widget.onOpenPrivacy;
  }

  @override
  void didUpdateWidget(covariant _TermsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onOpenTerms != widget.onOpenTerms) {
      _termsRecognizer.onTap = widget.onOpenTerms;
    }
    if (oldWidget.onOpenPrivacy != widget.onOpenPrivacy) {
      _privacyRecognizer.onTap = widget.onOpenPrivacy;
    }
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.checkbox),
            onTap: widget.enabled
                ? () => widget.onChanged(!widget.accepted)
                : null,
            child: Center(
              child: IgnorePointer(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.accepted,
                    onChanged: widget.enabled
                        ? (v) => widget.onChanged(v ?? false)
                        : null,
                    activeColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.checkbox),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text.rich(
              TextSpan(
                style: AppTypography.caption(color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: "I agree to La Mia's "),
                  TextSpan(
                    text: 'Terms of Service',
                    style: AppTypography.caption(
                      color: AppColors.secondary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: AppTypography.caption(
                      color: AppColors.secondary,
                    ).copyWith(fontWeight: FontWeight.w600),
                    recognizer: _privacyRecognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: widget.shakeController,
          builder: (context, child) {
            // Damped horizontal shake.
            final t = widget.shakeController.value;
            final dx = t == 0
                ? 0.0
                : 8 * (1 - t) * math.sin(t * 3 * 2 * math.pi);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: row,
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs, left: 2),
            child: Text(
              widget.error!,
              style: AppTypography.caption(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
