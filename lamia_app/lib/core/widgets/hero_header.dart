import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'fade_in_view.dart';

/// Full-bleed hero photo of Filipino dishes + the Philippine flag, topped with
/// a vertical dark scrim and the "La Mia" wordmark. Sits behind the floating
/// auth card, which overlaps its bottom edge.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.height});

  final double height;

  static const String _asset = 'assets/images/l-intro-1725652895.jpg';

  @override
  Widget build(BuildContext context) {
    // Decode the large photo at roughly device width to save memory.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round().clamp(
      1,
      4096,
    );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo — slowly settles from a gentle zoom on first appearance
          // (subtle "Ken Burns" settle so the hero feels alive).
          Semantics(
            label: 'Collage of Filipino dishes with the Philippine flag',
            image: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.08, end: 1.0),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Image.asset(
                _asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: AppColors.primaryDark),
              ),
            ),
          ),
          // Warm multiply overlay to unify tone (decorative).
          const ColoredBox(color: AppColors.heroWarmOverlay),
          // Vertical scrim so white text stays legible over the photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.heroScrim,
                stops: AppColors.heroScrimStops,
              ),
            ),
          ),
          // Wordmark + tagline, lower-left.
          Positioned(
            left: AppSpacing.screenH,
            right: AppSpacing.screenH,
            bottom: AppSpacing.xl + 28,
            child: FadeInView(
              delay: const Duration(milliseconds: 120),
              duration: const Duration(milliseconds: 600),
              offset: const Offset(0, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Discover, Cook, and Share Delicious Recipes.',
                    style: AppTypography.label(
                      color: AppColors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'La Mia',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('La Mia', style: AppTypography.wordmark()),
            const SizedBox(height: AppSpacing.xxs),
            // Short amber underline stroke under the wordmark.
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
