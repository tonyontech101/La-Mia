import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../notifications/data/notification_model.dart';
import '../../notifications/data/notification_repository.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';

/// Manages recipe likes and the per-user index used by the profile Likes tab.
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

  /// Toggles a recipe like and returns its resulting state.
  ///
  /// The recipe lookup, profile lookup, and counters are committed together.
  /// This prevents a filled heart from appearing when the recipe was not
  /// actually added to the profile's Likes tab.
  Future<bool> toggleLike({
    required String recipeId,
    required String userId,
    String? recipeAuthorId,
    String? senderName,
    String? senderPhotoUrl,
    String? recipeTitle,
  }) async {
    final userLikeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .doc(recipeId);
    final likeRef = _firestore
        .collection('likes')
        .doc(recipeId)
        .collection('users')
        .doc(userId);

    // Prefer the profile index, but recognize likes written by older clients.
    final userLikeDoc = await userLikeRef.get();
    final isCurrentlyLiked = userLikeDoc.exists ||
        (!userLikeDoc.exists && (await likeRef.get()).exists);

    final batch = _firestore.batch();
    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final authorRef = recipeAuthorId != null &&
            recipeAuthorId.isNotEmpty &&
            recipeAuthorId != 'null'
        ? _firestore.collection('users').doc(recipeAuthorId)
        : null;

    if (isCurrentlyLiked) {
      batch.delete(userLikeRef);
      batch.delete(likeRef);
      batch.update(recipeRef, {'likeCount': FieldValue.increment(-1)});
      if (authorRef != null) {
        batch.set(
          authorRef,
          {'totalLikesReceived': FieldValue.increment(-1)},
          SetOptions(merge: true),
        );
      }
    } else {
      final now = FieldValue.serverTimestamp();
      batch.set(userLikeRef, {'recipeId': recipeId, 'likedAt': now});
      batch.set(
        likeRef,
        {'recipeId': recipeId, 'userId': userId, 'likedAt': now},
      );
      batch.update(recipeRef, {'likeCount': FieldValue.increment(1)});
      if (authorRef != null) {
        batch.set(
          authorRef,
          {'totalLikesReceived': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();

    if (!isCurrentlyLiked &&
        authorRef != null &&
        recipeAuthorId != userId) {
      final name = senderName?.isNotEmpty == true ? senderName! : 'A foodie';
      _notifRepo
          .sendNotification(
            recipientId: recipeAuthorId!,
            type: NotificationType.recipeLike,
            title: 'New Recipe Like',
            body: '$name liked "${recipeTitle ?? 'your recipe'}".',
            senderId: userId,
            senderName: name,
            senderPhotoUrl: senderPhotoUrl,
            targetId: recipeId,
            targetType: TargetType.recipe,
          )
          .catchError(
            (Object error) =>
                debugPrint('[LikeRepo] notification failed: $error'),
          );
    }

    return !isCurrentlyLiked;
  }

  Future<bool> isLiked({
    required String recipeId,
    required String userId,
  }) async {
    final userDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .doc(recipeId)
        .get();
    if (userDoc.exists) return true;

    final doc = await _firestore
        .collection('likes')
        .doc(recipeId)
        .collection('users')
        .doc(userId)
        .get();
    return doc.exists;
  }

  /// Returns liked recipe IDs, newest first.
  Future<List<String>> getLikedRecipeIds(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('likes')
        .get();
    final likes = snap.docs
        .map(
          (doc) => (
            id: doc.id,
            likedAt: (doc.data()['likedAt'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .toList()
      ..sort((a, b) => b.likedAt.compareTo(a.likedAt));
    return likes.map((like) => like.id).toList();
  }

  Future<List<RecipeModel>> getLikedRecipes(String userId) async {
    final ids = await getLikedRecipeIds(userId);
    if (ids.isEmpty) return [];
    return _recipeRepository.recipesByIds(ids);
  }
}
