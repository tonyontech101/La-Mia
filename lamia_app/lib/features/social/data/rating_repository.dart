import 'package:cloud_firestore/cloud_firestore.dart';

class RatingRepository {
  RatingRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Gets the rating a specific user gave to a recipe. Returns null if not rated yet.
  Future<int?> getUserRating({
    required String recipeId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore
          .collection('ratings')
          .doc(recipeId)
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['rating'] as int?;
      }
    } catch (_) {
      // Return null on failure
    }
    return null;
  }

  /// Submits a rating for a recipe and updates the average and count on the recipe document.
  Future<void> submitRating({
    required String recipeId,
    required String userId,
    required int rating,
  }) async {
    final ratingRef = _firestore
        .collection('ratings')
        .doc(recipeId)
        .collection('users')
        .doc(userId);

    final recipeRef = _firestore.collection('recipes').doc(recipeId);

    await _firestore.runTransaction((transaction) async {
      final recipeSnapshot = await transaction.get(recipeRef);
      if (!recipeSnapshot.exists) {
        throw Exception('Recipe does not exist');
      }

      final ratingSnapshot = await transaction.get(ratingRef);
      final hasRated = ratingSnapshot.exists;
      final int oldRating = hasRated ? (ratingSnapshot.data()!['rating'] as int) : 0;

      final data = recipeSnapshot.data()!;
      double ratingAvg = (data['ratingAvg'] as num?)?.toDouble() ?? 0.0;
      int ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

      if (hasRated) {
        // Update existing rating: adjust the average rating with new value
        final totalScore = (ratingAvg * ratingCount) - oldRating + rating;
        ratingAvg = ratingCount > 0 ? totalScore / ratingCount : rating.toDouble();
      } else {
        // New rating: increment count and adjust average
        final totalScore = (ratingAvg * ratingCount) + rating;
        ratingCount += 1;
        ratingAvg = totalScore / ratingCount;
      }

      transaction.set(
        ratingRef,
        {
          'rating': rating,
          'ratedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.update(recipeRef, {
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
      });
    });
  }
}
