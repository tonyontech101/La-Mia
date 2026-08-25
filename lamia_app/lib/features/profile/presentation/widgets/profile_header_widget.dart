import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Header section of the Profile screen based on wireframe design.
///
/// Features:
/// - Circular profile avatar with status/online badge
/// - Earned leaderboard recognition badges
/// - Bio text section
/// - 3-column stats row: Following, Followers, Likes
class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({
    super.key,
    required this.displayName,
    this.bio,
    this.photoUrl,
    this.recognitions = const [],
    this.achievementLevelLabel,
    this.followingCount = '0',
    this.followersCount = '0',
    this.likesCount = '0',
    this.isGuest = false,
    this.isOwnProfile = true,
    this.isFollowing = false,
    this.onEditProfileTap,
    this.onFollowTap,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onLikesTap,
    this.onAchievementsTap,
  });

  final String displayName;
  final String? bio;
  final String? photoUrl;
  final List<ProfileRecognition> recognitions;
  final String? achievementLevelLabel;
  final String followingCount;
  final String followersCount;
  final String likesCount;
  final bool isGuest;
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback? onEditProfileTap;
  final VoidCallback? onFollowTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onLikesTap;
  final VoidCallback? onAchievementsTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Avatar with edit badge (if own profile)
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
            if (isOwnProfile && onEditProfileTap != null)
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

        // 2. Recognition badges (only shown for earned recognitions).
        if (recognitions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: recognitions
                .map((recognition) => _RecognitionBadge(recognition))
                .toList(),
          ),
        ],

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
            (bio?.trim().isNotEmpty ?? false)
                ? bio!.trim()
                : (isGuest ? 'Browsing as guest foodie' : 'No bio added yet.'),
            style: AppTypography.body(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        if (achievementLevelLabel != null && onAchievementsTap != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAchievementsTap,
            icon: const Icon(Icons.emoji_events_rounded, size: 17),
            label: Text(
              '${isOwnProfile ? 'Your' : 'View'} achievements · '
              '$achievementLevelLabel',
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary,
              textStyle: AppTypography.caption().copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],

        // 3b. Follow Button for Other User Profiles
        if (!isOwnProfile && onFollowTap != null) ...[
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onFollowTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing
                  ? AppColors.surfaceAlt
                  : AppColors.primary,
              foregroundColor: isFollowing
                  ? AppColors.textPrimary
                  : AppColors.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              elevation: isFollowing ? 0 : 2,
            ),
            child: Text(
              isFollowing ? 'Following' : '+ Follow',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],

        const SizedBox(height: 18),

        // 4. Stats Row (Following, Followers, Likes)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              _StatItem(
                count: followingCount,
                label: 'Following',
                onTap: onFollowingTap,
              ),
              _buildDivider(),
              _StatItem(
                count: followersCount,
                label: 'Followers',
                onTap: onFollowersTap,
              ),
              _buildDivider(),
              _StatItem(
                count: likesCount,
                label: 'Likes',
                onTap: onLikesTap,
              ),
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

/// A public, presentation-only description of one earned profile badge.
class ProfileRecognition {
  const ProfileRecognition({
    required this.label,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String label;
  final String? detail;
  final IconData icon;
  final Color color;
}

class _RecognitionBadge extends StatelessWidget {
  const _RecognitionBadge(this.recognition);

  final ProfileRecognition recognition;

  @override
  Widget build(BuildContext context) {
    final badgeText = recognition.detail == null
        ? recognition.label
        : '${recognition.label} ${recognition.detail}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: recognition.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: recognition.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(recognition.icon, color: recognition.color, size: 15),
          const SizedBox(width: 5),
          Text(
            badgeText,
            style: AppTypography.caption(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    this.onTap,
  });

  final String count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
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
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: content,
      );
    }

    return content;
  }
}
