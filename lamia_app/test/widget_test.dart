// Smoke tests for the La Mia auth front-end.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/core/widgets/hero_header.dart';
import 'package:lamia_app/features/auth/presentation/login_screen.dart';
import 'package:lamia_app/features/auth/presentation/sign_up_screen.dart';

void main() {
  setUpAll(() {
    // Avoid network font fetches during tests; fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // Use a tall phone viewport so all fields/buttons are laid out on-screen.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  testWidgets('Login screen renders its key elements', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pump();

    expect(find.byType(HeroHeader), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('Login shows an email error when submitting empty form', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pump();

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Login screen fits on standard phone viewport without scrolling', (
    tester,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;

    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    // Verify hero header is generously sized so the photo can be viewed more
    final heroRect = tester.getRect(find.byType(HeroHeader));
    expect(heroRect.height, greaterThanOrEqualTo(300.0));

    // Verify bottom-most link is on screen (< 844) without any scrolling
    final bottomLinkRect = tester.getRect(find.text('Create an account'));
    expect(bottomLinkRect.bottom, lessThanOrEqualTo(844.0));

    // And can be tapped directly without scrolling
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Join La Mia'), findsOneWidget);
  });

  testWidgets(
    'Login screen fits on compact phone viewport (375x667) without scrolling',
    (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(375, 667);
      view.devicePixelRatio = 1.0;

      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      final compactRect = tester.getRect(find.text('Create an account'));
      expect(compactRect.bottom, lessThanOrEqualTo(667.0));

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Join La Mia'), findsOneWidget);
    },
  );

  testWidgets(
    'Login screen displays generous hero photo on tall phone (412x915) without extra dead space',
    (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(412, 915);
      view.devicePixelRatio = 1.0;

      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      final heroRect = tester.getRect(find.byType(HeroHeader));
      expect(heroRect.height, greaterThanOrEqualTo(350.0));

      final bottomLinkRect = tester.getRect(find.text('Create an account'));
      expect(bottomLinkRect.bottom, lessThanOrEqualTo(915.0));

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Join La Mia'), findsOneWidget);
    },
  );

  testWidgets('SignUpScreen displays Enter your full name placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SignUpScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Join La Mia'), findsOneWidget);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsNothing);
  });
}
