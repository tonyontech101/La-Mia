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
    this.featuredAchievementId,
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
  final String? featuredAchievementId;
  final DateTime createdAt;

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'] as String
          : 'User',
      bio: data['bio'] as String?,
      photoUrl: data['photoUrl'] as String?,
      recipeCount: (data['recipeCount'] as num?)?.toInt() ?? 0,
      totalLikesReceived: (data['totalLikesReceived'] as num?)?.toInt() ?? 0,
      followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
      followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
      role: data['role'] as String? ?? 'user',
      featuredAchievementId: data['featuredAchievementId'] as String?,
      createdAt: () {
        final raw = data['createdAt'];
        if (raw is Timestamp) return raw.toDate();
        if (raw is DateTime) return raw;
        if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
        return DateTime.now();
      }(),
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
      'featuredAchievementId': featuredAchievementId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? bio,
    String? photoUrl,
    int? recipeCount,
    int? totalLikesReceived,
    int? followerCount,
    int? followingCount,
    int? savedCount,
    String? role,
    String? featuredAchievementId,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      recipeCount: recipeCount ?? this.recipeCount,
      totalLikesReceived: totalLikesReceived ?? this.totalLikesReceived,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      savedCount: savedCount ?? this.savedCount,
      role: role ?? this.role,
      featuredAchievementId:
          featuredAchievementId ?? this.featuredAchievementId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
