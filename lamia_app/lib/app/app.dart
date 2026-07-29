import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_placeholder_screen.dart';

/// Root application widget.
///
/// Listens to Firebase Auth state and routes to the login screen or the home
/// placeholder accordingly.
class LaMiaApp extends StatelessWidget {
  const LaMiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons over the dark hero scrim.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        title: 'La Mia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Show a brief loading indicator while Firebase resolves the
            // persisted session on cold start.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If user is signed in, go to home. Otherwise, show login.
            if (snapshot.hasData) {
              return const HomePlaceholderScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
