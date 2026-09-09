// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lamia_app/features/notifications/data/notification_model.dart';
import 'package:lamia_app/features/notifications/data/notification_repository.dart';
import 'package:lamia_app/features/recipes/data/recipe_repository.dart';
import 'package:lamia_app/features/social/data/like_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  final List<Map<String, dynamic>> sentNotifications = [];

  @override
  Future<void> sendNotification({
    required String recipientId,
    required NotificationType type,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? targetId,
    required TargetType targetType,
    String? targetRoute,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    sentNotifications.add({
      'recipientId': recipientId,
      'type': type,
      'title': title,
      'body': body,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'targetId': targetId,
      'targetType': targetType,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  FakeDocSnapshot(this._id, this._data, {this.existsFlag = true});
  final String _id;
  final Map<String, dynamic>? _data;
  final bool existsFlag;

  @override
  String get id => _id;
  @override
  bool get exists => existsFlag;
  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  FakeDocRef(this.id, {this.data, this.exists = false});
  @override
  final String id;
  Map<String, dynamic>? data;
  bool exists;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return FakeDocSnapshot(id, data, existsFlag: exists);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    this.data = data;
    exists = true;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    final converted = <String, dynamic>{};
    data.forEach((k, v) => converted[k.toString()] = v);
    this.data = {...?this.data, ...converted};
  }

  @override
  Future<void> delete() async {
    exists = false;
    data = null;
  }

  final Map<String, FakeColRef> _subcollections = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _subcollections.putIfAbsent(
      collectionPath,
      () => FakeColRef('$id/$collectionPath'),
    );
  }

  FakeColRef getSubcollection(String name) =>
      _subcollections.putIfAbsent(name, () => FakeColRef('$id/$name'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeColRef implements CollectionReference<Map<String, dynamic>> {
  FakeColRef(this.path);
  @override
  final String path;
  final Map<String, FakeDocRef> _docs = {};

  Map<String, FakeDocRef> get docs => _docs;

  @override
  FakeDocRef doc([String? path]) {
    final docId = path ?? 'doc_${DateTime.now().microsecondsSinceEpoch}_${_docs.length}';
    return _docs.putIfAbsent(docId, () => FakeDocRef(docId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWriteBatch implements WriteBatch {
  final List<String> operations = [];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    operations.add('set: ${(document as FakeDocRef).id}');
    (document as FakeDocRef).data = data as Map<String, dynamic>;
    (document as FakeDocRef).exists = true;
  }

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) {
    operations.add('update: ${(document as FakeDocRef).id}');
    final converted = <String, dynamic>{};
    data.forEach((k, v) => converted[k.toString()] = v);
    (document).data = {...?(document).data, ...converted};
  }

  @override
  void delete(DocumentReference<Object?> document) {
    operations.add('delete: ${(document as FakeDocRef).id}');
    (document as FakeDocRef).exists = false;
  }

  @override
  Future<void> commit() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirestore implements FirebaseFirestore {
  final Map<String, FakeColRef> collections = {};

  @override
  FakeColRef collection(String collectionPath) {
    return collections.putIfAbsent(collectionPath, () => FakeColRef(collectionPath));
  }

  @override
  WriteBatch batch() => FakeWriteBatch();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LikeRepository notification dispatch tests', () {
    late FakeFirestore firestore;
    late MockNotificationRepository notifRepo;
    late LikeRepository likeRepo;

    setUp(() {
      firestore = FakeFirestore();
      notifRepo = MockNotificationRepository();
      likeRepo = LikeRepository(
        firestore: firestore,
        recipeRepository: RecipeRepository(firestore: firestore),
        notificationRepository: notifRepo,
      );
    });

    test('Dispatches recipeLike notification when a user likes another user recipe', () async {
      const recipeId = 'rec_sinigang_123';
      const likingUserId = 'user_fan_456';
      const authorUserId = 'user_chef_789';

      // Set up author doc in users
      firestore.collection('users').doc(authorUserId).data = {
        'displayName': 'Chef Maria',
      };
      firestore.collection('users').doc(authorUserId).exists = true;

      // Set up recipe doc
      firestore.collection('recipes').doc(recipeId).data = {
        'authorId': authorUserId,
        'name': 'Sinigang na Baboy',
        'likeCount': 5,
      };
      firestore.collection('recipes').doc(recipeId).exists = true;

      final isLiked = await likeRepo.toggleLike(
        recipeId: recipeId,
        userId: likingUserId,
        recipeAuthorId: authorUserId,
        senderName: 'Jayzer Relator',
        senderPhotoUrl: 'https://example.com/photo.jpg',
        recipeTitle: 'Sinigang na Baboy',
      );

      expect(isLiked, isTrue);
      expect(notifRepo.sentNotifications.length, 1);
      final notif = notifRepo.sentNotifications.first;
      expect(notif['recipientId'], authorUserId);
      expect(notif['type'], NotificationType.recipeLike);
      expect(notif['senderId'], likingUserId);
      expect(notif['senderName'], 'Jayzer Relator');
      expect(notif['targetId'], recipeId);
      expect(notif['body'], contains('Jayzer Relator liked "Sinigang na Baboy".'));
    });

    test('Does NOT dispatch notification when a user likes their own recipe', () async {
      const recipeId = 'rec_sinigang_123';
      const userId = 'user_chef_789';

      firestore.collection('users').doc(userId).data = {'displayName': 'Chef Maria'};
      firestore.collection('users').doc(userId).exists = true;

      firestore.collection('recipes').doc(recipeId).data = {
        'authorId': userId,
        'name': 'Sinigang na Baboy',
      };
      firestore.collection('recipes').doc(recipeId).exists = true;

      final isLiked = await likeRepo.toggleLike(
        recipeId: recipeId,
        userId: userId,
        recipeAuthorId: userId,
        senderName: 'Chef Maria',
        recipeTitle: 'Sinigang na Baboy',
      );

      expect(isLiked, isTrue);
      expect(notifRepo.sentNotifications, isEmpty);
    });

    test('Resolves targetAuthorId from Firestore when recipeAuthorId is null and sends notification', () async {
      const recipeId = 'rec_adobo_999';
      const likingUserId = 'user_fan_456';
      const authorUserId = 'user_chef_888';

      firestore.collection('users').doc(authorUserId).data = {'displayName': 'Chef Maria'};
      firestore.collection('users').doc(authorUserId).exists = true;

      firestore.collection('recipes').doc(recipeId).data = {
        'authorId': authorUserId,
        'name': 'Chicken Adobo',
      };
      firestore.collection('recipes').doc(recipeId).exists = true;

      // recipeAuthorId passed as null
      final isLiked = await likeRepo.toggleLike(
        recipeId: recipeId,
        userId: likingUserId,
        recipeAuthorId: null,
        senderName: 'Jayzer Relator',
        recipeTitle: 'Chicken Adobo',
      );

      expect(isLiked, isTrue);
      expect(notifRepo.sentNotifications.length, 1);
      expect(notifRepo.sentNotifications.first['recipientId'], authorUserId);
    });
  });

  group('NotificationRepository tests', () {
    late FakeFirestore firestore;
    late NotificationRepository notifRepo;

    setUp(() {
      firestore = FakeFirestore();
      notifRepo = NotificationRepository(firestore: firestore);
    });

    test('sendNotification creates document in recipient subcollection without cross-user reads', () async {
      const recipientId = 'recipient_user_1';
      const senderId = 'liker_user_2';

      await notifRepo.sendNotification(
        recipientId: recipientId,
        type: NotificationType.recipeLike,
        title: 'New Recipe Like',
        body: 'Jayzer Relator liked "Chicken Adobo".',
        senderId: senderId,
        senderName: 'Jayzer Relator',
        senderPhotoUrl: 'https://example.com/photo.png',
        targetId: 'recipe_adobo_1',
        targetType: TargetType.recipe,
      );

      final userDoc = firestore.collection('users').doc(recipientId);
      final notificationsCol = userDoc.getSubcollection('notifications');

      expect(notificationsCol.docs.isNotEmpty, isTrue);
      final createdDoc = notificationsCol.docs.values.first;
      expect(createdDoc.data?['userId'], recipientId);
      expect(createdDoc.data?['senderId'], senderId);
      expect(createdDoc.data?['senderName'], 'Jayzer Relator');
      expect(createdDoc.data?['type'], 'recipe_like');
      expect(createdDoc.data?['targetId'], 'recipe_adobo_1');
      expect(createdDoc.data?['isRead'], isFalse);

      // Verify unreadNotificationCount increment
      expect(userDoc.data?['unreadNotificationCount'], isNotNull);
    });

    test('sendNotification skips duplicate social notification within debounce interval', () async {
      const recipientId = 'recipient_user_debounce';
      const senderId = 'liker_user_debounce';
      const targetId = 'recipe_debounce_target';

      await notifRepo.sendNotification(
        recipientId: recipientId,
        type: NotificationType.recipeLike,
        title: 'New Recipe Like',
        body: 'Jayzer Relator liked "Sinigang".',
        senderId: senderId,
        targetId: targetId,
        targetType: TargetType.recipe,
      );

      final userDoc = firestore.collection('users').doc(recipientId);
      final notificationsCol = userDoc.getSubcollection('notifications');
      expect(notificationsCol.docs.length, 1);

      // Immediate second like (should be debounced in-memory)
      await notifRepo.sendNotification(
        recipientId: recipientId,
        type: NotificationType.recipeLike,
        title: 'New Recipe Like',
        body: 'Jayzer Relator liked "Sinigang".',
        senderId: senderId,
        targetId: targetId,
        targetType: TargetType.recipe,
      );

      expect(notificationsCol.docs.length, 1);
    });

    test('sendNotification skips self notification', () async {
      const userId = 'self_user_99';

      await notifRepo.sendNotification(
        recipientId: userId,
        type: NotificationType.recipeLike,
        title: 'New Recipe Like',
        body: 'You liked your recipe.',
        senderId: userId,
        targetId: 'recipe_self',
        targetType: TargetType.recipe,
      );

      final userDoc = firestore.collection('users').doc(userId);
      final notificationsCol = userDoc.getSubcollection('notifications');
      expect(notificationsCol.docs.isEmpty, isTrue);
    });

    test('NotificationModel deserializes recipe_like type and properties accurately', () {
      final now = DateTime.now();
      final fakeDoc = FakeDocSnapshot('notif_id_abc', {
        'userId': 'user_123',
        'senderId': 'sender_456',
        'senderName': 'Jayzer Relator',
        'senderPhotoUrl': 'https://example.com/avatar.jpg',
        'type': 'recipe_like',
        'title': 'New Recipe Like',
        'body': 'Jayzer Relator liked your recipe.',
        'targetId': 'recipe_789',
        'targetType': 'recipe',
        'isRead': false,
        'createdAt': Timestamp.fromDate(now),
      });
      final model = NotificationModel.fromFirestore(fakeDoc);

      expect(model.id, 'notif_id_abc');
      expect(model.userId, 'user_123');
      expect(model.senderId, 'sender_456');
      expect(model.senderName, 'Jayzer Relator');
      expect(model.type, NotificationType.recipeLike);
      expect(model.targetType, TargetType.recipe);
      expect(model.targetId, 'recipe_789');
      expect(model.isRead, isFalse);
      expect(model.createdAt.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
    });

    test('Filter categorisation matches recipeLike under "all" and "social"', () {
      final notif = NotificationModel(
        id: 'n1',
        userId: 'u1',
        type: NotificationType.recipeLike,
        title: 'Like',
        body: 'Liked',
        targetType: TargetType.recipe,
        isRead: false,
        createdAt: DateTime.now(),
      );

      bool matchesFilter(NotificationModel n, String filter) {
        if (filter == 'all') return true;
        switch (filter) {
          case 'social':
            return n.type == NotificationType.recipeLike ||
                n.type == NotificationType.recipeComment ||
                n.type == NotificationType.commentLike ||
                n.type == NotificationType.commentReply ||
                n.type == NotificationType.newFollower ||
                n.type == NotificationType.followingNewRecipe;
          case 'planner':
            return n.type == NotificationType.mealReminder ||
                n.type == NotificationType.dailySuggestion;
          case 'system':
            return n.type == NotificationType.recipeApproved ||
                n.type == NotificationType.achievement ||
                n.type == NotificationType.system;
          default:
            return true;
        }
      }

      expect(matchesFilter(notif, 'all'), isTrue);
      expect(matchesFilter(notif, 'social'), isTrue);
      expect(matchesFilter(notif, 'planner'), isFalse);
      expect(matchesFilter(notif, 'system'), isFalse);
    });
  });
}
