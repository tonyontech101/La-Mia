import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_model.dart';

/// Full-width social-feed recipe card matching the wireframe layout.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │         [Recipe Cover Photo]         │
/// │         (16:10 aspect ratio)         │
/// │  ⏱ 1h 30 min  ◆ Breakfast  ◆ Budget │ ← overlaid tag pills
/// ├──────────────────────────────────────┤ ← divider
/// │ 🟤 @username  + follow    [See More] │
/// │ Dish Name (title, bold)              │
/// │ the description of the dish...       │
/// └──────────────────────────────────────┘
/// ```
class FeedRecipeCard extends StatelessWidget {
  const FeedRecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onFollowTap,
    this.onLongPress,
  });

  final RecipeModel recipe;
  final VoidCallback? onTap;
  final VoidCallback? onFollowTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.985,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover photo with overlaid tag pills ──────────────────
              _buildCoverSection(),

              // ── Thin divider ────────────────────────────────────────
              Container(
                height: 1,
                color: AppColors.border,
              ),

              // ── Info section below the divider ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username row with follow + See More
                    _buildUserRow(),

                    const SizedBox(height: 10),

                    // Dish Name
                    Text(
                      recipe.name,
                      style: AppTypography.title(
                        color: AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Description
                    Text(
                      _buildDescription(),
                      style: AppTypography.body(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cover photo with overlaid tag pills ─────────────────────────────

  Widget _buildCoverSection() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(16),
      ),
      child: Stack(
        children: [
          // Photo
          AspectRatio(
            aspectRatio: 16 / 10,
            child: recipe.coverPhotoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: recipe.coverPhotoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: AppColors.surfaceAlt,
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => _buildPhotoPlaceholder(),
                  )
                : _buildPhotoPlaceholder(),
          ),

          // Bottom gradient scrim so tag pills stay legible
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 52,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x66000000),
                  ],
                ),
              ),
            ),
          ),

          // Tag pills overlaid at the bottom of the photo
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  _OverlayTagPill(
                    icon: Icons.schedule_rounded,
                    label: recipe.approximateCookTime,
                  ),
                  const SizedBox(width: 8),
                  _OverlayTagPill(
                    icon: Icons.restaurant_menu_rounded,
                    label: recipe.category,
                  ),
                  const SizedBox(width: 8),
                  _OverlayTagPill(
                    icon: Icons.savings_outlined,
                    label: _shortBudget(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User row (avatar, @username, + follow, See More button) ─────────

  Widget _buildUserRow() {
    return Row(
      children: [
        // Author avatar circle
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recipe.isSystemRecipe
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
          ),
          child: Center(
            child: recipe.isSystemRecipe
                ? const Icon(
                    Icons.restaurant_rounded,
                    size: 14,
                    color: AppColors.primary,
                  )
                : Text(
                    recipe.authorName.isNotEmpty
                        ? recipe.authorName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),

        // @username
        Flexible(
          child: Text(
            '@${recipe.authorName.replaceAll(' ', '').toLowerCase()}',
            style: AppTypography.caption(
              color: AppColors.textPrimary,
            ).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // System recipe badge
        if (recipe.isSystemRecipe) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Original',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],

        const Spacer(),

        // "+ Follow" button in the corner
        GestureDetector(
          onTap: onFollowTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '+ Follow',
              style: AppTypography.caption(
                color: AppColors.onPrimary,
              ).copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Returns a compact budget label for the overlay pill.
  String _shortBudget() {
    final raw = recipe.budget ?? 'Budget friendly';
    final lower = raw.toLowerCase();
    if (lower.contains('budget') || lower.contains('cheap') || lower.contains('sulit')) {
      return 'Budget-Friendly';
    }
    if (lower.contains('affordable') || lower.contains('sakto')) {
      return 'Affordable';
    }
    if (lower.contains('special') || lower.contains('moderate')) {
      return 'Special';
    }
    if (lower.contains('expensive') || lower.contains('premium')) {
      return 'Premium';
    }
    // Fallback: take only the parenthesized label or the raw string
    final parenMatch = RegExp(r'\(([^)]+)\)').firstMatch(raw);
    if (parenMatch != null) return parenMatch.group(1)!;
    return raw.length > 16 ? '${raw.substring(0, 14)}…' : raw;
  }

  /// Builds a brief description from recipe data.
  String _buildDescription() {
    // Combine region, difficulty, servings into a readable sentence
    final parts = <String>[];
    if (recipe.region.isNotEmpty && recipe.region != 'Unknown') {
      parts.add('A ${recipe.region} dish');
    } else {
      parts.add('A Filipino dish');
    }
    if (recipe.difficulty.isNotEmpty) {
      parts.add('${recipe.difficulty.toLowerCase()} difficulty');
    }
    if (recipe.servings > 0) {
      parts.add('serves ${recipe.servings}');
    }
    if (recipe.tags.isNotEmpty) {
      final tagStr = recipe.tags.take(3).join(', ');
      parts.add(tagStr);
    }
    return '${parts.join(' · ')}.';
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 48,
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Frosted-glass tag pill overlaid on the cover photo.
///
/// Uses a semi-transparent dark background so it reads over any image.
class _OverlayTagPill extends StatelessWidget {
  const _OverlayTagPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption(
              color: Colors.white,
            ).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
