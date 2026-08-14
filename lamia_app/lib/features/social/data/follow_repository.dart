import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/user_model.dart';

/// Manages the follow/unfollow relationship between users.
///
/// Uses two parallel subcollections for efficient bidirectional queries:
/// - `followers/{userId}/users/{followerUid}` — who follows this user
/// - `following/{userId}/users/{targetUid}` — who this user follows
///
/// Both are existence-based (like the likes pattern). Counter updates
/// are batched for consistency.
class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Toggles the follow state: [currentUid] follows/unfollows [targetUid].
  ///
  /// Returns `true` if now following, `false` if unfollowed.
  /// Updates counters on both user documents in a batch write.
  Future<bool> toggleFollow({
    required String currentUid,
    required String targetUid,
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
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });
      batch.update(targetUserRef, {
        'followerCount': FieldValue.increment(-1),
      });
    } else {
      // Follow
      final now = FieldValue.serverTimestamp();
      batch.set(followingRef, {'followedAt': now});
      batch.set(followerRef, {'followedAt': now});
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });
      batch.update(targetUserRef, {
        'followerCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
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

  /// Returns the UIDs of all users that [uid] is following.
  Future<List<String>> getFollowingIds(String uid) async {
    final snap = await _firestore
        .collection('following')
        .doc(uid)
        .collection('users')
        .get();
    return snap.docs.map((d) => d.id).toList();
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
