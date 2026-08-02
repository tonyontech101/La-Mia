import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Skeleton placeholder shown while a section's data is loading from Firebase.
///
/// Animates a subtle pulse to signal activity without being distracting.
/// Pass [isHorizontal] = false for vertically-stacked card skeletons
/// (e.g. Popular Choices) vs the default horizontal row (e.g. Featured).
class SectionLoadingSkeleton extends StatefulWidget {
  const SectionLoadingSkeleton({
    super.key,
    this.height = 220,
    this.isHorizontal = true,
  });

  final double height;
  final bool isHorizontal;

  @override
  State<SectionLoadingSkeleton> createState() =>
      _SectionLoadingSkeletonState();
}

class _SectionLoadingSkeletonState extends State<SectionLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return Opacity(
          opacity: opacity,
          child: widget.isHorizontal
              ? _buildHorizontalSkeleton()
              : _buildVerticalSkeleton(),
        );
      },
    );
  }

  Widget _buildHorizontalSkeleton() {
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => Container(
          width: 190,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 108,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state shown when a section's Firebase query fails.
///
/// Displays an icon, a human-readable [message], and an optional
/// [onRetry] callback wired to a "Retry" button.
class SectionErrorState extends StatelessWidget {
  const SectionErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.screenH,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Text(
                    'Retry',
                    style: AppTypography.button(color: AppColors.onPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state shown when a section's Firebase query returns zero results.
///
/// Friendly and inviting — the user should feel encouraged, not disappointed.
class SectionEmptyState extends StatelessWidget {
  const SectionEmptyState({
    super.key,
    this.message = 'No recipes found yet',
    this.subtitle,
  });

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.screenH,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong(color: AppColors.textPrimary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.caption(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
