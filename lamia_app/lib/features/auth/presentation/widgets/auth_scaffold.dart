import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/fade_in_view.dart';
import '../../../../core/widgets/hero_header.dart';

/// Shared layout for the auth screens: a full-bleed hero photo with a floating
/// content card overlapping its bottom edge. Handles the keyboard, scrolling,
/// responsive hero height, and tablet max-width centering.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  /// The card body (title, fields, buttons, links).
  final Widget child;

  static const double _cardOverlap = 28;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    // Hero is ~38% of height, clamped so small phones keep the first fields
    // visible and large screens don't over-crop the photo.
    final heroHeight = (size.height * 0.38).clamp(260.0, 360.0);
    final cardTop = heroHeight - _cardOverlap;
    // Let the card fill at least the rest of the viewport so its cream surface
    // reaches the bottom even when the form is short.
    final cardMinHeight = (size.height - cardTop).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Stack(
            children: [
              HeroHeader(height: heroHeight),
              if (Navigator.of(context).canPop())
                Positioned(
                  top: media.padding.top + 8,
                  left: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                  ),
                ),
              // The floating card rises and fades in just after the hero so
              // the auth screens feel alive on entry.
              FadeInView(
                delay: const Duration(milliseconds: 60),
                duration: const Duration(milliseconds: 480),
                offset: const Offset(0, 26),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: EdgeInsets.only(top: cardTop),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: cardMinHeight),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.card),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F2B211B), // ~0.12 alpha
                          offset: Offset(0, -2),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSpacing.contentMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenH,
                              AppSpacing.xxl,
                              AppSpacing.screenH,
                              AppSpacing.xl,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
