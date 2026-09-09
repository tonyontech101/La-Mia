import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_model.dart';
import 'notification_preference_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userNotifications(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  static final Map<String, DateTime> _recentDispatches = {};

  /// Streams notifications for a user, ordered by newest first, optionally filtered by category.
  Stream<List<NotificationModel>> watchNotifications(String userId, {String? filter}) {
    // Query by createdAt descending (automatically indexed single field in Firestore).
    // Filtering by category is performed in-memory to prevent missing composite index errors.
    return _userNotifications(userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          final notifications =
              snap.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList();

          if (filter == null || filter == 'all') {
            return notifications;
          }

          return notifications.where((n) {
            switch (filter) {
              case 'social':
                return n.type == NotificationType.recipeLike ||
                    n.type == NotificationType.recipeComment ||
                    n.type == NotificationType.commentLike ||
                    n.type == NotificationType.commentReply ||
                    n.type == NotificationType.newFollower ||
                    n.type == NotificationType.followingNewRecipe;
              case 'planner':
                return n.type == NotificationType.mealReminder ||
                    n.type == NotificationType.dailySuggestion;
              case 'system':
                return n.type == NotificationType.recipeApproved ||
                    n.type == NotificationType.achievement ||
                    n.type == NotificationType.system;
              default:
                return true;
            }
          }).toList();
        });
  }

  /// Streams real-time count of unread notifications.
  Stream<int> watchUnreadCount(String userId) {
    return _userNotifications(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Creates a new notification document.
  Future<void> sendNotification({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? targetId,
    required TargetType targetType,
    String? targetRoute,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    // Avoid self-notifications
    if (senderId == recipientId) return;

    // In-memory debouncing for duplicate social notifications (prevents cross-user read security rule errors)
    if ((type == NotificationType.recipeLike ||
            type == NotificationType.commentLike ||
            type == NotificationType.commentReply) &&
        targetId != null &&
        senderId != null) {
      final key = '${recipientId}_${type.value}_${targetId}_$senderId';
      final lastSent = _recentDispatches[key];
      final now = DateTime.now();
      if (lastSent != null && now.difference(lastSent) < const Duration(minutes: 2)) {
        // Debounce duplicate interaction from this client within 2 minutes
        return;
      }
      _recentDispatches[key] = now;
      if (_recentDispatches.length > 200) {
        _recentDispatches.removeWhere(
          (_, time) => now.difference(time) > const Duration(minutes: 10),
        );
      }
    }

    final docRef = _userNotifications(recipientId).doc();
    final notif = NotificationModel(
      id: docRef.id,
      userId: recipientId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      type: type,
      title: title,
      body: body,
      targetId: targetId,
      targetType: targetType,
      targetRoute: targetRoute,
      imageUrl: imageUrl,
      metadata: metadata,
      isRead: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(notif.toFirestore());

    try {
      final userRef = _firestore.collection('users').doc(recipientId);
      await userRef.set(
        {'unreadNotificationCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      // Counter update non-fatal; notification document is already persisted
    }
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(String userId, String notificationId) async {
    final docRef = _userNotifications(userId).doc(notificationId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final wasRead = doc.data()?['isRead'] as bool? ?? false;
    if (!wasRead) {
      final batch = _firestore.batch();
      batch.update(docRef, {'isRead': true});
      batch.set(
        _firestore.collection('users').doc(userId),
        {'unreadNotificationCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
      await batch.commit();
    }
  }

  /// Marks all unread notifications for a user as read.
  Future<void> markAllAsRead(String userId) async {
    final snap = await _userNotifications(userId).where('isRead', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    batch.set(
      _firestore.collection('users').doc(userId),
      {'unreadNotificationCount': 0},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Deletes a specific notification.
  Future<void> deleteNotification(String userId, String notificationId) async {
    final docRef = _userNotifications(userId).doc(notificationId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final isRead = doc.data()?['isRead'] as bool? ?? false;

    final batch = _firestore.batch();
    batch.delete(docRef);

    if (!isRead) {
      batch.set(
        _firestore.collection('users').doc(userId),
        {'unreadNotificationCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Clears all notifications for a user.
  Future<void> clearAllNotifications(String userId) async {
    final snap = await _userNotifications(userId).get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }

    batch.set(
      _firestore.collection('users').doc(userId),
      {'unreadNotificationCount': 0},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Fetches granular notification preferences for a user.
  Future<NotificationPreferenceModel> getNotificationPreferences(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return NotificationPreferenceModel.defaults();
    final data = doc.data();
    final prefData = data?['notificationPreferences'] as Map<String, dynamic>?;
    return NotificationPreferenceModel.fromMap(prefData);
  }

  /// Saves/updates notification preferences for a user.
  Future<void> updateNotificationPreferences(String userId, NotificationPreferenceModel prefs) async {
    await _firestore.collection('users').doc(userId).set({
      'notificationPreferences': prefs.toMap(),
    }, SetOptions(merge: true));
  }

  /// Saves a device FCM token to the user document.
  Future<void> saveFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Removes a device FCM token (useful on logout).
  Future<void> removeFcmToken(String userId, String token) async {
    await _firestore.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }
}
