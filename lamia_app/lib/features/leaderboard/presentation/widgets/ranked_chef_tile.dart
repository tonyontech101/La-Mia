import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// A ranked chef tile used in the Top 3 and Trending Cooks sections.
///
/// For top 3: larger card style with numbered badge and chevron.
/// For trending (4+): compact list-row style.
class RankedChefTile extends StatelessWidget {
  const RankedChefTile({
    super.key,
    required this.rank,
    required this.chefName,
    required this.recipesShared,
    this.isTopThree = false,
    this.onTap,
  });

  final int rank;
  final String chefName;
  final int recipesShared;
  final bool isTopThree;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isTopThree) {
      return _buildTopThreeTile(context);
    }
    return _buildTrendingTile(context);
  }

  /// Large card-style row for ranks 1–3.
  Widget _buildTopThreeTile(BuildContext context) {
    return PressableScale(
      pressedScale: 0.98,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank number badge
            _RankBadge(rank: rank),
            const SizedBox(width: 12),

            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getAvatarColor().withValues(alpha: 0.12),
                border: Border.all(
                  color: _getAvatarColor().withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  chefName.isNotEmpty ? chefName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _getAvatarColor(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + recipes count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chefName,
                    style: AppTypography.bodyStrong(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'no. of Recipes Shared',
                    style: AppTypography.caption(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Compact list-row style for ranks 4+.
  Widget _buildTrendingTile(BuildContext context) {
    return PressableScale(
      pressedScale: 0.97,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: AppTypography.bodyStrong(
                  color: AppColors.textSecondary,
                ).copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),

            // Avatar (smaller)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: Center(
                child: Text(
                  chefName.isNotEmpty ? chefName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name
            Expanded(
              child: Text(
                chefName,
                style: AppTypography.body(
                  color: AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Recipes count
            Text(
              'no. of Recipes Shared',
              style: AppTypography.caption(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 11),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Color _getAvatarColor() {
    switch (rank) {
      case 1:
        return AppColors.accent; // Gold
      case 2:
        return AppColors.textSecondary; // Silver-ish
      case 3:
        return AppColors.primary; // Bronze/terracotta
      default:
        return AppColors.primary;
    }
  }
}

/// Circular badge showing the rank number with a color-coded background.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;

    switch (rank) {
      case 1:
        bgColor = AppColors.accent;
        textColor = Colors.white;
        break;
      case 2:
        bgColor = const Color(0xFFB0B0B0); // Silver
        textColor = Colors.white;
        break;
      case 3:
        bgColor = AppColors.primary;
        textColor = Colors.white;
        break;
      default:
        bgColor = AppColors.surfaceAlt;
        textColor = AppColors.textSecondary;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
