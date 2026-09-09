import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lamia_app/features/legal/data/legal_content.dart';
import 'package:lamia_app/features/legal/presentation/legal_document_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('LegalContent', () {
    test('provides comprehensive Terms of Service sections', () {
      final terms = LegalContent.termsOfService;
      expect(terms.title, 'Terms of Service');
      expect(terms.sections, isNotEmpty);
      expect(
        terms.sections.any((s) => s.heading.contains('Food Safety')),
        isTrue,
      );
      expect(
        terms.sections.any((s) => s.heading.contains('User-Generated Content')),
        isTrue,
      );
    });

    test('provides comprehensive Privacy Policy sections complying with RA 10173', () {
      final privacy = LegalContent.privacyPolicy;
      expect(privacy.title, 'Privacy Policy');
      expect(privacy.sections, isNotEmpty);
      expect(
        privacy.sections.any((s) => s.heading.contains('Data Subject Rights')),
        isTrue,
      );
      expect(
        privacy.sections.any((s) => s.heading.contains('Information We Collect')),
        isTrue,
      );
    });
  });

  group('LegalDocumentScreen Widget Test', () {
    testWidgets('renders Terms of Service with header and sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LegalDocumentScreen.termsOfService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Effective:'), findsOneWidget);
      expect(find.textContaining('Acceptance of Terms'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('renders Privacy Policy with header and sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LegalDocumentScreen.privacyPolicy(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Effective:'), findsOneWidget);
      expect(find.textContaining('Introduction'), findsOneWidget);
    });

    testWidgets('pops screen when back button tapped', (tester) async {
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LegalDocumentScreen.termsOfService(),
                    ),
                  );
                  popped = true;
                },
                child: const Text('Open Terms'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Terms'));
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsAtLeastNWidgets(1));

      // Tap back button
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text('Open Terms'), findsOneWidget);
    });
  });
}
