import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// A compact personal placement card for one leaderboard category.
class YourRankingCard extends StatelessWidget {
  const YourRankingCard({
    super.key,
    required this.rank,
    required this.label,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.onSeeFullRank,
  });

  final int rank;
  final String label;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onSeeFullRank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          // Category marker
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 21,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Category + placement
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyStrong(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),

          // Placement + full ranking link
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank > 0 ? '#$rank' : 'Unranked',
                style: AppTypography.bodyStrong(color: accentColor).copyWith(
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onSeeFullRank,
                child: Text(
                  'See Full Rank',
                  style: AppTypography.caption(color: AppColors.secondary)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.secondary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
