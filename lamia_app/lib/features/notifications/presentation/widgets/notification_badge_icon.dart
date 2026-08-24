import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/notification_repository.dart';
import '../notifications_screen.dart';

class NotificationBadgeIcon extends StatelessWidget {
  const NotificationBadgeIcon({
    super.key,
    this.isGuest = false,
  });

  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuestMode = isGuest || user == null;
    final notifRepo = NotificationRepository();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotificationsScreen(isGuest: isGuestMode),
          ),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceAlt,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            if (!isGuestMode)
              StreamBuilder<int>(
                stream: notifRepo.watchUnreadCount(user.uid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 10,
                        minHeight: 10,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
