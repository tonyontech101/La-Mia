import 'package:cloud_firestore/cloud_firestore.dart';

import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../notifications/data/notification_model.dart';
import '../../notifications/data/notification_repository.dart';

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
    NotificationRepository? notificationRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _recipeRepository = recipeRepository ?? RecipeRepository(),
       _notifRepo = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final RecipeRepository _recipeRepository;
  final NotificationRepository _notifRepo;

  /// Toggles the like state for [recipeId] by the current [userId].
  ///
  /// Returns `true` if the recipe is now liked, `false` if unliked.
  /// Updates `recipes/{recipeId}.likeCount` and the recipe author's
  /// `users/{authorId}.totalLikesReceived` in a batch write.
  Future<bool> toggleLike({
    required String recipeId,
    required String userId,
    String? recipeAuthorId,
    String? senderName,
    String? senderPhotoUrl,
    String? recipeTitle,
  }) async {
    final likeRef = _firestore
        .collection('likes')
        .doc(recipeId)
        .collection('users')
        .doc(userId);

    final userLikeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .doc(recipeId);

    final likeDoc = await likeRef.get();
    final isCurrentlyLiked = likeDoc.exists;

    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final batch = _firestore.batch();

    if (isCurrentlyLiked) {
      // Unlike
      batch.delete(likeRef);
      batch.delete(userLikeRef);
      batch.update(recipeRef, {'likeCount': FieldValue.increment(-1)});
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
      final now = FieldValue.serverTimestamp();
      batch.set(likeRef, {'likedAt': now});
      batch.set(userLikeRef, {
        'recipeId': recipeId,
        'likedAt': now,
      });
      batch.update(recipeRef, {'likeCount': FieldValue.increment(1)});
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

    // Send social notification on like (after successful commit)
    if (!isCurrentlyLiked && recipeAuthorId != null && recipeAuthorId != userId) {
      final name = (senderName != null && senderName.isNotEmpty) ? senderName : 'A foodie';
      final title = recipeTitle ?? 'your recipe';
      try {
        await _notifRepo.sendNotification(
          recipientId: recipeAuthorId,
          type: NotificationType.recipeLike,
          title: 'New Recipe Like',
          body: '$name liked "$title".',
          senderId: userId,
          senderName: name,
          senderPhotoUrl: senderPhotoUrl,
          targetId: recipeId,
          targetType: TargetType.recipe,
        );
      } catch (_) {}
    }

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
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .orderBy('likedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Returns the full recipe objects for all recipes liked by [userId].
  Future<List<RecipeModel>> getLikedRecipes(String userId) async {
    final ids = await getLikedRecipeIds(userId);
    if (ids.isEmpty) return [];
    return _recipeRepository.recipesByIds(ids);
  }
}
