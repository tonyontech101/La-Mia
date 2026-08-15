import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a La Mia user profile stored in the `users` collection.
///
/// A user document is automatically created when someone signs up or signs in
/// with Google for the first time.
class UserModel {
  UserModel({
    required this.uid,
    required this.displayName,
    this.bio,
    this.photoUrl,
    this.recipeCount = 0,
    this.totalLikesReceived = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.savedCount = 0,
    this.role = 'user',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String uid;
  final String displayName;
  final String? bio;
  final String? photoUrl;
  final int recipeCount;
  final int totalLikesReceived;
  final int followerCount;
  final int followingCount;
  final int savedCount;
  final String role; // "user" | "trusted" | "admin"
  final DateTime createdAt;

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'User',
      bio: data['bio'] as String?,
      photoUrl: data['photoUrl'] as String?,
      recipeCount: data['recipeCount'] as int? ?? 0,
      totalLikesReceived: data['totalLikesReceived'] as int? ?? 0,
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      savedCount: data['savedCount'] as int? ?? 0,
      role: data['role'] as String? ?? 'user',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Converts this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'bio': bio,
      'photoUrl': photoUrl,
      'recipeCount': recipeCount,
      'totalLikesReceived': totalLikesReceived,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'savedCount': savedCount,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
