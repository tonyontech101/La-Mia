import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/app_logger.dart';
import '../data/notification_repository.dart';
import 'local_notification_service.dart';
import 'notification_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background messaging: ${message.messageId}');
}

class FCMService {
  FCMService._internal({
    FirebaseMessaging? fcm,
    NotificationRepository? notifRepo,
    FirebaseAuth? auth,
  })  : _customFcm = fcm,
        _customNotifRepo = notifRepo,
        _customAuth = auth;

  static FCMService instance = FCMService._internal();

  final FirebaseMessaging? _customFcm;
  final NotificationRepository? _customNotifRepo;
  final FirebaseAuth? _customAuth;

  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;
  NotificationRepository get _notifRepo =>
      _customNotifRepo ?? NotificationRepository();
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  bool _initialized = false;
  String? _lastSyncedUserId;
  StreamSubscription<User?>? _authSubscription;

  @visibleForTesting
  static void setMockInstance(FCMService customInstance) {
    instance = customInstance;
  }

  @visibleForTesting
  static void resetInstance() {
    instance = FCMService._internal();
  }

  @visibleForTesting
  factory FCMService.custom({
    FirebaseMessaging? fcm,
    NotificationRepository? notifRepo,
    FirebaseAuth? auth,
  }) {
    return FCMService._internal(
      fcm: fcm,
      notifRepo: notifRepo,
      auth: auth,
    );
  }

  /// Sets up a listener to auth state changes to sync token immediately when user signs in.
  @visibleForTesting
  StreamSubscription<User?> setupAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        _lastSyncedUserId = user.uid;
        await syncToken(user.uid);
      } else if (_lastSyncedUserId != null) {
        await clearTokenOnLogout(_lastSyncedUserId);
        _lastSyncedUserId = null;
      }
    });
    return _authSubscription!;
  }

  @visibleForTesting
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initial permission request (safe to run on startup)
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Load initial token
      await syncToken();

      // Listen to auth state changes to sync token immediately when user signs in
      setupAuthListener();

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((token) async {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await _notifRepo.saveFcmToken(user.uid, token);
          } catch (e, stackTrace) {
            AppLogger.error(
              'Failed to save refreshed FCM token',
              error: e,
              stackTrace: stackTrace,
              category: 'FCMService',
            );
          }
        }
      });

      // Listen to foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          LocalNotificationService.instance.showNotification(
            id: notification.hashCode,
            title: notification.title ?? 'La Mia',
            body: notification.body ?? '',
            channelId: 'system_updates',
            channelName: 'System Updates',
            payload: jsonEncode(message.data),
          );
        }
      });

      // Listen to background notification taps (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data.isNotEmpty) {
          NotificationRouter.navigateWithPayload(jsonEncode(message.data));
        }
      });

      // Check cold-start notification (app terminated)
      _checkInitialMessage();

      _initialized = true;
    } catch (e) {
      debugPrint('FCMService initialize error: $e');
    }
  }

  /// Checks if the app was launched by tapping a notification from a terminated state.
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationRouter.navigateWithPayload(jsonEncode(initialMessage.data));
        });
      }
    } catch (e) {
      debugPrint('Error checking initial FCM message: $e');
    }
  }

  /// Syncs current device FCM token to Firestore under user document.
  Future<void> syncToken([String? userId]) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid != null) {
      _lastSyncedUserId = uid;
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _notifRepo.saveFcmToken(uid, token);
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to sync FCM token',
          error: e,
          stackTrace: stackTrace,
          category: 'FCMService',
        );
      }
    }
  }

  /// Clears token from database during user sign out.
  Future<void> clearTokenOnLogout([String? userId]) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _notifRepo.removeFcmToken(uid, token);
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'Failed to clear FCM token on logout',
          error: e,
          stackTrace: stackTrace,
          category: 'FCMService',
        );
      }
      if (_lastSyncedUserId == uid) {
        _lastSyncedUserId = null;
      }
    }
  }
}
