import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import 'comment_model.dart';
import '../../notifications/data/notification_model.dart';
import '../../notifications/data/notification_repository.dart';

/// Repository for handling recipe comments against Firestore.
///
/// Supports top-level comments and threaded replies. Replies are nested
/// one level deep — replies cannot have replies (UI policy, not data constraint).
class CommentRepository {
  CommentRepository({
    FirebaseFirestore? firestore,
    NotificationRepository? notificationRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifRepo = notificationRepository ?? NotificationRepository();

  final FirebaseFirestore _firestore;
  final NotificationRepository _notifRepo;

  CollectionReference<Map<String, dynamic>> _commentsRef(String recipeId) =>
      _firestore.collection('recipes').doc(recipeId).collection('comments');

  /// Real-time stream of top-level comments for a given recipe, newest first.
  Stream<List<CommentModel>> getCommentsStream(String recipeId) {
    return _commentsRef(recipeId)
        .where('isReply', isEqualTo: false)
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

  /// Real-time stream of replies for a given parent comment, oldest first.
  Stream<List<CommentModel>> getRepliesStream({
    required String recipeId,
    required String parentCommentId,
  }) {
    return _commentsRef(recipeId)
        .where('parentCommentId', isEqualTo: parentCommentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) {
            try {
              return CommentModel.fromFirestore(doc, recipeId: recipeId);
            } catch (e) {
              AppLogger.warning(
                'Failed to parse reply doc ${doc.id}: $e',
                'CommentRepository',
              );
              return null;
            }
          })
          .whereType<CommentModel>()
          .toList();
    });
  }

  /// Returns the count of replies for a given parent comment.
  ///
  /// Uses Firestore aggregation for efficiency — billed as one read.
  Future<int> getReplyCount({
    required String recipeId,
    required String parentCommentId,
  }) async {
    try {
      final snapshot = await _commentsRef(recipeId)
          .where('parentCommentId', isEqualTo: parentCommentId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      AppLogger.warning(
        'Failed to get reply count for $parentCommentId: $e',
        'CommentRepository',
      );
      return 0;
    }
  }

  /// Adds a new top-level comment to a recipe's comments subcollection.
  Future<void> addComment({
    required String recipeId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    String? recipeAuthorId,
    String? recipeTitle,
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

    // Write comment and increment recipe commentCount atomically.
    final batch = _firestore.batch();
    final commentRef = _commentsRef(recipeId).doc();
    batch.set(commentRef, comment.toFirestore());
    batch.update(
      _firestore.collection('recipes').doc(recipeId),
      {'commentCount': FieldValue.increment(1)},
    );
    await batch.commit();

    // Dispatch social notification (if author is not commenter)
    if (recipeAuthorId != null && recipeAuthorId != userId) {
      final title = recipeTitle ?? 'your recipe';
      final snippet =
          cleanText.length > 50 ? '${cleanText.substring(0, 47)}...' : cleanText;
      try {
        await _notifRepo.sendNotification(
          recipientId: recipeAuthorId,
          type: NotificationType.recipeComment,
          title: 'New Comment',
          body: '$userName commented on "$title": "$snippet"',
          senderId: userId,
          senderName: userName,
          senderPhotoUrl: userPhotoUrl,
          targetId: recipeId,
          targetType: TargetType.recipe,
        );
      } catch (_) {}
    }
  }

  /// Adds a reply to an existing comment.
  ///
  /// Writes the reply doc, increments the parent's [replyCount], and sends
  /// a [NotificationType.commentReply] notification to the parent's author.
  Future<void> addReply({
    required String recipeId,
    required String parentCommentId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    required String parentCommentAuthorId,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final reply = CommentModel(
      id: '',
      recipeId: recipeId,
      userId: userId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: cleanText,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
    );

    // Write reply + increment parent replyCount atomically.
    final batch = _firestore.batch();
    final replyRef = _commentsRef(recipeId).doc();
    batch.set(replyRef, reply.toFirestore());
    batch.update(_commentsRef(recipeId).doc(parentCommentId), {
      'replyCount': FieldValue.increment(1),
    });
    await batch.commit();

    // Notify parent comment author (skip self).
    if (parentCommentAuthorId != userId) {
      final snippet =
          cleanText.length > 50 ? '${cleanText.substring(0, 47)}...' : cleanText;
      try {
        await _notifRepo.sendNotification(
          recipientId: parentCommentAuthorId,
          type: NotificationType.commentReply,
          title: 'New Reply',
          body: '$userName replied to your comment: "$snippet"',
          senderId: userId,
          senderName: userName,
          senderPhotoUrl: userPhotoUrl,
          targetId: recipeId,
          targetType: TargetType.recipe,
        );
      } catch (_) {}
    }
  }

  /// Deletes a comment by ID.
  ///
  /// For top-level comments, also cascade-deletes all replies and decrements
  /// the recipe's [commentCount] accordingly. For replies, decrements the
  /// parent's [replyCount].
  Future<void> deleteComment({
    required String recipeId,
    required String commentId,
    bool isTopLevel = true,
  }) async {
    if (isTopLevel) {
      // Cascade: delete all replies, then the comment, then decrement recipe count.
      final repliesSnap = await _commentsRef(recipeId)
          .where('parentCommentId', isEqualTo: commentId)
          .get();
      final batch = _firestore.batch();
      for (final doc in repliesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_commentsRef(recipeId).doc(commentId));
      batch.update(
        _firestore.collection('recipes').doc(recipeId),
        {'commentCount': FieldValue.increment(-(1 + repliesSnap.size))},
      );
      await batch.commit();
    } else {
      // Reply deletion: delete and decrement parent replyCount.
      final replyDoc = await _commentsRef(recipeId).doc(commentId).get();
      final parentId = replyDoc.data()?['parentCommentId'] as String?;
      final batch = _firestore.batch();
      batch.delete(_commentsRef(recipeId).doc(commentId));
      if (parentId != null) {
        batch.update(_commentsRef(recipeId).doc(parentId), {
          'replyCount': FieldValue.increment(-1),
        });
      }
      await batch.commit();
    }
  }

  /// Toggles like for a specific comment by [userId].
  ///
  /// Also fires a [NotificationType.commentLike] notification to the
  /// comment's author when a like is added (not removed).
  Future<void> toggleCommentLike({
    required String recipeId,
    required String commentId,
    required String userId,
  }) async {
    final docRef = _commentsRef(recipeId).doc(commentId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    final likedBy = List<String>.from(data['likedBy'] as List? ?? []);
    final commentAuthorId = data['userId'] as String?;

    if (likedBy.contains(userId)) {
      await docRef.update({
        'likedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likedBy': FieldValue.arrayUnion([userId]),
      });

      // Notify comment author (skip self).
      if (commentAuthorId != null && commentAuthorId != userId) {
        try {
          final userName = data['userName'] as String? ?? 'Someone';
          await _notifRepo.sendNotification(
            recipientId: commentAuthorId,
            type: NotificationType.commentLike,
            title: 'Comment Liked',
            body: '$userName liked your comment.',
            senderId: userId,
            targetId: recipeId,
            targetType: TargetType.recipe,
          );
        } catch (_) {}
      }
    }
  }
}
