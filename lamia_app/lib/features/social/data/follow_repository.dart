import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../auth/data/user_model.dart';
import '../../notifications/data/notification_model.dart';
import '../../notifications/data/notification_repository.dart';

/// Real-time stream of user IDs that the current signed-in user is following.
final currentUserFollowingIdsProvider = StreamProvider<Set<String>>((ref) {
  final currentUid = ref.watch(currentUserIdProvider);
  if (currentUid == null) return Stream.value(const <String>{});
  final followRepo = ref.watch(followRepositoryProvider);
  return followRepo.followingIdsStream(currentUid);
});

/// Real-time stream of user IDs who follow the current signed-in user.
final currentUserFollowerIdsProvider = StreamProvider<Set<String>>((ref) {
  final currentUid = ref.watch(currentUserIdProvider);
  if (currentUid == null) return Stream.value(const <String>{});
  final followRepo = ref.watch(followRepositoryProvider);
  return followRepo.followerIdsStream(currentUid);
});

/// Manages the follow/unfollow relationship between users.
///
/// Uses two parallel subcollections for efficient bidirectional queries:
/// - `followers/{userId}/users/{followerUid}` — who follows this user
/// - `following/{userId}/users/{targetUid}` — who this user follows
///
/// Both are existence-based (like the likes pattern). Counter updates
/// are batched for consistency.
class FollowRepository {
  FollowRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifRepo = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notifRepo;

  /// Toggles the follow state: [currentUid] follows/unfollows [targetUid].
  ///
  /// Returns `true` if now following, `false` if unfollowed.
  /// Updates counters on both user documents in a batch write.
  Future<bool> toggleFollow({
    required String currentUid,
    required String targetUid,
    String? currentUserName,
    String? currentUserPhotoUrl,
  }) async {
    if (currentUid == targetUid) return false; // Can't follow yourself.

    final followingRef = _firestore
        .collection('following')
        .doc(currentUid)
        .collection('users')
        .doc(targetUid);

    final followerRef = _firestore
        .collection('followers')
        .doc(targetUid)
        .collection('users')
        .doc(currentUid);

    final followDoc = await followingRef.get();
    final isCurrentlyFollowing = followDoc.exists;

    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUid);
    final targetUserRef = _firestore.collection('users').doc(targetUid);

    if (isCurrentlyFollowing) {
      // Unfollow
      batch.delete(followingRef);
      batch.delete(followerRef);
      batch.set(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
      batch.set(targetUserRef, {
        'followerCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    } else {
      // Follow
      final now = FieldValue.serverTimestamp();
      batch.set(followingRef, {'followedAt': now});
      batch.set(followerRef, {'followedAt': now});
      batch.set(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      batch.set(targetUserRef, {
        'followerCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    // Dispatch social notification on follow
    if (!isCurrentlyFollowing) {
      final name = (currentUserName != null && currentUserName.isNotEmpty)
          ? currentUserName
          : 'A foodie';
      try {
        await _notifRepo.sendNotification(
          recipientId: targetUid,
          type: NotificationType.newFollower,
          title: 'New Follower',
          body: '$name started following your culinary journey.',
          senderId: currentUid,
          senderName: name,
          senderPhotoUrl: currentUserPhotoUrl,
          targetId: currentUid,
          targetType: TargetType.user,
        );
      } catch (_) {}
    }

    return !isCurrentlyFollowing;
  }

  /// Checks whether [currentUid] follows [targetUid].
  Future<bool> isFollowing({
    required String currentUid,
    required String targetUid,
  }) async {
    final doc = await _firestore
        .collection('following')
        .doc(currentUid)
        .collection('users')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  /// Checks whether [targetUid] follows [currentUid] (i.e. target is following current).
  Future<bool> isFollowedBy({
    required String currentUid,
    required String targetUid,
  }) async {
    final doc = await _firestore
        .collection('followers')
        .doc(currentUid)
        .collection('users')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  /// Returns the UIDs of all users that [uid] is following.
  Future<List<String>> getFollowingIds(String uid) async {
    final snap = await _firestore
        .collection('following')
        .doc(uid)
        .collection('users')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Emits real-time updates of all target UIDs that [uid] is following.
  Stream<Set<String>> followingIdsStream(String uid) {
    return _firestore
        .collection('following')
        .doc(uid)
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Emits real-time updates of all follower UIDs who follow [uid].
  Stream<Set<String>> followerIdsStream(String uid) {
    return _firestore
        .collection('followers')
        .doc(uid)
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Returns the [UserModel] list of users that [uid] is following.
  Future<List<UserModel>> getFollowing(String uid) async {
    final ids = await getFollowingIds(uid);
    return _fetchUsersByIds(ids);
  }

  /// Returns the UIDs of all users who follow [uid].
  Future<List<String>> getFollowerIds(String uid) async {
    final snap = await _firestore
        .collection('followers')
        .doc(uid)
        .collection('users')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Returns the [UserModel] list of users who follow [uid].
  Future<List<UserModel>> getFollowers(String uid) async {
    final ids = await getFollowerIds(uid);
    return _fetchUsersByIds(ids);
  }

  /// Fetches [UserModel] objects for a list of UIDs, chunking to respect
  /// Firestore's `whereIn` 30-element limit.
  Future<List<UserModel>> _fetchUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <UserModel>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => UserModel.fromFirestore(d)));
    }
    return results;
  }
}
