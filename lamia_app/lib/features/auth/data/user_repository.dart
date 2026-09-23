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
    try {
      return _usersRef.doc(uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return UserModel.fromFirestore(doc);
      });
    } catch (_) {
      return Stream.fromFuture(getUser(uid));
    }
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

  /// Counts uploaded (non-system) recipes per author, capped at the first
  /// 500 recipe docs — same window the rest of the leaderboard uses.
  Future<Map<String, int>> _recipeCountsByAuthor() async {
    final recipes = await _db.collection('recipes').limit(500).get();
    final counts = <String, int>{};
    for (final recipe in recipes.docs) {
      final data = recipe.data();
      final authorId = data['authorId'] as String?;
      final isSystemRecipe = data['isSystemRecipe'] as bool? ?? true;
      if (authorId == null || authorId.isEmpty || isSystemRecipe) continue;
      counts.update(authorId, (current) => current + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  /// Fetches users by document ID (chunked — Firestore caps `whereIn` at 30).
  Future<List<UserModel>> _usersByIds(Set<String> ids) async {
    final users = <UserModel>[];
    final idList = ids.toList();
    for (var i = 0; i < idList.length; i += 30) {
      final chunk = idList.sublist(
        i,
        i + 30 > idList.length ? idList.length : i + 30,
      );
      final snap = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        try {
          users.add(UserModel.fromFirestore(d));
        } catch (e) {
          AppLogger.warning('Failed to parse user ${d.id}: $e', 'UserRepository');
        }
      }
    }
    return users;
  }

  /// Fetches users sorted by [followerCount] descending — "Top Contributors".
  ///
  /// Only users who have uploaded at least one recipe are ranked, so
  /// recipe-less accounts (even with followers) never appear in the
  /// Top 3 or "Trending Cooks" sections.
  Future<List<UserModel>> topContributorsByFollowers({int limit = 20}) async {
    try {
      final authorCounts = await _recipeCountsByAuthor();
      final authorIds = authorCounts.keys.toSet();
      if (authorIds.isEmpty) return [];

      // Over-fetch followers so filtering out non-authors still fills [limit].
      final fetchLimit = limit * 10 > 100 ? limit * 10 : 100;
      final snap = await _usersRef
          .orderBy('followerCount', descending: true)
          .limit(fetchLimit)
          .get();
      final users = <UserModel>[];
      for (final d in snap.docs) {
        if (!authorIds.contains(d.id)) continue;
        try {
          users.add(UserModel.fromFirestore(d));
        } catch (e) {
          AppLogger.warning('Failed to parse user ${d.id}: $e', 'UserRepository');
        }
        if (users.length >= limit) break;
      }
      if (users.isNotEmpty) return users;

      // No authors in the top follower window — rank the authors directly.
      final authors = await _usersByIds(authorIds);
      authors.sort((a, b) => b.followerCount.compareTo(a.followerCount));
      return authors.take(limit).toList();
    } catch (e) {
      AppLogger.warning('Error fetching top contributors (falling back): $e', 'UserRepository');
      try {
        final authorCounts = await _recipeCountsByAuthor();
        final authorIds = authorCounts.keys.toSet();
        if (authorIds.isEmpty) return [];

        final fallbackSnap = await _usersRef.limit(200).get();
        final users = <UserModel>[];
        for (final d in fallbackSnap.docs) {
          if (!authorIds.contains(d.id)) continue;
          try {
            users.add(UserModel.fromFirestore(d));
          } catch (_) {}
        }
        if (users.isNotEmpty) {
          users.sort((a, b) => b.followerCount.compareTo(a.followerCount));
          return users.take(limit).toList();
        }

        final authors = await _usersByIds(authorIds);
        authors.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        return authors.take(limit).toList();
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
      final counts = await _recipeCountsByAuthor();

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

  /// Ranks cooks by recent recipe engagement — "Trending Cooks".
  ///
  /// Each approved recipe contributes its `trendingScore`, which the hourly
  /// Cloud Function refreshes with a 14-day half-life, so the ranking
  /// reflects who people are engaging with *now* rather than all-time
  /// totals. If `trendingScore` has not been computed yet, raw likes,
  /// favorites, and comments are used as a fallback.
  Future<List<TrendingCook>> trendingCooks({int limit = 6}) async {
    try {
      final recipes = await _db
          .collection('recipes')
          .where('status', isEqualTo: 'approved')
          .limit(500)
          .get();
      final scores = <String, int>{};
      for (final recipe in recipes.docs) {
        final data = recipe.data();
        final authorId = data['authorId'] as String?;
        final isSystemRecipe = data['isSystemRecipe'] as bool? ?? true;
        if (authorId == null || authorId.isEmpty || isSystemRecipe) continue;

        var score = (data['trendingScore'] as num?)?.toInt() ?? 0;
        if (score <= 0) {
          score = ((data['likeCount'] as num?)?.toInt() ?? 0) * 2 +
              ((data['favoriteCount'] as num?)?.toInt() ?? 0) * 3 +
              ((data['commentCount'] as num?)?.toInt() ?? 0) * 2;
        }
        if (score <= 0) continue;
        scores.update(authorId, (current) => current + score,
            ifAbsent: () => score);
      }

      final entries = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final cooks = <TrendingCook>[];
      for (final entry in entries.take(limit)) {
        final user = await getUser(entry.key);
        if (user != null) cooks.add(TrendingCook(user, entry.value));
      }
      return cooks;
    } catch (e) {
      AppLogger.warning('Error computing trending cooks: $e', 'UserRepository');
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

/// A cook with their summed recent-recipe engagement score, used by the
/// "Trending Cooks" leaderboard section.
class TrendingCook {
  const TrendingCook(this.user, this.score);

  final UserModel user;

  /// Summed trending score (or raw engagement fallback) across recipes.
  final int score;
}
