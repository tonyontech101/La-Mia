/// Data model for a Filipino recipe.
///
/// Maps between the local `.txt` JSON files, Dart objects, and Firestore
/// documents. Used by both the seed script and the app's recipe feature.
class RecipeModel {
  RecipeModel({
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
    this.createdAt,
  });

  final String name;
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
    );
  }

  /// Creates a [RecipeModel] from a Firestore document snapshot.
  ///
  /// `ingredients` may be stored as objects ({display, ingredient_id, ...});
  /// they are projected to their `display` string for display purposes.
  factory RecipeModel.fromFirestore(Map<String, dynamic> data) {
    return RecipeModel(
      name: data['name'] as String,
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
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  /// Converts this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
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
      'createdAt': createdAt ?? DateTime.now(),
    };
  }
}
