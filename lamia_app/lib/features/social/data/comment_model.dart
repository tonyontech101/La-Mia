import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a comment on a recipe.
class CommentModel {
  const CommentModel({
    required this.id,
    required this.recipeId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likedBy = const [],
  });

  final String id;
  final String recipeId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final List<String> likedBy;

  int get likeCount => likedBy.length;

  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory CommentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String recipeId,
  }) {
    final data = doc.data() ?? {};
    return CommentModel(
      id: doc.id,
      recipeId: recipeId,
      userId: data['userId'] as String? ?? '',
      userName: (data['userName'] as String?)?.trim().isNotEmpty == true
          ? data['userName'] as String
          : 'Foodie',
      userPhotoUrl: data['userPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: () {
        final raw = data['createdAt'];
        if (raw is Timestamp) return raw.toDate();
        if (raw is DateTime) return raw;
        if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
        return DateTime.now();
      }(),
      likedBy: (data['likedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likedBy': likedBy,
    };
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }
}
