import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';

/// Wireframe-matching app bar for the Home Feed screen.
///
/// Layout: [Avatar]  —  [La Mia + subtitle]  —  [Notification Icon]
class FeedAppBar extends StatelessWidget {
  const FeedAppBar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.isGuest = false,
    this.onProfileTap,
  });

  final String displayName;
  final String? photoUrl;
  final bool isGuest;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Left: Small circular avatar
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // Center: "La Mia" + subtitle (expanded to push to center)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'La Mia',
                  style: AppTypography.wordmark(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  'Filipino Recipe & Meal Assistant',
                  style: AppTypography.caption(color: AppColors.textSecondary)
                      .copyWith(
                        fontSize: 9,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),

          // Right: Notifications icon
          NotificationBadgeIcon(isGuest: isGuest),
        ],
      ),
    );
  }
}
