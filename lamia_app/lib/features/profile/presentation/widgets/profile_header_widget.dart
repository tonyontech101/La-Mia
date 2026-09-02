import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';

/// Header section of the Profile screen matching the wireframe arrangement
/// integrated with La Mia's vibrant appetite color palette.
///
/// Arrangement:
/// 1. Centered circular profile avatar with gradient border & edit badge
/// 2. Nickname / Display Name (Bold)
/// 3. @username Handle
/// 4. Bio text (Centered)
/// 5. Ranking badge chip (#24 ranking / Leaderboard rank)
/// 6. See your overall achievements callout link with trophy icon
/// 7. Optional Follow button (for viewing other chef profiles)
/// 8. 3-Column Stats Row: Recipes, Likes, followers (with compact numbers)
class ProfileHeaderWidget extends StatelessWidget {
  const ProfileHeaderWidget({
    super.key,
    required this.displayName,
    this.username,
    this.bio,
    this.photoUrl,
    this.rankingLabel,
    this.recognitions = const [],
    this.achievementLevelLabel,
    this.recipeCount = '0',
    this.likesCount = '0',
    this.followersCount = '0',
    this.followingCount = '0',
    this.isGuest = false,
    this.isOwnProfile = true,
    this.isFollowing = false,
    this.onEditProfileTap,
    this.onFollowTap,
    this.onRecipesTap,
    this.onLikesTap,
    this.onFollowersTap,
    this.onAchievementsTap,
  });

  final String displayName;
  final String? username;
  final String? bio;
  final String? photoUrl;
  final String? rankingLabel;
  final List<ProfileRecognition> recognitions;
  final String? achievementLevelLabel;
  final String recipeCount;
  final String likesCount;
  final String followersCount;
  final String followingCount;
  final bool isGuest;
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback? onEditProfileTap;
  final VoidCallback? onFollowTap;
  final VoidCallback? onRecipesTap;
  final VoidCallback? onLikesTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onAchievementsTap;

  String _formatHandle(String name) {
    if (username != null && username!.trim().isNotEmpty) {
      final clean = username!.trim().replaceAll('@', '');
      return '@$clean';
    }
    final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return '@${clean.isEmpty ? "foodie" : clean}';
  }

  String _formatCount(String raw) {
    final val = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (val == null) return raw;
    if (val >= 1000000) {
      final formatted = (val / 1000000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}M';
    } else if (val >= 1000) {
      final formatted = (val / 1000).toStringAsFixed(1);
      return '${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _formatHandle(displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // 1. Centered Circular Avatar with Lively Gradient Border Ring
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: isOwnProfile ? onEditProfileTap : null,
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.accent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: photoUrl != null && photoUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.surfaceAlt,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
                    ),
                  ),
                ),
              ),

              // Edit Badge (if own profile)
              if (isOwnProfile && onEditProfileTap != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onEditProfileTap,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 6,
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
        ),

        const SizedBox(height: 14),

        // 2. Nickname / Display Name (Bold & Large)
        Text(
          displayName,
          style: AppTypography.headline(
            color: AppColors.textPrimary,
          ).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 2),

        // 3. @username Handle
        Text(
          handle,
          style: AppTypography.body(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // 4. Bio of user contains here
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            (bio?.trim().isNotEmpty ?? false)
                ? bio!.trim()
                : (isGuest
                    ? 'Browsing as guest foodie. Sign in to share your recipes!'
                    : 'Bio of user contains here.'),
            style: AppTypography.body(
              color: AppColors.textSecondary,
            ).copyWith(
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 12),

        // 5. Ranking Pill Badge (e.g. #24 ranking)
        _buildRankingBadge(),

        // Extra recognition badges (if any)
        if (recognitions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: recognitions
                .map((recognition) => _RecognitionBadge(recognition))
                .toList(),
          ),
        ],

        const SizedBox(height: 12),

        // 6. See your overall achievements! Interactive Link
        if (onAchievementsTap != null)
          PressableScale(
            onTap: onAchievementsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    isOwnProfile
                        ? 'See your overall achievements!'
                        : 'See overall achievements!',
                    style: AppTypography.caption(
                      color: const Color(0xFF0284C7),
                    ).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Follow Button for Other User Profiles
        if (!isOwnProfile && onFollowTap != null) ...[
          const SizedBox(height: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              elevation: isFollowing ? 0 : 2,
              side: isFollowing
                  ? const BorderSide(color: AppColors.border, width: 1.2)
                  : BorderSide.none,
            ),
            child: Text(
              isFollowing ? 'Following' : '+ Follow Chef',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // 7. Stats Row (24 Recipes | 1.2k Likes | 850 followers)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
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
                count: _formatCount(recipeCount),
                label: 'Recipes',
                onTap: onRecipesTap,
              ),
              _buildDivider(),
              _StatItem(
                count: _formatCount(likesCount),
                label: 'Likes',
                onTap: onLikesTap,
              ),
              _buildDivider(),
              _StatItem(
                count: _formatCount(followersCount),
                label: 'followers',
                onTap: onFollowersTap,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankingBadge() {
    final text = rankingLabel ??
        (achievementLevelLabel != null
            ? '#${achievementLevelLabel!.split(" ").first} ranking'
            : '#24 ranking');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.caption(
          color: AppColors.textPrimary,
        ).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
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
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 22,
      width: 1,
      color: AppColors.border.withValues(alpha: 0.8),
    );
  }
}

/// A public, presentation-only description of one earned profile badge.
class ProfileRecognition {
  const ProfileRecognition({
    required this.label,
    required this.icon,
    required this.color,
    this.detail,
    this.onTap,
  });

  final String label;
  final String? detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class _RecognitionBadge extends StatelessWidget {
  const _RecognitionBadge(this.recognition);

  final ProfileRecognition recognition;

  @override
  Widget build(BuildContext context) {
    final badgeText = recognition.detail == null
        ? recognition.label
        : '${recognition.label} ${recognition.detail}';
    final badgeWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: recognition.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: recognition.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(recognition.icon, color: recognition.color, size: 14),
          const SizedBox(width: 4.5),
          Text(
            badgeText,
            style: AppTypography.caption(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          if (recognition.onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.edit_rounded,
              size: 11,
              color: recognition.color.withValues(alpha: 0.8),
            ),
          ],
        ],
      ),
    );

    if (recognition.onTap != null) {
      return PressableScale(
        pressedScale: 0.95,
        onTap: recognition.onTap,
        child: badgeWidget,
      );
    }
    return badgeWidget;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: AppTypography.title(
              color: AppColors.textPrimary,
            ).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            label,
            style: AppTypography.caption(
              color: AppColors.textSecondary,
            ).copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return PressableScale(
        pressedScale: 0.94,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
