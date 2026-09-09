import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/core/providers/user_profile_provider.dart';
import 'package:lamia_app/features/auth/data/user_model.dart';
import 'package:lamia_app/features/home/presentation/widgets/feed_recipe_card.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final userRecipe = RecipeModel(
    id: 'user-rec-1',
    name: 'Sinigang na Baboy',
    category: 'Dinner',
    region: 'Tagalog',
    prepTime: '20m',
    cookTime: '1h',
    servings: 4,
    difficulty: 'Easy',
    ingredients: ['500g pork', 'Tamarind mix'],
    instructions: ['Boil pork', 'Add tamarind mix'],
    tags: ['Sour', 'Soup'],
    coverPhotoUrl: '',
    source: 'community',
    authorId: 'author-user-42',
    authorName: 'Chef Maria',
    isSystemRecipe: false,
  );

  final systemRecipe = RecipeModel(
    id: 'sys-rec-1',
    name: 'Classic Adobo',
    category: 'Lunch',
    region: 'Luzon',
    prepTime: '15m',
    cookTime: '45m',
    servings: 4,
    difficulty: 'Easy',
    ingredients: ['Chicken', 'Soy sauce'],
    instructions: ['Cook adobo'],
    tags: ['Savory'],
    coverPhotoUrl: '',
    source: 'seed',
    authorId: null,
    authorName: 'La Mia',
    isSystemRecipe: true,
  );

  Widget buildTestCard(Widget card, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: card,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('System recipe hides follow button and shows Original badge', (tester) async {
    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: systemRecipe,
          onFollowTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+ Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
    expect(find.text('Original'), findsOneWidget);
  });

  testWidgets('Own recipe hides follow button', (tester) async {
    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: userRecipe,
          isOwnRecipe: true,
          onFollowTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+ Follow'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('Follow button shows "+ Follow" when isFollowing is false and handles tap', (tester) async {
    var followTapped = false;

    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: userRecipe,
          isFollowing: false,
          isOwnRecipe: false,
          onFollowTap: () => followTapped = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+ Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);

    await tester.tap(find.text('+ Follow'));
    expect(followTapped, isTrue);
  });

  testWidgets('Follow button shows "Following" when isFollowing is true', (tester) async {
    var followTapped = false;

    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: userRecipe,
          isFollowing: true,
          isOwnRecipe: false,
          onFollowTap: () => followTapped = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('+ Follow'), findsNothing);

    await tester.tap(find.text('Following'));
    expect(followTapped, isTrue);
  });

  testWidgets('FeedRecipeCard renders live author name from userProfileProvider over stale authorName', (tester) async {
    final liveAuthor = UserModel(
      uid: 'author-user-42',
      displayName: 'Jayzer Relator',
      bio: '',
      photoUrl: null,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: userRecipe, // has stale authorName: 'Chef Maria'
          isFollowing: false,
          isOwnRecipe: false,
        ),
        overrides: [
          userProfileProvider('author-user-42').overrideWith(
            (ref) => Stream.value(liveAuthor),
          ),
        ],
      ),
    );
    await tester.pump();

    // Stale name should not be displayed; live name should be displayed
    expect(find.text('@jayzerrelator'), findsOneWidget);
    expect(find.text('@chefmaria'), findsNothing);
  });

  testWidgets('FeedRecipeCard invokes onAuthorTap when tapping author username/avatar', (tester) async {
    var authorTapped = false;

    await tester.pumpWidget(
      buildTestCard(
        FeedRecipeCard(
          recipe: userRecipe,
          isFollowing: false,
          isOwnRecipe: false,
          onAuthorTap: () => authorTapped = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('@chefmaria'));
    expect(authorTapped, isTrue);
  });
}
