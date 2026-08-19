import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe_model.dart';

/// Reads recipe data from Cloud Firestore.
///
/// Provides methods for featured, popular, category-filtered, author-filtered,
/// and search-based recipe queries. Each method limits its result set via
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
    return docs
        .take(limit)
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
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
    return snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
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
    return snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
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
    return snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
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
    return snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
  }

  // ── User-centric queries ────────────────────────────────────────────────

  /// Returns recipes authored by [authorId], ordered by creation date.
  Future<List<RecipeModel>> recipesByAuthor(
    String authorId, {
    int limit = 50,
  }) async {
    final snap = await _firestore
        .collection('recipes')
        .where('authorId', isEqualTo: authorId)
        .get();
    final recipes = snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .toList();
    recipes.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return recipes.take(limit).toList();
  }

  /// Batch-fetches recipes by their document IDs.
  ///
  /// Firestore `whereIn` caps at 30 elements, so this method chunks
  /// the list and merges results. Used for liked/saved recipe lists.
  Future<List<RecipeModel>> recipesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <RecipeModel>[];
    // Firestore whereIn supports max 30 values per query.
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _firestore
          .collection('recipes')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(
        snap.docs.map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id)),
      );
    }
    return results;
  }

  /// Returns recipes from the given [authorIds] — used for the "Following"
  /// feed tab. Ordered by `createdAt` descending.
  ///
  /// Firestore `whereIn` caps at 30 elements; this chunks the list.
  Future<List<RecipeModel>> recipesFromFollowing(
    List<String> authorIds, {
    int limit = 30,
  }) async {
    if (authorIds.isEmpty) return [];
    final results = <RecipeModel>[];
    for (var i = 0; i < authorIds.length; i += 30) {
      final chunk = authorIds.sublist(
        i,
        i + 30 > authorIds.length ? authorIds.length : i + 30,
      );
      final snap = await _firestore
          .collection('recipes')
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      results.addAll(
        snap.docs.map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id)),
      );
    }
    // Sort merged results by createdAt descending and cap at limit.
    results.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return results.take(limit).toList();
  }

  /// Adds a new user-submitted recipe to Firestore.
  /// Returns the newly created document ID.
  Future<String> addRecipe(RecipeModel recipe) async {
    final ref = await _firestore
        .collection('recipes')
        .add(recipe.toFirestoreForCreate());
    return ref.id;
  }
}
