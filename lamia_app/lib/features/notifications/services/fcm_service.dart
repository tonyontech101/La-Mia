import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../data/notification_repository.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background messaging: ${message.messageId}");
}

class FCMService {
  FCMService._internal();
  static final FCMService instance = FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final NotificationRepository _notifRepo = NotificationRepository();

  bool _initialized = false;

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

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((token) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await _notifRepo.saveFcmToken(user.uid, token);
          } catch (_) {}
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

      _initialized = true;
    } catch (e) {
      debugPrint('FCMService initialize error: $e');
    }
  }

  /// Syncs current device FCM token to Firestore under user document.
  Future<void> syncToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _notifRepo.saveFcmToken(user.uid, token);
        }
      } catch (_) {}
    }
  }

  /// Clears token from database during user sign out.
  Future<void> clearTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _notifRepo.removeFcmToken(user.uid, token);
        }
      } catch (_) {}
    }
  }
}
