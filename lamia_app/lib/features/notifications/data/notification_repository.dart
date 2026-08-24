import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_model.dart';
import 'notification_preference_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userNotifications(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  /// Streams notifications for a user, ordered by newest first, optionally filtered by category.
  Stream<List<NotificationModel>> watchNotifications(String userId, {String? filter}) {
    Query<Map<String, dynamic>> query = _userNotifications(userId).orderBy('createdAt', descending: true);

    if (filter != null && filter != 'all') {
      List<String> types = [];
      if (filter == 'social') {
        types = ['recipe_like', 'recipe_comment', 'comment_like', 'comment_reply', 'new_follower', 'following_new_recipe'];
      } else if (filter == 'planner') {
        types = ['meal_reminder', 'daily_suggestion'];
      } else if (filter == 'system') {
        types = ['recipe_approved', 'achievement', 'system'];
      }

      if (types.isNotEmpty) {
        query = query.where('type', whereIn: types);
      }
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
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

    // Check for debouncing duplicate social notifications within the last 5 minutes
    if ((type == NotificationType.recipeLike ||
            type == NotificationType.commentLike ||
            type == NotificationType.commentReply) &&
        targetId != null &&
        senderId != null) {
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final recent = await _userNotifications(recipientId)
          .where('type', isEqualTo: type.value)
          .where('targetId', isEqualTo: targetId)
          .where('senderId', isEqualTo: senderId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fiveMinAgo))
          .limit(1)
          .get();

      if (recent.docs.isNotEmpty) {
        // Notification already generated recently, skip to prevent spam
        return;
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

    final batch = _firestore.batch();
    batch.set(docRef, notif.toFirestore());

    // Update denormalized counter on user profile if preferred
    final userRef = _firestore.collection('users').doc(recipientId);
    batch.set(
      userRef,
      {'unreadNotificationCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );

    await batch.commit();
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
