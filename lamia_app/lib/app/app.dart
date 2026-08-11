import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/home/presentation/home_placeholder_screen.dart';

/// Root application widget.
///
/// Listens to Firebase Auth state and routes to the login screen or the home
/// placeholder accordingly.
///
/// On cold start the cached [User.emailVerified] value can be stale (still
/// `false` even after the user clicked the verification link in the browser).
/// We call [User.reload] before the first render to fetch the latest value
/// from Firebase so the user lands on the correct screen immediately.
class LaMiaApp extends StatefulWidget {
  const LaMiaApp({super.key});

  @override
  State<LaMiaApp> createState() => _LaMiaAppState();
}

class _LaMiaAppState extends State<LaMiaApp> {
  late final Future<void> _initialReload;

  @override
  void initState() {
    super.initState();
    // Reload the current user once at startup so emailVerified is fresh.
    _initialReload = _reloadCurrentUser();
  }

  /// Reloads the Firebase Auth user from the server. This is a no-op when
  /// no user is signed in.
  Future<void> _reloadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

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
        home: FutureBuilder<void>(
          future: _initialReload,
          builder: (context, reloadSnapshot) {
            // While the initial reload is in flight, show a loading
            // indicator so we don't render with a stale emailVerified.
            if (reloadSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Now listen to auth state changes for the real-time routing.
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // Show a brief loading indicator while Firebase resolves the
                // persisted session on cold start.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // If user is signed in, check email verification.
                // Google sign-in users are auto-verified by Firebase, so
                // they go straight to home. Email/password users must click
                // the verification link first.
                if (snapshot.hasData) {
                  final user = snapshot.data!;
                  // Google users have no password provider — treat as verified.
                  final isGoogleUser = user.providerData.any(
                    (info) => info.providerId == 'google.com',
                  );
                  if (isGoogleUser || user.emailVerified) {
                    return const HomePlaceholderScreen();
                  }
                  return const EmailVerificationScreen();
                }
                return const LoginScreen();
              },
            );
          },
        ),
      ),
    );
  }
}
