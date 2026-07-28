// Smoke tests for the La Mia auth front-end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/features/auth/presentation/login_screen.dart';

void main() {
  setUpAll(() {
    // Avoid network font fetches during tests; fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // Use a tall phone viewport so all fields/buttons are laid out on-screen.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('Login screen renders its key elements', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('Login shows an email error when submitting empty form',
      (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pump();

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Navigating to Sign Up shows the Join La Mia screen',
      (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pump();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Join La Mia'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
  });
}
