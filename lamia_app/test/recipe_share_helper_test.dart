import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/utils/recipe_share_helper.dart';

void main() {
  group('RecipeShareHelper', () {
    test('generateRecipeUrl returns standard web recipe URL', () {
      final url = RecipeShareHelper.generateRecipeUrl('sinigang-456');
      expect(url, 'https://la-mia-e348d.web.app/recipe/sinigang-456');
    });

    test('generateDeepLinkUrl returns custom scheme URI', () {
      final url = RecipeShareHelper.generateDeepLinkUrl('sinigang-456');
      expect(url, 'lamia://recipe/sinigang-456');
    });

    group('parseRecipeIdFromUri', () {
      test('parses custom scheme lamia://recipe/123', () {
        final uri = Uri.parse('lamia://recipe/adobo-789');
        final id = RecipeShareHelper.parseRecipeIdFromUri(uri);
        expect(id, 'adobo-789');
      });

      test('parses standard https://lamia.app/recipe/123', () {
        final uri = Uri.parse('https://lamia.app/recipe/adobo-789');
        final id = RecipeShareHelper.parseRecipeIdFromUri(uri);
        expect(id, 'adobo-789');
      });

      test('parses firebase hosting https://la-mia.web.app/recipe/123', () {
        final uri = Uri.parse('https://la-mia.web.app/recipe/adobo-789');
        final id = RecipeShareHelper.parseRecipeIdFromUri(uri);
        expect(id, 'adobo-789');
      });

      test('returns null for unrelated paths or hosts', () {
        expect(
          RecipeShareHelper.parseRecipeIdFromUri(Uri.parse('https://lamia.app/profile/user1')),
          isNull,
        );
        expect(
          RecipeShareHelper.parseRecipeIdFromUri(Uri.parse('https://google.com')),
          isNull,
        );
      });
    });

    test('generateShareText includes dish name, author, ingredients, and recipe URL', () {
      final recipe = RecipeModel(
        id: 'kare-kare-101',
        name: 'Classic Kare-Kare',
        authorName: 'Chef Maria',
        category: 'Filipino',
        region: 'Luzon',
        prepTime: '20 mins',
        cookTime: '90 mins',
        servings: 6,
        difficulty: 'Medium',
        tags: const ['beef', 'stew'],
        coverPhotoUrl: '',
        source: 'community',
        description: 'Rich peanut stew with oxtail.',
        ingredients: const ['1 kg oxtail', '1/2 cup peanut butter', 'Achuete oil'],
        instructions: const ['Boil meat until tender', 'Add peanut sauce', 'Simmer and serve'],
      );

      final text = RecipeShareHelper.generateShareText(
        recipe: recipe,
        authorName: 'Chef Maria',
      );

      expect(text, contains('Classic Kare-Kare'));
      expect(text, contains('Chef Maria'));
      expect(text, contains('https://la-mia-e348d.web.app/recipe/kare-kare-101'));
      expect(text, contains('La Mia'));
      // Verifies ingredients and instructions are NOT dumped in chat
      expect(text, isNot(contains('1 kg oxtail')));
      expect(text, isNot(contains('Boil meat until tender')));
    });

    test('generateShareText with linkOnly returns just the recipe URL', () {
      final recipe = RecipeModel(
        id: 'adobo-202',
        name: 'Chicken Adobo',
        authorName: 'Chef Jay',
        category: 'Filipino',
        region: 'Luzon',
        prepTime: '15 mins',
        cookTime: '35 mins',
        servings: 4,
        difficulty: 'Easy',
        tags: const ['chicken'],
        coverPhotoUrl: '',
        source: 'community',
        ingredients: const ['Chicken', 'Soy sauce'],
        instructions: const ['Simmer chicken in sauce'],
      );

      final text = RecipeShareHelper.generateShareText(
        recipe: recipe,
        authorName: 'Chef Jay',
        linkOnly: true,
      );

      expect(text, 'https://la-mia-e348d.web.app/recipe/adobo-202');
    });
  });
}
