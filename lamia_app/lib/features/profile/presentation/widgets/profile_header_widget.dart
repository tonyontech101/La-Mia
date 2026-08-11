import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Header section of the Profile screen based on wireframe design.
///
/// Features:
/// - Circular profile avatar with status/online badge
/// - `#34 ranking` pill badge
/// - Bio text section
/// - 3-column stats row: Recipes, Likes, Followers
class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({
    super.key,
    required this.displayName,
    this.bio,
    this.photoUrl,
    this.ranking = '#34 ranking',
    this.recipesCount = '24',
    this.likesCount = '1.2k',
    this.followersCount = '950',
    this.isGuest = false,
    this.onEditProfileTap,
  });

  final String displayName;
  final String? bio;
  final String? photoUrl;
  final String ranking;
  final String recipesCount;
  final String likesCount;
  final String followersCount;
  final bool isGuest;
  final VoidCallback? onEditProfileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Avatar with edit / status badge
        Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.primary, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildAvatarFallback(),
                      )
                    : _buildAvatarFallback(),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: GestureDetector(
                onTap: onEditProfileTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.onPrimary,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Ranking Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                ranking,
                style: AppTypography.caption(
                  color: AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. Display Name & Bio
        Text(
          displayName,
          style: AppTypography.headline(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            bio ??
                (isGuest
                    ? 'Browsing as guest foodie'
                    : 'Bio of user contains here.'),
            style: AppTypography.body(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 18),

        // 4. Stats Row (Recipes, Likes, Followers)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(count: recipesCount, label: 'Recipes'),
              _buildDivider(),
              _StatItem(count: likesCount, label: 'Likes'),
              _buildDivider(),
              _StatItem(count: followersCount, label: 'Followers'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 28, width: 1, color: AppColors.border);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.count, required this.label});

  final String count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
