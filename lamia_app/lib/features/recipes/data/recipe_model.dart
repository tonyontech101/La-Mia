/// Data model for a Filipino recipe.
///
/// Maps between the local `.txt` JSON files, Dart objects, and Firestore
/// documents. Used by both the seed script and the app's recipe feature.
class RecipeModel {
  RecipeModel({
    this.id,
    required this.name,
    required this.category,
    required this.region,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.instructions,
    required this.tags,
    required this.coverPhotoUrl,
    required this.source,
    this.description = '',
    this.authorId,
    this.authorName = 'La Mia',
    this.authorPhotoUrl,
    this.isSystemRecipe = true,
    this.likeCount = 0,
    this.commentCount = 0,
    this.favoriteCount = 0,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.status = 'approved',
    this.createdAt,
  });

  /// Firestore document ID — needed to reference recipes for likes/saves.
  final String? id;

  final String name;
  final String description;
  final String category;
  final String region;
  final String prepTime;
  final String cookTime;
  final int servings;
  final String difficulty;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String coverPhotoUrl;
  final String source;

  // ── Authorship ──────────────────────────────────────────────────────────

  /// `null` for system-seeded recipes, real UID for user-submitted ones.
  final String? authorId;

  /// `"La Mia"` for system recipes, user's display name otherwise.
  final String authorName;

  /// Author's profile picture URL.
  final String? authorPhotoUrl;

  /// `true` for curated/seeded recipes, `false` for user-submitted ones.
  final bool isSystemRecipe;

  // ── Social counters (denormalized, updated by batch writes) ─────────────

  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final double ratingAvg;
  final int ratingCount;

  // ── Moderation ──────────────────────────────────────────────────────────

  /// `"approved"` | `"pending"` | `"rejected"` | `"hidden"`.
  final String status;

  final DateTime? createdAt;

  /// Creates a [RecipeModel] from the JSON stored in recipe `.txt` files.
  ///
  /// [coverPhotoUrl] must be supplied separately (from Firebase Storage)
  /// because the local JSON only contains the filename
  /// (e.g. `"chicken-adobo.jpg"`).
  factory RecipeModel.fromLocalJson(
    Map<String, dynamic> json, {
    required String coverPhotoUrl,
  }) {
    return RecipeModel(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      region: json['region'] as String? ?? 'Unknown',
      prepTime: json['prep_time'] as String,
      cookTime: json['cook_time'] as String,
      servings: json['servings'] as int,
      difficulty: json['difficulty'] as String,
      ingredients: List<String>.from(json['ingredients'] as List),
      instructions: List<String>.from(json['instructions'] as List),
      tags: List<String>.from(json['tags'] as List),
      coverPhotoUrl: coverPhotoUrl,
      source: json['source'] as String? ?? '',
      // Local JSON recipes are always system-seeded.
      isSystemRecipe: true,
      authorId: null,
      authorName: 'La Mia',
    );
  }

  /// Creates a [RecipeModel] from a Firestore document snapshot.
  ///
  /// [docId] is the Firestore document ID, required for like/save/favorite
  /// operations that reference the recipe by ID.
  ///
  /// `ingredients` may be stored as objects ({display, ingredient_id, ...});
  /// they are projected to their `display` string for display purposes.
  factory RecipeModel.fromFirestore(
    Map<String, dynamic> data, {
    required String docId,
  }) {
    return RecipeModel(
      id: docId,
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      category: data['category'] as String,
      region: data['region'] as String? ?? 'Unknown',
      prepTime: data['prepTime'] as String,
      cookTime: data['cookTime'] as String,
      servings: data['servings'] as int,
      difficulty: data['difficulty'] as String,
      ingredients: (data['ingredients'] as List<dynamic>)
          .map(
            (e) => e is String
                ? e
                : (e as Map<String, dynamic>)['display'] as String? ??
                      e.toString(),
          )
          .toList(),
      instructions: List<String>.from(data['instructions'] as List),
      tags: List<String>.from(data['tags'] as List),
      coverPhotoUrl: data['coverPhotoUrl'] as String? ?? '',
      source: data['source'] as String? ?? '',
      authorId: data['authorId'] as String?,
      authorName: data['authorName'] as String? ?? 'La Mia',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      isSystemRecipe: data['isSystemRecipe'] as bool? ?? true,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'approved',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  /// Converts this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'region': region,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'difficulty': difficulty,
      'ingredients': ingredients,
      'instructions': instructions,
      'tags': tags,
      'coverPhotoUrl': coverPhotoUrl,
      'source': source,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'isSystemRecipe': isSystemRecipe,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'status': status,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }
}
