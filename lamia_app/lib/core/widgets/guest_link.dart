import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// "Just browsing? Continue as guest →" affordance. Stays enabled even while
/// an auth action is loading, so browse-first users are never blocked.
class GuestLink extends StatelessWidget {
  const GuestLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue as guest, skip sign in',
      child: Center(
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.textPrimary,
          ),
          child: Text.rich(
            TextSpan(
              style: AppTypography.bodyStrong(),
              children: const [
                TextSpan(text: 'Just browsing? Continue as '),
                TextSpan(
                  text: 'guest',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
                TextSpan(text: ' →'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline "prompt + tappable link" row, e.g. "New here? Create an account".
///
/// The link is a real [TextButton] so it has a proper tap target and is
/// reachable by assistive tech.
class PromptLink extends StatelessWidget {
  const PromptLink({
    super.key,
    required this.prompt,
    required this.linkText,
    required this.onTap,
  });

  final String prompt;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: AppTypography.body(color: AppColors.textSecondary)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            foregroundColor: AppColors.secondary,
          ),
          child: Text(
            linkText,
            style: AppTypography.bodyStrong(color: AppColors.secondary),
          ),
        ),
      ],
    );
  }
}
