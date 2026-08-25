import 'package:cloud_firestore/cloud_firestore.dart';

import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';

/// Manages saved recipes and the profile index that displays them.
class FavoritesRepository {
  FavoritesRepository({
    FirebaseFirestore? firestore,
    RecipeRepository? recipeRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _recipeRepository = recipeRepository ?? RecipeRepository();

  final FirebaseFirestore _firestore;
  final RecipeRepository _recipeRepository;

  /// Toggles a saved recipe and returns its resulting state.
  ///
  /// All representations of a save are committed together, preventing stale
  /// profile entries and counter drift when a write is rejected or interrupted.
  Future<bool> toggleSave({
    required String recipeId,
    required String userId,
  }) async {
    final userSavedRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(recipeId);
    final favoriteRef = _firestore
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .doc(recipeId);

    final userSavedDoc = await userSavedRef.get();
    final isCurrentlySaved = userSavedDoc.exists ||
        (!userSavedDoc.exists && (await favoriteRef.get()).exists);

    final batch = _firestore.batch();
    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final userRef = _firestore.collection('users').doc(userId);

    if (isCurrentlySaved) {
      batch.delete(userSavedRef);
      batch.delete(favoriteRef);
      batch.update(recipeRef, {'favoriteCount': FieldValue.increment(-1)});
      batch.set(
        userRef,
        {'savedCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    } else {
      final savedAt = FieldValue.serverTimestamp();
      batch.set(userSavedRef, {'recipeId': recipeId, 'savedAt': savedAt});
      batch.set(favoriteRef, {'recipeId': recipeId, 'savedAt': savedAt});
      batch.update(recipeRef, {'favoriteCount': FieldValue.increment(1)});
      batch.set(
        userRef,
        {'savedCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return !isCurrentlySaved;
  }

  Future<bool> isSaved({
    required String recipeId,
    required String userId,
  }) async {
    final userSavedDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved')
        .doc(recipeId)
        .get();
    if (userSavedDoc.exists) return true;

    final favoriteDoc = await _firestore
        .collection('favorites')
        .doc(userId)
        .collection('items')
        .doc(recipeId)
        .get();
    return favoriteDoc.exists;
  }

  /// Returns saved recipe IDs, newest first.
  Future<List<String>> getSavedRecipeIds(String userId) async {
    final saved = await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved')
        .get();
    final recipes = saved.docs
        .map(
          (doc) => (
            id: doc.id,
            savedAt: (doc.data()['savedAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return recipes.map((recipe) => recipe.id).toList();
  }

  Future<List<RecipeModel>> getSavedRecipes(String userId) async {
    final ids = await getSavedRecipeIds(userId);
    if (ids.isEmpty) return [];
    return _recipeRepository.recipesByIds(ids);
  }
}
