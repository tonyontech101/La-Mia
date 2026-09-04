import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_colors.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';
import '../core/providers/current_user_provider.dart';
import '../core/widgets/fade_in_view.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/home/presentation/home_placeholder_screen.dart';

/// Root application widget.
///
/// Listens to Firebase Auth state via Riverpod and routes to the login screen
/// or the home placeholder accordingly.
///
/// On cold start the cached [User.emailVerified] value can be stale (still
/// `false` even after the user clicked the verification link in the browser).
/// We call [User.reload] before the first render to fetch the latest value
/// from Firebase so the user lands on the correct screen immediately.
/// Global navigation key used for programmatic navigation outside of the widget tree
/// (e.g., from local notification and FCM tap callbacks).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class LaMiaApp extends ConsumerStatefulWidget {
  const LaMiaApp({super.key});

  @override
  ConsumerState<LaMiaApp> createState() => _LaMiaAppState();
}

class _LaMiaAppState extends ConsumerState<LaMiaApp> {
  late final Future<void> _initialReload;

  @override
  void initState() {
    super.initState();
    _initialReload = _reloadCurrentUser();
  }

  Future<void> _reloadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'La Mia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: FutureBuilder<void>(
          future: _initialReload,
          builder: (context, reloadSnapshot) {
            if (reloadSnapshot.connectionState != ConnectionState.done) {
              return const _AppSplash();
            }

            final authState = ref.watch(authStateChangesProvider);

            return authState.when(
              loading: () => const _AppSplash(),
              error: (_, _) => const LoginScreen(),
              data: (User? user) {
                if (user == null) return const LoginScreen();

                final isGoogleUser = user.providerData
                    .any((info) => info.providerId == 'google.com');
                if (isGoogleUser || user.emailVerified) {
                  return const HomePlaceholderScreen();
                }
                return const EmailVerificationScreen();
              },
            );
          },
        ),
      ),
    );
  }
}

/// Branded loading splash shown while Firebase resolves the session on
/// cold start. Wordmark fades in with the app's signature amber underline.
class _AppSplash extends StatelessWidget {
  const _AppSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeInView(
          duration: const Duration(milliseconds: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('La Mia', style: AppTypography.brandWordmark()),
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
