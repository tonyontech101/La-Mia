import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/fade_in_view.dart';
import '../../../../core/widgets/hero_header.dart';

/// Shared layout for the auth screens: a full-bleed hero photo with a floating
/// content card overlapping its bottom edge. Handles the keyboard, scrolling,
/// responsive hero height, and tablet max-width centering.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.compact = false,
    this.cardPadding,
  });

  /// The card body (title, fields, buttons, links).
  final Widget child;

  /// If true, scales the hero height and card padding to fit compact / single-viewport screens.
  final bool compact;

  /// Optional override for card padding.
  final EdgeInsetsGeometry? cardPadding;

  static const double _cardOverlap = 28;
  static const double _compactCardOverlap = 20;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final isSmallScreen = size.height < 700;
    final isTallScreen = size.height >= 880;
    final overlap = compact
        ? (isSmallScreen ? _compactCardOverlap : 24.0)
        : _cardOverlap;

    // Responsive hero height:
    // If compact on small phones (<700, e.g. iPhone SE): ~18% (115..130) so all fields fit without scrolling.
    // If compact on standard phones (700..880): ~38% (300..330).
    // If compact on tall phones (>=880, e.g. Pixel/modern Android): ~40% (350..385).
    // Otherwise standard ~38% (clamped 260..360).
    final heroHeight = compact
        ? (isSmallScreen
            ? (size.height * 0.18).clamp(115.0, 130.0)
            : (isTallScreen
                ? (size.height * 0.40).clamp(350.0, 385.0)
                : (size.height * 0.38).clamp(300.0, 335.0)))
        : (size.height * 0.38).clamp(260.0, 360.0);
    final cardTop = heroHeight - overlap;
    // Let the card fill at least the rest of the viewport so its cream surface
    // reaches the bottom even when the form is short.
    final cardMinHeight = (size.height - cardTop).clamp(0.0, double.infinity);

    final resolvedCardPadding = cardPadding ??
        EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          compact ? 10.0 : AppSpacing.xxl,
          AppSpacing.screenH,
          compact ? AppSpacing.sm : AppSpacing.xl,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Stack(
            children: [
              HeroHeader(
                height: heroHeight,
                compact: compact,
              ),
              if (Navigator.of(context).canPop())
                Positioned(
                  top: media.padding.top + (compact ? 4 : 8),
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
                            padding: resolvedCardPadding,
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
