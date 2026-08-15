// Smoke tests for the sliding tab bar + tab switcher animations introduced
// for the whole-app fluid-motion pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/core/widgets/sliding_tab_bar.dart';
import 'package:lamia_app/features/leaderboard/presentation/leaderboard_screen.dart';

void main() {
  setUpAll(() {
    // Avoid network font fetches during tests; fall back to bundled fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
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

  group('SlidingTabBar', () {
    testWidgets('renders centered labels and reports taps', (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlidingTabBar(
              index: selected,
              itemCount: 3,
              highlight: Container(),
              onChanged: (i) => selected = i,
              builder: (context, i, isActive) =>
                  Center(child: Text('Tab $i', textAlign: TextAlign.center)),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tab 0'), findsOneWidget);
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Tab 2'), findsOneWidget);

      // Each label should be horizontally centered within its third of the
      // bar: tab 0 at 1/6, tab 1 at 3/6, tab 2 at 5/6 of the screen width.
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      const cells = 3;
      for (var i = 0; i < cells; i++) {
        final expectedCenterX = screenWidth * (i + 0.5) / cells;
        final actualCenterX = tester.getCenter(find.text('Tab $i')).dx;
        expect(
          (actualCenterX - expectedCenterX).abs(),
          lessThan(2.0),
          reason: 'Tab $i should be centered in its cell',
        );
      }

      // Tapping a label reports its index.
      await tester.tap(find.text('Tab 1'));
      await tester.pump();
      expect(selected, 1);
    });
  });

  group('LeaderboardScreen tab bar', () {
    testWidgets('slides content between Top Contributors / Most Cooked', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LeaderboardScreen()));
      await tester.pump();

      expect(find.text('Top Contributors'), findsOneWidget);
      expect(find.text('Most Cooked'), findsOneWidget);

      // Both labels are centered inside their half of the tab bar.
      final barRect = tester.getRect(find.byType(SlidingTabBar));
      final tcCenter = tester.getCenter(find.text('Top Contributors')).dx;
      final mcCenter = tester.getCenter(find.text('Most Cooked')).dx;
      expect(
        (tcCenter - (barRect.left + barRect.width * 0.25)).abs(),
        lessThan(3.0),
        reason: 'Top Contributors should sit in the center of the left half',
      );
      expect(
        (mcCenter - (barRect.left + barRect.width * 0.75)).abs(),
        lessThan(3.0),
        reason: 'Most Cooked should sit in the center of the right half',
      );

      // Default tab content (Top Contributors roster).
      expect(find.text('Kuya Ben Cruz'), findsOneWidget);
      expect(find.text('Inay Dina Ramos'), findsNothing);

      // Switch to Most Cooked — roster slides in.
      await tester.tap(find.text('Most Cooked'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Inay Dina Ramos'), findsOneWidget);
      expect(find.text('Kuya Ben Cruz'), findsNothing);

      // Switch back.
      await tester.tap(find.text('Top Contributors'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Kuya Ben Cruz'), findsOneWidget);
      expect(find.text('Inay Dina Ramos'), findsNothing);
    });
  });
}