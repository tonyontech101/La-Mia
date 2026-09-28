import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/core/providers/current_user_provider.dart';
import 'package:lamia_app/core/providers/repository_providers.dart';
import 'package:lamia_app/features/home/presentation/widgets/popular_choices_section.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/social/data/favorites_repository.dart';

class _FakeFavoritesRepository implements FavoritesRepository {
  int toggleCallCount = 0;
  bool isCurrentlySaved = false;
  String? lastRecipeId;
  String? lastUserId;

  @override
  Future<bool> isSaved({
    required String recipeId,
    required String userId,
  }) async {
    lastRecipeId = recipeId;
    lastUserId = userId;
    return isCurrentlySaved;
  }

  @override
  Future<bool> toggleSave({
    required String recipeId,
    required String userId,
  }) async {
    toggleCallCount++;
    lastRecipeId = recipeId;
    lastUserId = userId;
    isCurrentlySaved = !isCurrentlySaved;
    return isCurrentlySaved;
  }

  @override
  Future<List<String>> getSavedRecipeIds(String userId) async => [];

  @override
  Future<List<RecipeModel>> getSavedRecipes(String userId) async => [];
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testRecipe = RecipeModel(
    id: 'pop-adobo',
    name: 'Chicken Adobo',
    description: 'Classic Filipino adobo.',
    category: 'Ulam',
    region: 'Luzon',
    prepTime: '15 mins',
    cookTime: '45 mins',
    servings: 4,
    difficulty: 'Easy',
    ingredients: ['chicken', 'soy sauce', 'vinegar'],
    instructions: ['Marinate', 'Simmer'],
    tags: ['Savory'],
    coverPhotoUrl: '',
    source: 'seed',
    authorName: 'La Mia',
    isSystemRecipe: false,
  );

  Widget buildSection({
    required VoidCallback onRecipeTap,
    required _FakeFavoritesRepository favorites,
    String? userId,
  }) {
    return ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userId),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PopularChoicesSection(
              recipes: [testRecipe],
              onRecipeTap: (_) => onRecipeTap(),
              showTitle: false,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'tapping bookmark saves recipe and does not open recipe detail',
    (tester) async {
      final favorites = _FakeFavoritesRepository();
      var openCount = 0;

      await tester.pumpWidget(
        buildSection(
          onRecipeTap: () => openCount++,
          favorites: favorites,
          userId: 'user-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(favorites.toggleCallCount, 1);
      expect(favorites.lastRecipeId, 'pop-adobo');
      expect(favorites.lastUserId, 'user-1');
      expect(openCount, 0);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.text('Recipe saved'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping bookmark again unsaves without opening recipe detail',
    (tester) async {
      final favorites = _FakeFavoritesRepository()..isCurrentlySaved = true;
      var openCount = 0;

      await tester.pumpWidget(
        buildSection(
          onRecipeTap: () => openCount++,
          favorites: favorites,
          userId: 'user-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(favorites.toggleCallCount, 1);
      expect(openCount, 0);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.text('Recipe removed from saved'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping card body still opens recipe detail',
    (tester) async {
      final favorites = _FakeFavoritesRepository();
      var openCount = 0;

      await tester.pumpWidget(
        buildSection(
          onRecipeTap: () => openCount++,
          favorites: favorites,
          userId: 'user-1',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Chicken Adobo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(openCount, 1);
      expect(favorites.toggleCallCount, 0);
    },
  );

  testWidgets(
    'signed-out user sees sign-in message and does not open recipe',
    (tester) async {
      final favorites = _FakeFavoritesRepository();
      var openCount = 0;

      await tester.pumpWidget(
        buildSection(
          onRecipeTap: () => openCount++,
          favorites: favorites,
          userId: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(favorites.toggleCallCount, 0);
      expect(openCount, 0);
      expect(find.text('Sign in to save recipes'), findsOneWidget);
    },
  );
}
