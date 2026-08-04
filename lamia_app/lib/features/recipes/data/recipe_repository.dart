import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_model.dart';

/// Reads recipe data from Cloud Firestore.
///
/// Provides methods for featured, popular, category-filtered, and
/// search-based recipe queries with cursor-based pagination support.
class RecipeRepository {
  RecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fetches recipes flagged as featured by editors/seed data.
  ///
  /// Queries `isFeatured == true`, ordered by [trendingScore] descending.
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
  /// Ranked by [trendingScore] descending — includes both featured and
  /// non-featured recipes. Returns a different set than [featuredRecipes]
  /// because it is not filtered by [isFeatured].
  Future<List<RecipeModel>> popularChoices({int limit = 6}) async {
    final snap = await _firestore
        .collection('recipes')
        .orderBy('trendingScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Fetches the full recipe collection for offline, in-memory filtering.
  ///
  /// Returns up to [limit] recipes ordered by [trendingScore] descending. Used
  /// by the "Ano Pong Ulam?" screen to load the whole dataset once and then
  /// filter it locally in Dart, so no re-query is needed per Apply.
  Future<List<RecipeModel>> allRecipes({int limit = 200}) async {
    final snap = await _firestore
        .collection('recipes')
        .orderBy('trendingScore', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => RecipeModel.fromFirestore(d.data())).toList();
  }

  /// Returns recipes matching [category] (case-insensitive match on the
  /// Firestore `category` field).
  ///
  /// Supports cursor-based pagination via [startAfter]. Pass the last
  /// [DocumentSnapshot] from a previous page to fetch the next page.
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

  /// Full-text-ish search by recipe name (prefix match via `>=` + `<`).
  ///
  /// Firestore does not support native full-text search, so this uses
  /// a range query on the lowercase `name` field. Results are limited
  /// to [limit] documents.
  Future<List<RecipeModel>> searchRecipes(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Firestore range query: name >= "query" AND name < "query\uffff"
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
