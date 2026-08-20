import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import 'comment_model.dart';

/// Repository for handling recipe comments against Firestore.
class CommentRepository {
  CommentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _commentsRef(String recipeId) =>
      _firestore.collection('recipes').doc(recipeId).collection('comments');

  /// Real-time stream of comments for a given recipe, sorted by newest first.
  Stream<List<CommentModel>> getCommentsStream(String recipeId) {
    return _commentsRef(recipeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) {
            try {
              return CommentModel.fromFirestore(doc, recipeId: recipeId);
            } catch (e) {
              AppLogger.warning(
                'Failed to parse comment doc ${doc.id}: $e',
                'CommentRepository',
              );
              return null;
            }
          })
          .whereType<CommentModel>()
          .toList();
    });
  }

  /// Adds a new comment to a recipe's comments subcollection.
  Future<void> addComment({
    required String recipeId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final comment = CommentModel(
      id: '',
      recipeId: recipeId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: cleanText,
      createdAt: DateTime.now(),
    );

    await _commentsRef(recipeId).add(comment.toFirestore());
  }

  /// Deletes a comment by ID.
  Future<void> deleteComment({
    required String recipeId,
    required String commentId,
  }) async {
    await _commentsRef(recipeId).doc(commentId).delete();
  }

  /// Toggles like for a specific comment by [userId].
  Future<void> toggleCommentLike({
    required String recipeId,
    required String commentId,
    required String userId,
  }) async {
    final docRef = _commentsRef(recipeId).doc(commentId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final likedBy = List<String>.from(snap.data()!['likedBy'] as List? ?? []);
    if (likedBy.contains(userId)) {
      await docRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }
}
