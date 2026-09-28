// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/notifications/data/notification_repository.dart';
import 'package:lamia_app/features/notifications/services/fcm_service.dart';

// ── Test Doubles ─────────────────────────────────────────────────────────────

class FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  FakeDocRef(this.id);

  @override
  final String id;
  Map<String, dynamic>? lastSetData;
  SetOptions? lastSetOptions;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    lastSetData = data;
    lastSetOptions = options;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeColRef implements CollectionReference<Map<String, dynamic>> {
  FakeColRef(this.path);

  @override
  final String path;
  final Map<String, FakeDocRef> docs = {};

  @override
  FakeDocRef doc([String? path]) {
    final docId = path ?? 'default_doc';
    return docs.putIfAbsent(docId, () => FakeDocRef(docId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirestore implements FirebaseFirestore {
  final Map<String, FakeColRef> collections = {};

  @override
  FakeColRef collection(String collectionPath) {
    return collections.putIfAbsent(
      collectionPath,
      () => FakeColRef(collectionPath),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUser implements User {
  MockUser({required this.uid});

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements FirebaseAuth {
  MockFirebaseAuth({this.currentUser, StreamController<User?>? controller})
      : _controller = controller ?? StreamController<User?>.broadcast();

  final StreamController<User?> _controller;

  @override
  User? currentUser;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  void emitUser(User? user) {
    currentUser = user;
    _controller.add(user);
  }

  void close() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseMessaging implements FirebaseMessaging {
  MockFirebaseMessaging({this.token = 'mock_fcm_token_xyz'});

  String? token;
  int getTokenCallCount = 0;

  @override
  Future<String?> getToken({String? vapidKey}) async {
    getTokenCallCount++;
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationRepository implements NotificationRepository {
  final List<Map<String, String>> savedTokens = [];
  final List<Map<String, String>> removedTokens = [];

  @override
  Future<void> saveFcmToken(String userId, String token) async {
    savedTokens.add({'userId': userId, 'token': token});
  }

  @override
  Future<void> removeFcmToken(String userId, String token) async {
    removedTokens.add({'userId': userId, 'token': token});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('NotificationRepository FCM Token Operations', () {
    late FakeFirestore fakeFirestore;
    late NotificationRepository repository;

    setUp(() {
      fakeFirestore = FakeFirestore();
      repository = NotificationRepository(firestore: fakeFirestore);
    });

    test('saveFcmToken writes FieldValue.arrayUnion to users/{userId} with merge true', () async {
      const userId = 'user_abc_123';
      const token = 'sample_fcm_token_val';

      await repository.saveFcmToken(userId, token);

      final userCol = fakeFirestore.collections['users'];
      expect(userCol, isNotNull);
      final userDoc = userCol!.docs[userId];
      expect(userDoc, isNotNull);

      expect(userDoc!.lastSetOptions?.merge, isTrue);
      expect(userDoc.lastSetData, isNotNull);
      expect(userDoc.lastSetData!.containsKey('fcmTokens'), isTrue);
      expect(
        userDoc.lastSetData!['fcmTokens'],
        equals(FieldValue.arrayUnion([token])),
      );
    });

    test('removeFcmToken writes FieldValue.arrayRemove to users/{userId} with merge true', () async {
      const userId = 'user_xyz_789';
      const token = 'sample_fcm_token_to_remove';

      await repository.removeFcmToken(userId, token);

      final userCol = fakeFirestore.collections['users'];
      expect(userCol, isNotNull);
      final userDoc = userCol!.docs[userId];
      expect(userDoc, isNotNull);

      expect(userDoc!.lastSetOptions?.merge, isTrue);
      expect(userDoc.lastSetData, isNotNull);
      expect(userDoc.lastSetData!.containsKey('fcmTokens'), isTrue);
      expect(
        userDoc.lastSetData!['fcmTokens'],
        equals(FieldValue.arrayRemove([token])),
      );
    });
  });

  group('FCMService Token Sync & Lifecycle', () {
    late MockFirebaseMessaging mockMessaging;
    late MockNotificationRepository mockRepo;
    late MockFirebaseAuth mockAuth;
    late FCMService fcmService;

    setUp(() {
      mockMessaging = MockFirebaseMessaging(token: 'device_token_001');
      mockRepo = MockNotificationRepository();
      mockAuth = MockFirebaseAuth();
      fcmService = FCMService.custom(
        fcm: mockMessaging,
        notifRepo: mockRepo,
        auth: mockAuth,
      );
    });

    tearDown(() {
      fcmService.dispose();
      mockAuth.close();
    });

    test('syncToken saves token when currentUser is authenticated', () async {
      final user = MockUser(uid: 'user_authenticated_1');
      mockAuth.currentUser = user;

      await fcmService.syncToken();

      expect(mockRepo.savedTokens.length, 1);
      expect(mockRepo.savedTokens.first, {
        'userId': 'user_authenticated_1',
        'token': 'device_token_001',
      });
      expect(mockRepo.removedTokens, isEmpty);
    });

    test('syncToken does nothing when currentUser is null (guest)', () async {
      mockAuth.currentUser = null;

      await fcmService.syncToken();

      expect(mockRepo.savedTokens, isEmpty);
      expect(mockMessaging.getTokenCallCount, 0);
    });

    test('syncToken with explicit userId saves token for specified user', () async {
      mockAuth.currentUser = null;

      await fcmService.syncToken('explicit_user_2');

      expect(mockRepo.savedTokens.length, 1);
      expect(mockRepo.savedTokens.first, {
        'userId': 'explicit_user_2',
        'token': 'device_token_001',
      });
    });

    test('clearTokenOnLogout removes token when currentUser is authenticated', () async {
      final user = MockUser(uid: 'user_logging_out_1');
      mockAuth.currentUser = user;

      await fcmService.clearTokenOnLogout();

      expect(mockRepo.removedTokens.length, 1);
      expect(mockRepo.removedTokens.first, {
        'userId': 'user_logging_out_1',
        'token': 'device_token_001',
      });
      expect(mockRepo.savedTokens, isEmpty);
    });

    test('clearTokenOnLogout does nothing when currentUser is null and no userId provided', () async {
      mockAuth.currentUser = null;

      await fcmService.clearTokenOnLogout();

      expect(mockRepo.removedTokens, isEmpty);
      expect(mockMessaging.getTokenCallCount, 0);
    });

    test('clearTokenOnLogout with explicit userId removes token even if currentUser is null', () async {
      mockAuth.currentUser = null;

      await fcmService.clearTokenOnLogout('previously_logged_in_user');

      expect(mockRepo.removedTokens.length, 1);
      expect(mockRepo.removedTokens.first, {
        'userId': 'previously_logged_in_user',
        'token': 'device_token_001',
      });
    });
  });

  group('FCMService Auth State Changes Listener', () {
    late MockFirebaseMessaging mockMessaging;
    late MockNotificationRepository mockRepo;
    late MockFirebaseAuth mockAuth;
    late FCMService fcmService;

    setUp(() {
      mockMessaging = MockFirebaseMessaging(token: 'live_device_token_123');
      mockRepo = MockNotificationRepository();
      mockAuth = MockFirebaseAuth();
      fcmService = FCMService.custom(
        fcm: mockMessaging,
        notifRepo: mockRepo,
        auth: mockAuth,
      );
    });

    tearDown(() {
      fcmService.dispose();
      mockAuth.close();
    });

    test('automatically syncs token when user logs in via authStateChanges', () async {
      fcmService.setupAuthListener();

      expect(mockRepo.savedTokens, isEmpty);

      // Simulate user login event
      final user = MockUser(uid: 'logged_in_user_456');
      mockAuth.emitUser(user);

      // Allow microtasks / async listener to execute
      await pumpEventQueue();

      expect(mockRepo.savedTokens.length, 1);
      expect(mockRepo.savedTokens.first, {
        'userId': 'logged_in_user_456',
        'token': 'live_device_token_123',
      });
    });

    test('automatically clears token when user logs out via authStateChanges', () async {
      fcmService.setupAuthListener();

      // Step 1: User logs in
      final user = MockUser(uid: 'user_who_will_logout');
      mockAuth.emitUser(user);
      await pumpEventQueue();

      expect(mockRepo.savedTokens.length, 1);
      expect(mockRepo.removedTokens, isEmpty);

      // Step 2: User logs out (authStateChanges emits null)
      mockAuth.emitUser(null);
      await pumpEventQueue();

      expect(mockRepo.removedTokens.length, 1);
      expect(mockRepo.removedTokens.first, {
        'userId': 'user_who_will_logout',
        'token': 'live_device_token_123',
      });
    });

    test('does not sync token if initial authStateChanges emits null (unauthenticated guest)', () async {
      fcmService.setupAuthListener();

      mockAuth.emitUser(null);
      await pumpEventQueue();

      expect(mockRepo.savedTokens, isEmpty);
      expect(mockRepo.removedTokens, isEmpty);
    });
  });
}
