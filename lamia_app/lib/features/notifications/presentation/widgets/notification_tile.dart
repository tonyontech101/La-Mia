import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/notification_model.dart';
import '../../services/notification_router.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  final NotificationModel notification;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  IconData _getTypeIcon() {
    switch (notification.type) {
      case NotificationType.recipeLike:
      case NotificationType.commentLike:
        return Icons.favorite_rounded;
      case NotificationType.recipeComment:
        return Icons.comment_rounded;
      case NotificationType.commentReply:
        return Icons.reply_rounded;
      case NotificationType.newFollower:
        return Icons.person_add_rounded;
      case NotificationType.followingNewRecipe:
        return Icons.restaurant_rounded;
      case NotificationType.recipeApproved:
        return Icons.verified_rounded;
      case NotificationType.mealReminder:
        return Icons.alarm_rounded;
      case NotificationType.dailySuggestion:
        return Icons.lightbulb_rounded;
      case NotificationType.achievement:
        return Icons.emoji_events_rounded;
      case NotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color _getTypeIconColor() {
    switch (notification.type) {
      case NotificationType.recipeLike:
      case NotificationType.commentLike:
        return Colors.red;
      case NotificationType.recipeComment:
        return Colors.amber[800]!;
      case NotificationType.commentReply:
        return AppColors.accent;
      case NotificationType.newFollower:
        return Colors.teal;
      case NotificationType.followingNewRecipe:
        return Colors.orange;
      case NotificationType.recipeApproved:
        return Colors.green;
      case NotificationType.mealReminder:
        return Colors.blue;
      case NotificationType.dailySuggestion:
        return Colors.amber[600]!;
      case NotificationType.achievement:
        return Colors.amber[800]!;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSenderPhoto = notification.senderPhotoUrl != null &&
        notification.senderPhotoUrl!.isNotEmpty;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red[100],
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
      ),
      child: InkWell(
        onTap: () {
          onMarkAsRead();
          NotificationRouter.navigate(context, notification);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.04),
            border: const Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: User Avatar or Type Icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: hasSenderPhoto
                        ? CachedNetworkImageProvider(notification.senderPhotoUrl!)
                        : null,
                    child: !hasSenderPhoto
                        ? Icon(
                            _getTypeIcon(),
                            color: _getTypeIconColor(),
                            size: 20,
                          )
                        : null,
                  ),
                  if (hasSenderPhoto)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getTypeIcon(),
                          color: _getTypeIconColor(),
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Middle: Notification Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: AppTypography.body(
                            color: AppColors.textPrimary,
                          ).copyWith(
                            fontSize: 13,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                        Text(
                          _formatTimeAgo(notification.createdAt),
                          style: AppTypography.caption(
                            color: AppColors.textSecondary,
                          ).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTypography.body(
                        color: AppColors.textSecondary,
                      ).copyWith(
                        fontSize: 12,
                        fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Unread Dot Indicator
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
