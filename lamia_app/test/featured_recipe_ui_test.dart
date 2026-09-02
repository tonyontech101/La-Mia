import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/features/home/presentation/widgets/featured_recipes_section.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/presentation/recipe_detail_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testRecipe = RecipeModel(
    id: 'test-adobo',
    name: 'Classic Chicken Adobo',
    description: 'A popular chicken recipe dated back in the early 19th century.',
    category: 'Breakfast',
    region: 'Luzon',
    prepTime: '15m',
    cookTime: '45m',
    servings: 4,
    difficulty: 'Medium',
    ingredients: ['1 kg chicken', '1/2 cup soy sauce', '1/2 cup vinegar'],
    instructions: ['Marinate chicken in soy sauce.', 'Simmer until tender.'],
    tags: ['Traditional', 'Savory'],
    coverPhotoUrl: '',
    source: 'seed',
    authorName: 'Gabriel',
    ratingAvg: 4.9,
    ratingCount: 1200,
  );

  testWidgets('FeaturedRecipesSection renders title and rating badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturedRecipesSection(
            recipes: [testRecipe],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Featured Recipes'), findsOneWidget);
    expect(find.text('Classic Chicken Adobo'), findsOneWidget);
    expect(find.text('BREAKFAST'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
  });

  testWidgets('RecipeDetailScreen renders wireframe elements correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecipeDetailScreen(
            recipe: testRecipe,
            screenTitle: 'Featured Recipe',
          ),
        ),
      ),
    );
    await tester.pump();

    // App Bar Title
    expect(find.text('Featured Recipe'), findsOneWidget);

    // Recipe Title and Description
    expect(find.text('Classic Chicken Adobo'), findsOneWidget);
    expect(
      find.text('A popular chicken recipe dated back in the early 19th century.'),
      findsOneWidget,
    );

    // Rating Badge
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('(1.2k)'), findsOneWidget);

    // Quick Stats Grid
    expect(find.text('Prep'), findsOneWidget);
    expect(find.text('15m'), findsOneWidget);
    expect(find.text('Cook'), findsOneWidget);
    expect(find.text('45m'), findsOneWidget);
    expect(find.text('Serves'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // Rating Section
    expect(find.text('How do you rate this recipe?'), findsOneWidget);
  });
}
