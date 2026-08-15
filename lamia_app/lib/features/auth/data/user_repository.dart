import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

/// Repository for user profile operations against Firestore.
///
/// Provides methods for fetching, streaming, and updating user profiles.
/// Profile photo upload is deferred to a later phase.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Fetches a user profile by [uid]. Returns `null` if the document
  /// does not exist.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Returns a real-time stream of a user profile. Emits `null` when the
  /// document does not exist or is deleted.
  Stream<UserModel?> getUserStream(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // ── Update ───────────────────────────────────────────────────────────────

  /// Updates the current user's profile fields. Only the provided fields
  /// are updated; `null` values are skipped.
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? bio,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (updates.isEmpty) return;
    await _usersRef.doc(uid).update(updates);
  }

  // ── Queries ──────────────────────────────────────────────────────────────

  /// Fetches users sorted by [recipeCount] descending — "Top Contributors".
  Future<List<UserModel>> topContributors({int limit = 20}) async {
    final snap = await _usersRef
        .orderBy('recipeCount', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .where((d) => d.data()['recipeCount'] != null)
        .map((d) => UserModel.fromFirestore(d))
        .toList();
  }

  /// Fetches users sorted by [totalLikesReceived] descending — "Most Liked".
  Future<List<UserModel>> mostLiked({int limit = 20}) async {
    final snap = await _usersRef
        .orderBy('totalLikesReceived', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .where((d) => d.data()['totalLikesReceived'] != null)
        .map((d) => UserModel.fromFirestore(d))
        .toList();
  }

  /// Prefix search for users by display name. Returns up to [limit] users.
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final snap = await _usersRef
        .where('displayName', isGreaterThanOrEqualTo: q)
        .where('displayName', isLessThan: '$q\uffff')
        .orderBy('displayName')
        .limit(limit)
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }
}
