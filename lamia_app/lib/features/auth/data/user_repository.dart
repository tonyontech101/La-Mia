import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import 'user_model.dart';

/// Repository for user profile operations against Firestore.
///
/// Provides methods for fetching, streaming, and updating user profiles.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  FirebaseFirestore get _db => _firestore;

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
    String? featuredAchievementId,
    bool clearFeaturedAchievement = false,
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
    if (clearFeaturedAchievement) {
      updates['featuredAchievementId'] = FieldValue.delete();
    } else if (featuredAchievementId != null) {
      updates['featuredAchievementId'] = featuredAchievementId;
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

  /// Fetches users sorted by [followerCount] descending — "Top Contributors".
  ///
  /// Ranks cooks by how many followers they have, reflecting their
  /// community influence and reach on the platform.
  Future<List<UserModel>> topContributorsByFollowers({int limit = 20}) async {
    try {
      final snap = await _usersRef
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();
      final users = <UserModel>[];
      for (final d in snap.docs) {
        try {
          users.add(UserModel.fromFirestore(d));
        } catch (e) {
          AppLogger.warning('Failed to parse user ${d.id}: $e', 'UserRepository');
        }
      }
      // If Firestore returned users (even those without the field), that's fine
      // — fromFirestore defaults followerCount to 0. Return as-is.
      if (users.isNotEmpty) return users;
      throw Exception('No users returned from ordered query');
    } catch (e) {
      AppLogger.warning('Error fetching top contributors (falling back): $e', 'UserRepository');
      // Fallback: fetch a larger batch without order, sort in Dart.
      // Use 200 as the cap so we get the true top-N even if some are unordered.
      try {
        final fallbackSnap = await _usersRef.limit(200).get();
        final users = <UserModel>[];
        for (final d in fallbackSnap.docs) {
          try {
            users.add(UserModel.fromFirestore(d));
          } catch (_) {}
        }
        users.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        return users.take(limit).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Ranks cooks by their actual uploaded recipes instead of the denormalized
  /// `users.recipeCount` value. This keeps the leaderboard correct for legacy
  /// profiles whose counter was never populated.
  Future<List<UserModel>> mostCookedByUploadedRecipes({int limit = 20}) async {
    try {
      final recipes = await _db.collection('recipes').limit(500).get();
      final counts = <String, int>{};
      for (final recipe in recipes.docs) {
        final data = recipe.data();
        final authorId = data['authorId'] as String?;
        final isSystemRecipe = data['isSystemRecipe'] as bool? ?? true;
        if (authorId == null || authorId.isEmpty || isSystemRecipe) continue;
        counts.update(authorId, (current) => current + 1, ifAbsent: () => 1);
      }

      final entries = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final cooks = <UserModel>[];
      for (final entry in entries.take(limit)) {
        final user = await getUser(entry.key);
        if (user != null) cooks.add(user.copyWith(recipeCount: entry.value));
      }
      return cooks;
    } catch (e) {
      AppLogger.warning('Error calculating uploaded recipe counts: $e', 'UserRepository');
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

  /// Returns the 1-based leaderboard ranking for [uid] across top contributors,
  /// or `null` if the user is not in the rankings (e.g., 0 followers or unranked).
  Future<int?> getUserLeaderboardRank(String uid) async {
    try {
      final contributors = await topContributorsByFollowers(limit: 100);
      for (var i = 0; i < contributors.length; i++) {
        if (contributors[i].uid == uid && contributors[i].followerCount > 0) {
          return i + 1;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
