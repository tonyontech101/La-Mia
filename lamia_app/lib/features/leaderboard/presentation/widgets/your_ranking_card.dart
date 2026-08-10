import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Bottom "Your Ranking" card showing the user's personal rank,
/// title, spots gained, and a "See Full Rank" link.
class YourRankingCard extends StatelessWidget {
  const YourRankingCard({
    super.key,
    required this.rank,
    required this.title,
    required this.spotsChange,
    this.onSeeFullRank,
  });

  final int rank;
  final String title;
  final int spotsChange; // positive = moved up, negative = dropped
  final VoidCallback? onSeeFullRank;

  @override
  Widget build(BuildContext context) {
    final isPositive = spotsChange >= 0;

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
          // Rank circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // "Your Ranking" + title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Ranking',
                  style: AppTypography.bodyStrong(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),

          // Spots change + See Full Rank
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14,
                    color: isPositive ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${isPositive ? '+' : ''}$spotsChange Spots ${isPositive ? 'Up' : 'Down'}',
                    style: AppTypography.caption(
                      color: isPositive ? AppColors.success : AppColors.error,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ],
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
