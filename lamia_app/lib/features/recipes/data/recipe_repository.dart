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

  /// Watches a recipe document so counters such as [RecipeModel.likeCount]
  /// remain current anywhere a recipe is already open on screen.
  Stream<RecipeModel?> watchRecipe(String recipeId) {
    return _firestore.collection('recipes').doc(recipeId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return RecipeModel.fromFirestore(doc.data()!, docId: doc.id);
    });
  }

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
        .limit(limit * 2)
        .get();
    return snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .where((r) => r.status == 'approved' || r.isSystemRecipe)
        .take(limit)
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
        .where((r) => r.status == 'approved' || r.isSystemRecipe)
        .toList();
  }

  /// Returns visible recipes assigned to [category].
  ///
  /// The [category] param may be either a category ID (e.g. `'lamang_dagat'`)
  /// or a category display name (e.g. `'Lamang Dagat'`). The method normalizes
  /// both sides before comparing. This also supports legacy English category
  /// labels, so a dish saved as `Breakfast` is included under `Almusal`.
  Future<List<RecipeModel>> recipesByCategory(
    String category, {
    int limit = 20,
  }) async {
    final target = _canonicalCategory(category);

    // Fetch a larger set (no server-side category filter to support both the
    // current Filipino labels and legacy labels without an index migration).
    final snap = await _firestore.collection('recipes').limit(500).get();
    final recipes = snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .where((r) {
          return isVisibleInCategory(r, target);
        })
        .toList();

    // Sort by createdAt descending (newest first), system recipes (no date) last.
    recipes.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return recipes.take(limit).toList();
  }

  /// Whether a recipe is visible and belongs to [category]. Kept public so
  /// dashboard sections can immediately reuse recipes they have already loaded.
  static bool isVisibleInCategory(RecipeModel recipe, String category) {
    final isVisible = recipe.status == 'approved' || recipe.isSystemRecipe;
    return isVisible &&
        _canonicalCategory(recipe.category) == _canonicalCategory(category);
  }

  /// Maps current IDs, Filipino display labels, and legacy English labels to
  /// the category users see in the dashboard.
  static String _canonicalCategory(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

    const aliases = <String, String>{
      'breakfast': 'almusal',
      'almusal': 'almusal',
      'main course': 'ulam',
      'lunch': 'ulam',
      'dinner': 'ulam',
      'chicken': 'ulam',
      'pork': 'ulam',
      'beef': 'ulam',
      'ulam': 'ulam',
      'soup': 'sabaw',
      'soups': 'sabaw',
      'sabaw': 'sabaw',
      'snack': 'merienda',
      'snacks': 'merienda',
      'merienda': 'merienda',
      'dessert': 'panghimagas',
      'desserts': 'panghimagas',
      'panghimagas': 'panghimagas',
      'vegetable': 'gulay',
      'vegetables': 'gulay',
      'gulay': 'gulay',
      'grilled': 'inihaw',
      'inihaw': 'inihaw',
      'seafood': 'lamang dagat',
      'lamang dagat': 'lamang dagat',
    };
    if (aliases.containsKey(normalized)) return aliases[normalized]!;

    // Some of the imported dataset uses longer category labels, e.g.
    // "Filipino Main Dishes". Treat those as the same categories shown in
    // the dashboard rather than leaving their category chip empty.
    if (normalized.contains('breakfast')) return 'almusal';
    if (normalized.contains('soup') || normalized.contains('broth')) {
      return 'sabaw';
    }
    if (normalized.contains('dessert') || normalized.contains('sweet')) {
      return 'panghimagas';
    }
    if (normalized.contains('snack') || normalized.contains('pastry')) {
      return 'merienda';
    }
    if (normalized.contains('vegetable')) return 'gulay';
    if (normalized.contains('seafood') || normalized.contains('fish')) {
      return 'lamang dagat';
    }
    if (normalized.contains('grill') || normalized.contains('barbecue')) {
      return 'inihaw';
    }
    if (normalized.contains('main') ||
        normalized.contains('dish') ||
        normalized.contains('meat')) {
      return 'ulam';
    }
    return normalized;
  }

  /// Search recipes by query. Searches across name, category, tags,
  /// ingredients, region, and description with case-insensitive matching.
  Future<List<RecipeModel>> searchRecipes(
    String query, {
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final all = await allRecipes(limit: 100);
      return all.where((r) {
        final nameMatch = r.name.toLowerCase().contains(q);
        final catMatch = r.category.toLowerCase().contains(q);
        final tagMatch = r.tags.any((t) => t.toLowerCase().contains(q));
        final regionMatch = r.region.toLowerCase().contains(q);
        final ingMatch = r.ingredients.any(
          (i) => i.toLowerCase().contains(q),
        );
        final descMatch = r.description.toLowerCase().contains(q);
        final authorMatch = r.authorName.toLowerCase().contains(q);
        return nameMatch ||
            catMatch ||
            tagMatch ||
            regionMatch ||
            ingMatch ||
            descMatch ||
            authorMatch;
      }).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  // ── User-centric queries ────────────────────────────────────────────────

  /// Returns recipes authored by [authorId], ordered by creation date.
  ///
  /// When [includePending] is `true` (for the user's own profile), recipes
  /// with any status are returned so the author can see their submissions
  /// including those still in the moderation queue.
  Future<List<RecipeModel>> recipesByAuthor(
    String authorId, {
    int limit = 50,
    bool includePending = false,
  }) async {
    final snap = await _firestore
        .collection('recipes')
        .where('authorId', isEqualTo: authorId)
        .get();
    final recipes = snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .where(
          (r) =>
              includePending ||
              r.status == 'approved' ||
              r.isSystemRecipe,
        )
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
  /// Uses individual document reads (rather than a whereIn collection query)
  /// because Firestore security rules evaluate collection-level queries
  /// against ALL docs — silently omitting any document the caller cannot read
  /// (e.g. pending recipes authored by others). Individual doc.get() calls
  /// resolve per-document read access correctly, so liked/saved recipes
  /// always appear regardless of their status.
  ///
  /// Preserves the original ordering of [ids].
  Future<List<RecipeModel>> recipesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Fetch all docs concurrently in chunks of 30 to avoid overloading
    // the connection pool while still being fast.
    final results = <RecipeModel?>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final chunkResults = await Future.wait(
        chunk.map((docId) async {
          try {
            final doc = await _firestore.collection('recipes').doc(docId).get();
            if (!doc.exists || doc.data() == null) return null;
            final model = RecipeModel.fromFirestore(doc.data()!, docId: doc.id);
            if (model.status == 'rejected') return null;
            return model;
          } catch (_) {
            return null;
          }
        }),
      );
      results.addAll(chunkResults);
    }
    // Preserve the original ordering of [ids], filtering out any nulls
    // (recipes that don't exist or were rejected).
    return results.whereType<RecipeModel>().toList();
  }

  /// Returns recipes from the given [authorIds] — used for the "Following"
  /// feed tab.
  ///
  /// Firestore `whereIn` caps at 30 elements; this chunks the list.
  /// No Firestore `orderBy` to avoid requiring a composite index on
  /// `(authorId, createdAt)` — sorting is done in memory.
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
          .get();
      results.addAll(
        snap.docs
            .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
            .where((r) => r.status == 'approved' || r.isSystemRecipe),
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

  /// Returns all approved user-submitted recipes created in the current
  /// calendar month.
  ///
  /// Used by the leaderboard to compute "Chef of the Month" — the author
  /// whose recipes received the most combined likes + favorites this month.
  ///
  /// Filters in-memory to avoid Firestore composite index requirements
  /// and to handle recipes where `createdAt` may be null or missing.
  Future<List<RecipeModel>> recipesCreatedThisMonth({int limit = 500}) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

    final snap = await _firestore
        .collection('recipes')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .limit(limit)
        .get();
    final monthRecipes = snap.docs
        .map((d) => RecipeModel.fromFirestore(d.data(), docId: d.id))
        .where((r) {
          // Only user-submitted recipes (not system/seeded) count for
          // Chef of the Month.
          if (r.authorId == null || r.isSystemRecipe) return false;
          return r.createdAt != null;
        })
        .toList();
    // Popularity is live: Cloud Functions update trendingScore as engagement
    // changes. Fall back to likes/favorites for legacy recipes without it.
    monthRecipes.sort((a, b) {
      final aPopularity = a.trendingScore > 0
          ? a.trendingScore
          : a.likeCount + a.favoriteCount;
      final bPopularity = b.trendingScore > 0
          ? b.trendingScore
          : b.likeCount + b.favoriteCount;
      if (bPopularity != aPopularity) {
        return bPopularity.compareTo(aPopularity);
      }
      return (b.createdAt ?? DateTime(2000)).compareTo(
        a.createdAt ?? DateTime(2000),
      );
    });
    return monthRecipes.take(limit).toList();
  }

  /// Fetches a single recipe by its document ID.
  Future<RecipeModel?> getRecipe(String recipeId) async {
    try {
      final doc = await _firestore.collection('recipes').doc(recipeId).get();
      if (!doc.exists || doc.data() == null) return null;
      return RecipeModel.fromFirestore(doc.data()!, docId: doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Adds a new user-submitted recipe to Firestore.
  /// Returns the newly created document ID.
  Future<String> addRecipe(RecipeModel recipe) async {
    final ref = await _firestore
        .collection('recipes')
        .add(recipe.toFirestoreForCreate());
    return ref.id;
  }

  /// Updates an existing recipe in Firestore.
  Future<void> updateRecipe(String recipeId, RecipeModel recipe) async {
    await _firestore
        .collection('recipes')
        .doc(recipeId)
        .update(recipe.toFirestore());
  }

  /// Deletes a recipe from Firestore.
  Future<void> deleteRecipe(String recipeId) async {
    await _firestore.collection('recipes').doc(recipeId).delete();
  }
}
