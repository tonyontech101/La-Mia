import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../profile/presentation/settings_screen.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';
import 'widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationRepository get _notifRepo => ref.read(notificationRepositoryProvider);
  String _selectedFilter = 'all'; // 'all', 'social', 'planner', 'system'

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isGuestMode = widget.isGuest || currentUserId == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTypography.brandWordmark().copyWith(
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!isGuestMode)
            StreamBuilder<int>(
              stream: _notifRepo.watchUnreadCount(currentUserId),
              builder: (context, snapshot) {
                final hasUnread = (snapshot.data ?? 0) > 0;
                if (!hasUnread) return const SizedBox.shrink();

                return IconButton(
                  icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
                  tooltip: 'Mark all as read',
                  onPressed: () => _notifRepo.markAllAsRead(currentUserId),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(isGuest: widget.isGuest),
                ),
              );
            },
          ),
        ],
      ),
      body: isGuestMode
          ? _buildGuestEmptyState()
          : Column(
              children: [
                // Filter chips
                _buildFilterChips(),

                // List
                Expanded(
                  child: StreamBuilder<List<NotificationModel>>(
                    stream: _notifRepo.watchNotifications(currentUserId, filter: _selectedFilter),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final notifications = snapshot.data ?? [];
                      if (notifications.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        itemCount: notifications.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return NotificationTile(
                            notification: notif,
                            onMarkAsRead: () => _notifRepo.markAsRead(currentUserId, notif.id),
                            onDelete: () => _notifRepo.deleteNotification(currentUserId, notif.id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'All'),
            const SizedBox(width: 8),
            _buildFilterChip('social', 'Interactions'),
            const SizedBox(width: 8),
            _buildFilterChip('planner', 'Meal Planner'),
            const SizedBox(width: 8),
            _buildFilterChip('system', 'System'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 0.8,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: AppTypography.title(color: AppColors.textPrimary).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Walang bagong ulat sa kusina! You will see alerts for recipe likes, comments, and scheduled meal updates here.',
              textAlign: TextAlign.center,
              style: AppTypography.body(color: AppColors.textSecondary).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to see notifications',
              style: AppTypography.title(color: AppColors.textPrimary).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Join the La Mia community to post Filipino recipes, interact with fellow foodies, and save custom meal planner alerts.',
              textAlign: TextAlign.center,
              style: AppTypography.body(color: AppColors.textSecondary).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
