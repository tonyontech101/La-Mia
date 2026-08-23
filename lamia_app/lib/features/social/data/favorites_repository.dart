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
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(recipeId);

    final favDoc = await favRef.get();
    final isCurrentlySaved = favDoc.exists;

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);

    if (isCurrentlySaved) {
      // Unsave
      batch.delete(favRef);
      // NOTE: recipe.favoriteCount is server-authoritative and blocked by
      // Firestore rules. Only update the user's own savedCount.
      batch.set(
        userRef,
        {'savedCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    } else {
      // Save
      batch.set(favRef, {
        'recipeId': recipeId,
        'savedAt': FieldValue.serverTimestamp(),
      });
      // NOTE: recipe.favoriteCount is server-authoritative; skip client update.
      batch.set(
        userRef,
        {'savedCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
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
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(recipeId)
        .get();
    return doc.exists;
  }

  /// Returns the IDs of all recipes saved by [userId].
  Future<List<String>> getSavedRecipeIds(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved')
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
