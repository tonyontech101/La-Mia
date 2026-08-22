import 'package:cloud_firestore/cloud_firestore.dart';

import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';

/// Manages recipe likes using the `likes/{recipeId}/users/{userId}`
/// subcollection pattern from the architecture doc.
///
/// Existence of a document means the user liked the recipe.
/// Counter updates (`likeCount`, `totalLikesReceived`) are done
/// in a batch write for consistency.
class LikeRepository {
  LikeRepository({
    FirebaseFirestore? firestore,
    RecipeRepository? recipeRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _recipeRepository = recipeRepository ?? RecipeRepository();

  final FirebaseFirestore _firestore;
  final RecipeRepository _recipeRepository;

  /// Toggles the like state for [recipeId] by the current [userId].
  ///
  /// Returns `true` if the recipe is now liked, `false` if unliked.
  /// Updates `recipes/{recipeId}.likeCount` and the recipe author's
  /// `users/{authorId}.totalLikesReceived` in a batch write.
  Future<bool> toggleLike({
    required String recipeId,
    required String userId,
    String? recipeAuthorId,
  }) async {
    final likeRef = _firestore
        .collection('likes')
        .doc(recipeId)
        .collection('users')
        .doc(userId);

    final likeDoc = await likeRef.get();
    final isCurrentlyLiked = likeDoc.exists;

    final batch = _firestore.batch();

    if (isCurrentlyLiked) {
      // Unlike
      batch.delete(likeRef);
      // NOTE: recipe.likeCount is server-authoritative; we do NOT update it
      // from the client (blocked by Firestore rules). A Cloud Function or
      // scheduled job maintains the denormalized counter.
      if (recipeAuthorId != null) {
        final authorRef = _firestore.collection('users').doc(recipeAuthorId);
        // Use set+merge so missing counter fields don't cause NOT_FOUND.
        batch.set(
          authorRef,
          {'totalLikesReceived': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      }
    } else {
      // Like
      batch.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
      // NOTE: recipe.likeCount is server-authoritative; skip client update.
      if (recipeAuthorId != null) {
        final authorRef = _firestore.collection('users').doc(recipeAuthorId);
        batch.set(
          authorRef,
          {'totalLikesReceived': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
    return !isCurrentlyLiked;
  }

  /// Checks whether [userId] has liked [recipeId].
  Future<bool> isLiked({
    required String recipeId,
    required String userId,
  }) async {
    final doc = await _firestore
        .collection('likes')
        .doc(recipeId)
        .collection('users')
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// Returns the IDs of all recipes liked by [userId].
  Future<List<String>> getLikedRecipeIds(String userId) async {
    // Query across all likes subcollections via a collection group query.
    // This requires a Firestore index on the `users` collection group.
    // Alternative: maintain a user-level subcollection. For now we use
    // a simpler approach: query all `likes` docs and check the user subcol.
    //
    // Simpler approach: We store likes as likes/{recipeId}/users/{userId}.
    // To get all liked recipe IDs for a user, we use a collectionGroup query.
    final snap = await _firestore
        .collectionGroup('users')
        .where(FieldPath.documentId, isEqualTo: userId)
        .get();

    // Filter to only docs whose parent collection is named 'users' under 'likes'.
    final ids = <String>[];
    for (final doc in snap.docs) {
      final parentPath = doc.reference.parent.parent?.id;
      final grandparentPath = doc.reference.parent.parent?.parent.id;
      if (grandparentPath == 'likes' && parentPath != null) {
        ids.add(parentPath);
      }
    }
    return ids;
  }

  /// Returns the full recipe objects for all recipes liked by [userId].
  Future<List<RecipeModel>> getLikedRecipes(String userId) async {
    final ids = await getLikedRecipeIds(userId);
    if (ids.isEmpty) return [];
    return _recipeRepository.recipesByIds(ids);
  }
}
