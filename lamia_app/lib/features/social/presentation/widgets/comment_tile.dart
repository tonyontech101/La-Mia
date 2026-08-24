import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/comment_model.dart';

/// A single comment bubble — used for both top-level comments and replies.
///
/// When [isTopLevel] is false the tile renders a lighter, indented style
/// (no shadow, surfaceAlt fill, smaller avatar/body text).
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserUid,
    this.isTopLevel = true,
    this.onToggleLike,
    this.onReply,
    this.onDelete,
    this.isLikeInFlight = false,
  });

  final CommentModel comment;
  final String? currentUserUid;
  final bool isTopLevel;
  final VoidCallback? onToggleLike;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final bool isLikeInFlight;

  bool get _isAuthor => currentUserUid != null && currentUserUid == comment.userId;
  bool get _isLiked => currentUserUid != null && comment.isLikedBy(currentUserUid!);

  @override
  Widget build(BuildContext context) {
    final avatarSize = isTopLevel ? 34.0 : 28.0;
    final bodyFontSize = isTopLevel ? 13.0 : 12.5;
    final horizontalPad = isTopLevel ? AppSpacing.md : AppSpacing.sm;
    final verticalPad = isTopLevel ? AppSpacing.md : AppSpacing.xs;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        _buildAvatar(avatarSize),
        const SizedBox(width: AppSpacing.sm),

        // Bubble
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPad,
              vertical: verticalPad,
            ),
            decoration: BoxDecoration(
              color: isTopLevel ? AppColors.surface : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.field),
              border: isTopLevel ? Border.all(color: AppColors.border) : null,
              boxShadow: isTopLevel
                  ? [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        offset: const Offset(0, 1),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: name + time + delete
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        style: AppTypography.bodyStrong(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: isTopLevel ? 15 : 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '• ${comment.timeAgo}',
                      style: AppTypography.caption(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (_isAuthor && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isTopLevel ? AppSpacing.xxs : 2),

                // Body
                Text(
                  comment.text,
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: isTopLevel ? AppSpacing.sm : AppSpacing.xs),

                // Action bar
                Row(
                  children: [
                    // Like
                    GestureDetector(
                      onTap: isLikeInFlight ? null : onToggleLike,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: isTopLevel ? 15 : 13,
                            color: _isLiked
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          if (comment.likeCount > 0) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              '${comment.likeCount}',
                              style: AppTypography.label(
                                color: _isLiked
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ).copyWith(fontSize: isTopLevel ? 12 : 11),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Reply (top-level only)
                    if (isTopLevel && onReply != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: onReply,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              'Reply',
                              style: AppTypography.label(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(double size) {
    final radius = size / 2;
    final initialsStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
      fontSize: size * 0.38,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: comment.userPhotoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CachedNetworkImage(
                imageUrl: comment.userPhotoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : 'U',
                    style: initialsStyle,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : 'U',
                style: initialsStyle,
              ),
            ),
    );
  }
}
