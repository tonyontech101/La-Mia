import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/features/social/data/comment_model.dart';
import 'package:lamia_app/features/social/data/comment_repository.dart';
import 'package:lamia_app/features/social/presentation/widgets/comment_input.dart';
import 'package:lamia_app/features/social/presentation/widgets/comment_thread.dart';
import 'package:lamia_app/features/social/presentation/widgets/comment_tile.dart';
import 'package:lamia_app/features/social/presentation/widgets/view_replies_toggle.dart';

class _FakeCommentRepo extends Fake implements CommentRepository {}

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

    testWidgets('Inline reply button is disabled while submitting', (tester) async {
      var submitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentInput(
                variant: CommentInputVariant.inlineReply,
                replyingToName: 'Chef Anton',
                isSubmitting: true,
                onSubmit: (_) => submitCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Double tap guard');
      await tester.pump();

      final replyButtonFinder = find.widgetWithText(ElevatedButton, 'Replying...');
      expect(replyButtonFinder, findsOneWidget);

      final ElevatedButton button = tester.widget(replyButtonFinder);
      expect(button.onPressed, isNull);

      await tester.tap(replyButtonFinder, warnIfMissed: false);
      await tester.pump();
      expect(submitCount, 0);
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

    testWidgets('Reply tile (depth ≥ 1) still shows Reply button', (tester) async {
      var replyTapped = false;
      final nestedReply = CommentModel(
        id: 'reply-1',
        recipeId: 'test-r1',
        userId: 'user-2',
        userName: 'Chef B',
        text: 'Thanks!',
        createdAt: DateTime.now(),
        parentCommentId: 'test-c1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentTile(
                comment: nestedReply,
                currentUserUid: 'user-3',
                isTopLevel: false,
                onReply: () => replyTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reply'), findsOneWidget);
      await tester.tap(find.text('Reply'));
      await tester.pump();
      expect(replyTapped, isTrue);
    });

    testWidgets('Reply tile shows "Replying to @name" when replyingToName set', (tester) async {
      final nestedReply = CommentModel(
        id: 'reply-2',
        recipeId: 'test-r1',
        userId: 'user-2',
        userName: 'Chef B',
        text: 'Agreed',
        createdAt: DateTime.now(),
        parentCommentId: 'reply-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentTile(
                comment: nestedReply,
                currentUserUid: 'user-3',
                isTopLevel: false,
                replyingToName: 'Chef Anton',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Replying to @Chef Anton'), findsOneWidget);
    });

    testWidgets('Reply tile (depth ≥ 1) card has border, shadow, and rounded corners', (tester) async {
      final replyComment = CommentModel(
        id: 'reply-1',
        recipeId: 'test-r1',
        userId: 'user-2',
        userName: 'Bugg',
        text: 'Hello world',
        createdAt: DateTime.now(),
        parentCommentId: 'test-c1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentTile(
                comment: replyComment,
                currentUserUid: 'user-3',
                isTopLevel: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the card container (first Expanded's child in CommentTile Row)
      final commentTileFinder = find.byType(CommentTile);
      final expandeds = tester.widgetList<Expanded>(
        find.descendant(of: commentTileFinder, matching: find.byType(Expanded)),
      );
      final Container bubbleContainer = expandeds.first.child as Container;
      final BoxDecoration decoration = bubbleContainer.decoration as BoxDecoration;

      // Must have border, shadow, and rounded corners
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, isTrue);
      expect(decoration.borderRadius, isNotNull);
    });
  });

  group('ViewRepliesToggle labels', () {
    testWidgets('shows singular for one reply and toggles to hide', (tester) async {
      var expanded = false;

      Widget build() => MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ViewRepliesToggle(
                  replyCount: 1,
                  isExpanded: expanded,
                  onToggle: () => setState(() => expanded = !expanded),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pump();
      expect(find.text('View 1 reply'), findsOneWidget);

      await tester.tap(find.text('View 1 reply'));
      await tester.pumpAndSettle();
      expect(find.text('Hide replies'), findsOneWidget);
    });

    testWidgets('shows plural for multiple replies', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewRepliesToggle(
              replyCount: 3,
              isExpanded: false,
              onToggle: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('View 3 replies'), findsOneWidget);
    });
  });

  group('Inline reply header', () {
    testWidgets('shows Replying to @name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentInput(
                variant: CommentInputVariant.inlineReply,
                replyingToName: 'Chef Anton',
                onSubmit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Replying to @Chef Anton'), findsOneWidget);
    });
  });

  group('CommentThread reply rendering', () {
    testWidgets('renders direct and nested replies with proper separation and context', (tester) async {
      final parent = CommentModel(
        id: 'p1',
        recipeId: 'r1',
        userId: 'u1',
        userName: 'Jayzer',
        text: 'Lami siya murag ako',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );

      final reply1 = CommentModel(
        id: 'rep1',
        recipeId: 'r1',
        userId: 'u2',
        userName: 'Bugg',
        text: 'you gay nan',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        parentCommentId: 'p1',
      );

      final reply2 = CommentModel(
        id: 'rep2',
        recipeId: 'r1',
        userId: 'u2',
        userName: 'Bugg',
        text: 'shit',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        parentCommentId: 'rep1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentThread(
                parent: parent,
                commentRepository: _FakeCommentRepo(),
                directReplies: [reply1],
                repliesByParent: {
                  'p1': [reply1],
                  'rep1': [reply2],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially collapsed, parent is visible, replies are not
      expect(find.text('Lami siya murag ako'), findsOneWidget);
      expect(find.text('View 1 reply'), findsOneWidget);
      expect(find.text('you gay nan'), findsNothing);

      // Expand replies
      await tester.tap(find.text('View 1 reply'));
      await tester.pumpAndSettle();

      // Now both direct and nested reply are visible
      expect(find.text('you gay nan'), findsOneWidget);
      expect(find.text('shit'), findsOneWidget);
      expect(find.text('Replying to @Bugg'), findsOneWidget);

      // All 3 CommentTiles are present
      expect(find.byType(CommentTile), findsNWidgets(3));
    });
  });
}
