import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'features/notifications/services/local_notification_service.dart';
import 'features/notifications/services/fcm_service.dart';
import 'core/services/deep_link_service.dart';

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.title, this.exception, this.stackTrace});

  final String title;
  final Object? exception;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!kReleaseMode && exception != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Exception:\n$exception',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!kReleaseMode && stackTrace != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Stack Trace:\n$stackTrace',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _ErrorScreen(
      title: 'Application Error',
      exception: details.exception,
      stackTrace: details.stack,
    );
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stackTrace) {
    runApp(_ErrorScreen(
      title: 'Firebase Initialization Failed',
      exception: e,
      stackTrace: stackTrace,
    ));
    return;
  }

  // Safely initialize notification services without crashing the entire app
  try {
    await LocalNotificationService.instance.initialize();
    await FCMService.instance.initialize();
  } catch (e) {
    debugPrint('Notification services init warning (requires full app restart after adding new plugins): $e');
  }

  // Initialize deep linking for recipe sharing
  try {
    await DeepLinkService.instance.init();
  } catch (e) {
    debugPrint('DeepLinkService init warning: $e');
  }

  runApp(const ProviderScope(child: LaMiaApp()));
}
