import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_model.dart';

/// Reads recipe data from Cloud Firestore.
///
/// Provides methods for featured, popular, category-filtered, and
/// search-based recipe queries. Each method limits its result set via
/// Firestore `limit()`; cursor-based pagination is not yet implemented —
/// see the build order in `La Mia - Architecture (Flutter + Firebase).md` §9.
class RecipeRepository {
  RecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fetches recipes flagged as featured by editors/seed data.
  ///
  /// Queries `isFeatured == true` and returns up to [limit] recipes,
  /// sorted in-memory by `trendingScore` descending (Firestore cannot
  /// combine an equality filter with an `orderBy` on a different field
  /// without a composite index; we keep the query simple here).
  Future<List<RecipeModel>> featuredRecipes({int limit = 6}) async {
    final snap = await _firestore
        .collection('recipes')
        .where('isFeatured', isEqualTo: true)
        .get();
    final docs = snap.docs.toList();
    docs.sort((a, b) {
      final aScore = (a.data()['trendingScore'] as num?)?.toInt() ?? 0;
      final bScore = (b.data()['trendingScore'] as num?)?.toInt() ?? 0;
      return bScore.compareTo(aScore);
    });
    return docs.take(limit).map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Fetches the most popular recipes by trending score.
  ///
  /// Ranked by [trendingScore] descending via Firestore `orderBy` —
  /// includes both featured and non-featured recipes. Returns a different
  /// set than [featuredRecipes] because it is not filtered by [isFeatured].
  Future<List<RecipeModel>> popularChoices({int limit = 6}) async {
    final snap = await _firestore
        .collection('recipes')
        .orderBy('trendingScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Fetches a slice of the recipe collection, ordered by trending score.
  ///
  /// Returns up to [limit] recipes. Used today by the "Cook by Ingredients"
  /// and "Ano Pong Ulam?" screens to load a dataset for in-memory filtering.
  /// Note: per architecture doc §7 this over-fetch pattern should be
  /// replaced with cursor pagination + server-side filtering once the
  /// matching Cloud Function ships.
  Future<List<RecipeModel>> allRecipes({int limit = 200}) async {
    final snap = await _firestore
        .collection('recipes')
        .orderBy('trendingScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Returns recipes matching [category] (exact match on the Firestore
  /// `category` field), ordered by `createdAt` descending, up to [limit].
  ///
  /// Cursor pagination is not yet implemented.
  Future<List<RecipeModel>> recipesByCategory(
    String category, {
    int limit = 20,
  }) async {
    final snap = await _firestore
        .collection('recipes')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Prefix search by recipe name via a Firestore range query on the
  /// (lowercase-normalized) `name` field. Returns up to [limit] documents.
  ///
  /// Full-text search is deferred to Algolia/Typesense (architecture §7);
  /// until then this prefix match is the best Firestore can do.
  Future<List<RecipeModel>> searchRecipes(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Firestore range query: name >= "query" AND name < "query\uffff".
    final snap = await _firestore
        .collection('recipes')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThan: '$q\uffff')
        .orderBy('name')
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }
}
