import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/features/social/data/comment_model.dart';
import 'package:lamia_app/features/social/presentation/widgets/comment_input.dart';
import 'package:lamia_app/features/social/presentation/widgets/comment_tile.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testComment = CommentModel(
    id: 'test-c1',
    recipeId: 'test-r1',
    userId: 'user-1',
    userName: 'Chef Anton',
    text: 'This adobo recipe is fantastic!',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    likedBy: ['user-2'],
  );

  group('CommentInput reactivity', () {
    testWidgets('Composer button enables as soon as user enters text', (tester) async {
      String? submittedText;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentInput(
                variant: CommentInputVariant.composer,
                controller: controller,
                onSubmit: (text) => submittedText = text,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find Post Comment button
      final postButtonFinder = find.widgetWithText(ElevatedButton, 'Post Comment');
      expect(postButtonFinder, findsOneWidget);

      // Button is initially disabled
      ElevatedButton button = tester.widget(postButtonFinder);
      expect(button.onPressed, isNull);

      // Enter text into field
      await tester.enterText(find.byType(TextField), 'Delicious!');
      await tester.pump();

      // Button should now be enabled
      button = tester.widget(postButtonFinder);
      expect(button.onPressed, isNotNull);

      // Tap button and verify submit callback
      await tester.tap(postButtonFinder);
      await tester.pump();

      expect(submittedText, equals('Delicious!'));
    });

    testWidgets('Inline reply button enables when user types and invokes submit', (tester) async {
      String? submittedReply;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentInput(
                variant: CommentInputVariant.inlineReply,
                replyingToName: 'Chef Anton',
                onSubmit: (text) => submittedReply = text,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final replyButtonFinder = find.widgetWithText(ElevatedButton, 'Reply');
      expect(replyButtonFinder, findsOneWidget);

      // Initially disabled
      ElevatedButton button = tester.widget(replyButtonFinder);
      expect(button.onPressed, isNull);

      // Enter text
      await tester.enterText(find.byType(TextField), 'I agree!');
      await tester.pump();

      // Enabled
      button = tester.widget(replyButtonFinder);
      expect(button.onPressed, isNotNull);

      await tester.tap(replyButtonFinder);
      await tester.pump();

      expect(submittedReply, equals('I agree!'));
    });
  });

  group('CommentTile actions', () {
    testWidgets('Top-level tile allows liking and triggers onToggleLike', (tester) async {
      var likeTapped = false;
      var replyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentTile(
                comment: testComment,
                currentUserUid: 'user-3',
                isTopLevel: true,
                onToggleLike: () => likeTapped = true,
                onReply: () => replyTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap heart
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      expect(likeTapped, isTrue);

      // Tap reply
      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(replyTapped, isTrue);
    });
  });
}
