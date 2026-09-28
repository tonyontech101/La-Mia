import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/features/profile/presentation/widgets/app_right_sidebar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('AppRightSidebar renders active user rank and badge count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppRightSidebar(
            isGuest: false,
            initialRank: 5,
            initialUnlockedBadgesCount: 3,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Rank badge shows #5
    expect(find.text('#5'), findsOneWidget);

    // Verify Badges count shows 3 badges
    expect(find.text('3 badges'), findsOneWidget);
  });

  testWidgets('AppRightSidebar renders singular 1 badge when count is 1', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppRightSidebar(
            isGuest: false,
            initialRank: 1,
            initialUnlockedBadgesCount: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('1 badge'), findsOneWidget);
  });

  testWidgets('AppRightSidebar renders Unranked and 0 badges for new inactive user', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppRightSidebar(
            isGuest: false,
            initialRank: null,
            initialUnlockedBadgesCount: 0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('0 badges'), findsOneWidget);
    expect(find.text('#34'), findsNothing);
    expect(find.text('4 badges'), findsNothing);
  });

  testWidgets('AppRightSidebar omits rank and badge pills in guest mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppRightSidebar(
            isGuest: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('#34'), findsNothing);
    expect(find.text('4 badges'), findsNothing);
    expect(find.text('Unranked'), findsNothing);
  });
}
