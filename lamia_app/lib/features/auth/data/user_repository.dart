import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import 'user_model.dart';

/// Repository for user profile operations against Firestore.
///
/// Provides methods for fetching, streaming, and updating user profiles.
class UserRepository {
  UserRepository({this._firestore});

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Fetches a user profile by [uid]. Returns `null` if the document
  /// does not exist. Always reads from the server to avoid stale cache.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get(
      const GetOptions(source: Source.server),
    );
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

  /// Updates the current user's profile fields using [set] with merge.
  /// This is more resilient than [update] because it works even if the
  /// document is missing or fields don't exist yet.
  Future<void> updateProfile(
    String uid, {
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) {
      // An empty value is an intentional "clear bio" request.  Keeping the
      // field absent also prevents the profile UI from rendering stale text.
      updates['bio'] = bio.trim().isEmpty ? FieldValue.delete() : bio.trim();
    }
    if (photoUrl != null) {
      // Empty string means clear the field
      updates['photoUrl'] = photoUrl.isEmpty ? FieldValue.delete() : photoUrl;
    }
    if (updates.isEmpty) return;
    // Use set with merge: true for maximum resilience
    await _usersRef.doc(uid).set(updates, SetOptions(merge: true));
  }

  // ── Queries ──────────────────────────────────────────────────────────────

  /// Fetches users sorted by [recipeCount] descending — "Top Contributors".
  Future<List<UserModel>> topContributors({int limit = 20}) async {
    try {
      final snap = await _usersRef
          .orderBy('recipeCount', descending: true)
          .limit(limit)
          .get();
      final users = <UserModel>[];
      for (final d in snap.docs) {
        try {
          if (d.data()['recipeCount'] != null) {
            users.add(UserModel.fromFirestore(d));
          }
        } catch (_) {}
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  /// Fetches users sorted by [totalLikesReceived] descending — "Most Liked".
  Future<List<UserModel>> mostLiked({int limit = 20}) async {
    try {
      final snap = await _usersRef
          .orderBy('totalLikesReceived', descending: true)
          .limit(limit)
          .get();
      final users = <UserModel>[];
      for (final d in snap.docs) {
        try {
          if (d.data()['totalLikesReceived'] != null) {
            users.add(UserModel.fromFirestore(d));
          }
        } catch (_) {}
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  /// Search users by display name or bio. Case-insensitive and safe.
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final snap = await _usersRef.limit(100).get();
      final users = <UserModel>[];
      for (final d in snap.docs) {
        try {
          users.add(UserModel.fromFirestore(d));
        } catch (e) {
          AppLogger.warning(
            'Failed to parse user doc ${d.id}: $e',
            'UserRepository',
          );
        }
      }

      final results = users
          .where((u) =>
              u.displayName.toLowerCase().contains(q) ||
              (u.bio?.toLowerCase().contains(q) == true))
          .take(limit)
          .toList();

      AppLogger.info(
        'searchUsers found ${results.length} matches for "$query" out of ${snap.docs.length} user docs in Firestore.',
        'UserRepository',
      );
      return results;
    } catch (e, st) {
      AppLogger.error(
        'searchUsers failed for query "$query"',
        error: e,
        stackTrace: st,
        category: 'UserRepository',
      );
      return [];
    }
  }
}
