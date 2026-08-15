import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/asset_constants.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// Hero Action Cards matching the two main cards in image.png wireframe:
/// 1. "Cook by Ingredients"
/// 2. "Ano Pong Ulam?"
class HeroActionCards extends StatelessWidget {
  const HeroActionCards({
    super.key,
    this.onCookByIngredientsTap,
    this.onAnoPongUlamTap,
  });

  final VoidCallback? onCookByIngredientsTap;
  final VoidCallback? onAnoPongUlamTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's your next ulam for today?",
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),

        // Card 1: Cook by Ingredients
        _HeroCard(
          title: 'Cook by Ingredients',
          subtitle: 'Search recipes using your available ingredients!',
          icon: Icons.kitchen_outlined,
          gradient: AppColors.cookCardGradient,
          bgImageUrl: AssetConstants.heroCookByIngredients,
          onTap: onCookByIngredientsTap,
        ),

        const SizedBox(height: 14),

        // Card 2: Ano Pong Ulam?
        _HeroCard(
          title: 'Ano Pong Ulam?',
          subtitle: 'Decide what you want to eat today.',
          icon: Icons.auto_awesome_outlined,
          gradient: AppColors.ulamCardGradient,
          bgImageUrl: AssetConstants.heroAnoPongUlam,
          onTap: onAnoPongUlamTap,
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.bgImageUrl,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String bgImageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.97,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: Image.network(
                  bgImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: gradient.colors.first),
                ),
              ),

              // Dark Overlay Scrim
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        gradient.colors.first.withValues(alpha: 0.92),
                        gradient.colors.last.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),

              // Glassmorphism accent shapes
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),

              // Content Layout
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 20),
                      ),
                    ),

                    // Title & Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headline(
                            color: Colors.white,
                          ).copyWith(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.caption(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
