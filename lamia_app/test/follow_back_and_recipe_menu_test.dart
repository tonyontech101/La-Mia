import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/core/providers/current_user_provider.dart';
import 'package:lamia_app/features/profile/presentation/widgets/profile_header_widget.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:lamia_app/features/recipes/presentation/widgets/vertical_popping_button.dart';
import 'package:lamia_app/features/social/data/follow_repository.dart';

void main() {
  group('Follow Back Indicator Tests', () {
    testWidgets('ProfileHeaderWidget renders "+ Follow Chef" when user does not follow you and you do not follow them', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderWidget(
              displayName: 'Chef Mario',
              isOwnProfile: false,
              isFollowing: false,
              followsYou: false,
              onFollowTap: () {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ElevatedButton, '+ Follow Chef'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Follow Back'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Following'), findsNothing);
    });

    testWidgets('ProfileHeaderWidget renders "Follow Back" when other user follows you and you do not follow them', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderWidget(
              displayName: 'Chef Mario',
              isOwnProfile: false,
              isFollowing: false,
              followsYou: true,
              onFollowTap: () {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ElevatedButton, 'Follow Back'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '+ Follow Chef'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Following'), findsNothing);
    });

    testWidgets('ProfileHeaderWidget renders "Following" when you already follow the user, even if they follow you', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderWidget(
              displayName: 'Chef Mario',
              isOwnProfile: false,
              isFollowing: true,
              followsYou: true,
              onFollowTap: () {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ElevatedButton, 'Following'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Follow Back'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, '+ Follow Chef'), findsNothing);
    });
  });

  group('VerticalPoppingButton & 3-Dot Menu Button Tests', () {
    testWidgets('VerticalPoppingButton renders custom label and icon', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerticalPoppingButton(
              activeIcon: Icons.more_horiz_rounded,
              inactiveIcon: Icons.more_horiz_rounded,
              isActive: false,
              activeColor: Colors.black,
              inactiveColor: Colors.grey,
              label: 'More',
              showCount: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      await tester.tap(find.byType(VerticalPoppingButton));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('VerticalPoppingButton falls back to numeric count when no label is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerticalPoppingButton(
              activeIcon: Icons.favorite_rounded,
              inactiveIcon: Icons.favorite_rounded,
              isActive: true,
              activeColor: Colors.red,
              inactiveColor: Colors.grey,
              count: 42,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('RecipeDetailScreen TikTok Action Sheet & Follow Back Tests', () {
    testWidgets('RecipeDetailScreen shows "follow back" and opens TikTok-style bottom sheet with 5 options', (tester) async {
      final recipe = RecipeModel(
        id: 'bihon-123',
        name: 'Bihon Guisado',
        description: 'Sauteed Rice Noodles.',
        category: 'Pancit at Noodles',
        region: 'Tagalog',
        prepTime: '15 mins',
        cookTime: '20 mins',
        servings: 4,
        difficulty: 'Easy',
        ingredients: ['1 pack bihon', '1 cup shrimp'],
        instructions: ['Step 1: Soak noodles', 'Step 2: Stir fry'],
        tags: ['Pancit at Noodles'],
        coverPhotoUrl: '',
        source: 'user',
        isSystemRecipe: false,
        authorId: 'author-mario-99',
        authorName: 'Mario Batali',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => 'viewer-user-1'),
            currentUserFollowingIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
            currentUserFollowerIdsProvider.overrideWith((ref) => Stream.value({'author-mario-99'})),
          ],
          child: MaterialApp(
            home: RecipeDetailScreen(
              recipe: recipe,
              screenTitle: 'Featured Recipe',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Author byline should show "follow back" because author is in currentUserFollowerIdsProvider
      expect(find.text('follow back'), findsOneWidget);

      // Verify the 3-dot "More" button on the recipe card
      expect(find.byIcon(Icons.more_horiz_rounded), findsAtLeastNWidgets(1));
      expect(find.text('More'), findsOneWidget);

      // Tap the "More" button to open TikTok-style bottom sheet
      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Check TikTok sheet contents
      expect(find.text('Share to'), findsOneWidget);
      expect(find.text('Share this recipe'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);

      expect(find.text('Recipe Actions'), findsOneWidget);
      expect(find.text('Add to planner'), findsOneWidget);
      expect(find.text('Add to groceries'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Share to'), findsNothing);
    });
  });
}
