import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  recipeLike,
  recipeComment,
  commentLike,
  commentReply,
  newFollower,
  followingNewRecipe,
  recipeApproved,
  mealReminder,
  dailySuggestion,
  achievement,
  system;

  String get value {
    switch (this) {
      case NotificationType.recipeLike: return 'recipe_like';
      case NotificationType.recipeComment: return 'recipe_comment';
      case NotificationType.commentLike: return 'comment_like';
      case NotificationType.commentReply: return 'comment_reply';
      case NotificationType.newFollower: return 'new_follower';
      case NotificationType.followingNewRecipe: return 'following_new_recipe';
      case NotificationType.recipeApproved: return 'recipe_approved';
      case NotificationType.mealReminder: return 'meal_reminder';
      case NotificationType.dailySuggestion: return 'daily_suggestion';
      case NotificationType.achievement: return 'achievement';
      case NotificationType.system: return 'system';
    }
  }

  static NotificationType fromValue(String? val) {
    switch (val) {
      case 'recipe_like': return NotificationType.recipeLike;
      case 'recipe_comment': return NotificationType.recipeComment;
      case 'comment_like': return NotificationType.commentLike;
      case 'comment_reply': return NotificationType.commentReply;
      case 'new_follower': return NotificationType.newFollower;
      case 'following_new_recipe': return NotificationType.followingNewRecipe;
      case 'recipe_approved': return NotificationType.recipeApproved;
      case 'meal_reminder': return NotificationType.mealReminder;
      case 'daily_suggestion': return NotificationType.dailySuggestion;
      case 'achievement': return NotificationType.achievement;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
}

enum TargetType {
  recipe,
  user,
  planner,
  achievement,
  url,
  custom;

  String get value {
    switch (this) {
      case TargetType.recipe: return 'recipe';
      case TargetType.user: return 'user';
      case TargetType.planner: return 'planner';
      case TargetType.achievement: return 'achievement';
      case TargetType.url: return 'url';
      case TargetType.custom: return 'custom';
    }
  }

  static TargetType fromValue(String? val) {
    switch (val) {
      case 'recipe': return TargetType.recipe;
      case 'user': return TargetType.user;
      case 'planner': return TargetType.planner;
      case 'achievement': return TargetType.achievement;
      case 'url': return TargetType.url;
      case 'custom':
      default:
        return TargetType.custom;
    }
  }
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    required this.type,
    required this.title,
    required this.body,
    this.targetId,
    required this.targetType,
    this.targetRoute,
    this.imageUrl,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final NotificationType type;
  final String title;
  final String body;
  final String? targetId;
  final TargetType targetType;
  final String? targetRoute;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      type: NotificationType.fromValue(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      targetId: data['targetId'] as String?,
      targetType: TargetType.fromValue(data['targetType'] as String?),
      targetRoute: data['targetRoute'] as String?,
      imageUrl: data['imageUrl'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: () {
        final raw = data['createdAt'];
        if (raw is Timestamp) return raw.toDate();
        if (raw is DateTime) return raw;
        if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
        return DateTime.now();
      }(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'type': type.value,
      'title': title,
      'body': body,
      'targetId': targetId,
      'targetType': targetType.value,
      'targetRoute': targetRoute,
      'imageUrl': imageUrl,
      'metadata': metadata,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
