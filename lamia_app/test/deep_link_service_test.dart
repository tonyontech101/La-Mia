import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lamia_app/app/app.dart';
import 'package:lamia_app/core/services/deep_link_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DeepLinkService', () {
    testWidgets('handleUri processes custom scheme link and dispatches navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const Scaffold(body: Text('Deep Link Home')),
        ),
      );
      await tester.pumpAndSettle();

      final service = DeepLinkService.instance;
      final navigatedIds = <String>[];
      service.onNavigateToRecipe = (id) => navigatedIds.add(id);

      // Handle a valid custom scheme URI
      service.handleUri(Uri.parse('lamia://recipe/test-recipe-123'));
      expect(navigatedIds, contains('test-recipe-123'));

      // Handle a valid web URL
      service.handleUri(Uri.parse('https://lamia.app/recipe/adobo-456'));
      expect(navigatedIds, contains('adobo-456'));

      // Handle an unrelated URI (should silently ignore)
      service.handleUri(Uri.parse('https://google.com'));
      expect(navigatedIds.length, 2);

      service.onNavigateToRecipe = null;
    });
  });
}
