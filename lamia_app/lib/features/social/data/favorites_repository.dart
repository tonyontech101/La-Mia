import 'package:cloud_firestore/cloud_firestore.dart';

import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';

/// Manages recipe saves (favorites) using the
/// `favorites/{userId}/items/{recipeId}` subcollection pattern from the
/// architecture doc.
///
/// Existence of a document means the user saved the recipe.
class FavoritesRepository {
  FavoritesRepository({
    FirebaseFirestore? firestore,
    RecipeRepository? recipeRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _recipeRepository = recipeRepository ?? RecipeRepository();

  final FirebaseFirestore _firestore;
  final RecipeRepository _recipeRepository;

  /// Toggles the saved state for [recipeId] by the current [userId].
  ///
  /// Returns `true` if the recipe is now saved, `false` if unsaved.
  /// Updates `recipes/{recipeId}.favoriteCount` and
  /// `users/{userId}.savedCount` in a batch write.
  Future<bool> toggleSave({
    required String recipeId,
    required String userId,
  }) async {
    final favRef = _firestore
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .doc(recipeId);

    final favDoc = await favRef.get();
    final isCurrentlySaved = favDoc.exists;

    final batch = _firestore.batch();
    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final userRef = _firestore.collection('users').doc(userId);

    if (isCurrentlySaved) {
      // Unsave
      batch.delete(favRef);
      batch.update(recipeRef, {'favoriteCount': FieldValue.increment(-1)});
      batch.update(userRef, {'savedCount': FieldValue.increment(-1)});
    } else {
      // Save
      batch.set(favRef, {
        'recipeId': recipeId,
        'savedAt': FieldValue.serverTimestamp(),
      });
      batch.update(recipeRef, {'favoriteCount': FieldValue.increment(1)});
      batch.update(userRef, {'savedCount': FieldValue.increment(1)});
    }

    await batch.commit();
    return !isCurrentlySaved;
  }

  /// Checks whether [userId] has saved [recipeId].
  Future<bool> isSaved({
    required String recipeId,
    required String userId,
  }) async {
    final doc = await _firestore
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .doc(recipeId)
        .get();
    return doc.exists;
  }

  /// Returns the IDs of all recipes saved by [userId].
  Future<List<String>> getSavedRecipeIds(String userId) async {
    final snap = await _firestore
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .orderBy('savedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Returns the full recipe objects for all recipes saved by [userId].
  Future<List<RecipeModel>> getSavedRecipes(String userId) async {
    final ids = await getSavedRecipeIds(userId);
    if (ids.isEmpty) return [];
    return _recipeRepository.recipesByIds(ids);
  }
}
