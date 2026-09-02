import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/app/theme/app_colors.dart';
import 'package:lamia_app/features/profile/presentation/widgets/dish_card_grid.dart';
import 'package:lamia_app/features/profile/presentation/widgets/profile_header_widget.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('ProfileHeaderWidget renders horizontal layout and status badges', (tester) async {
    bool followedTapped = false;
    bool followingTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeaderWidget(
              displayName: 'Gabriel',
              username: 'gabriel_cook',
              bio: 'Cooking authentic Filipino meals daily.',
              rankingLabel: '#24 ranking',
              followingCount: '24',
              followersCount: '1200',
              likesCount: '850',
              recognitions: const [
                ProfileRecognition(
                  label: 'Top Contributor',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.secondary,
                ),
                ProfileRecognition(
                  label: 'Most Cooked',
                  icon: Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                ),
              ],
              onFollowingTap: () => followingTapped = true,
              onFollowersTap: () => followedTapped = true,
              onAchievementsTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Nickname & Ranking
    expect(find.text('Gabriel'), findsOneWidget);
    expect(find.text('#24 ranking'), findsOneWidget);

    // Stats Row
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('1.2k'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('850'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);

    // Bio
    expect(find.text('Cooking authentic Filipino meals daily.'), findsOneWidget);

    // Horizontal Status Badges
    expect(find.text('Top Contributor'), findsOneWidget);
    expect(find.text('Most Cooked'), findsOneWidget);

    // Achievements Link
    expect(find.text('See your overall achievements!'), findsOneWidget);

    // Interaction test
    await tester.tap(find.text('Following'));
    expect(followingTapped, isTrue);

    await tester.tap(find.text('Followers'));
    expect(followedTapped, isTrue);
  });

  testWidgets('DishCardGrid renders dish cards with larger icons and counts', (tester) async {
    final recipes = <RecipeModel>[
      RecipeModel(
        id: 'r1',
        name: 'Sinigang na Baboy',
        category: 'Soup',
        region: 'Luzon',
        prepTime: '20m',
        cookTime: '50m',
        servings: 4,
        difficulty: 'Medium',
        ingredients: const ['500g pork belly', '1 pack tamarind soup mix', '1 bunch kangkong'],
        instructions: const ['Boil pork in water.', 'Add tamarind mix and veggies.'],
        tags: const ['Sour', 'Soup'],
        coverPhotoUrl: '',
        source: 'user',
        likeCount: 150,
        favoriteCount: 150,
      ),
      RecipeModel(
        id: 'r2',
        name: 'Kare-Kare',
        category: 'Stew',
        region: 'Luzon',
        prepTime: '30m',
        cookTime: '1h 20m',
        servings: 6,
        difficulty: 'Hard',
        ingredients: const ['1kg oxtail', '1/2 cup peanut butter', '1 bunch pechay'],
        instructions: const ['Tenderize oxtail.', 'Mix peanut sauce and simmer.'],
        tags: const ['Peanut', 'Stew'],
        coverPhotoUrl: '',
        source: 'user',
        likeCount: 95,
        favoriteCount: 42,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DishCardGrid(
              recipes: recipes,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sinigang na Baboy'), findsOneWidget);
    expect(find.text('Kare-Kare'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.bookmark_rounded), findsNWidgets(2));
  });
}
