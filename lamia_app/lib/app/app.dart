import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';

/// Root application widget.
///
/// Front-end only: launches straight into the auth flow (Login → Sign Up).
/// Navigation to the home/browse experience is a stub for now.
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
        home: const LoginScreen(),
      ),
    );
  }
}
