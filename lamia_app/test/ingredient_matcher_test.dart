// Unit tests for `computeIngredientMatches`.
//
// Pure-function tests (no Firebase, no widget tree) for the token-based
// ingredient matcher. The most important coverage here is the *regression*
// set: the previous (substring `.contains`) implementation spuriously
// matched "rice" vs "rice flour" / "price", and "egg" vs "eggplant". The
// token-based matcher should reject those.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/domain/ingredient_matched_recipe.dart';
import 'package:lamia_app/features/recipes/domain/ingredient_matcher.dart';

RecipeModel _recipe({
  required String name,
  List<String> ingredients = const [],
}) {
  return RecipeModel(
    name: name,
    category: 'Ulam',
    region: 'Unknown',
    prepTime: '10 mins',
    cookTime: '20 mins',
    servings: 4,
    difficulty: 'Easy',
    ingredients: ingredients,
    instructions: const [],
    tags: const [],
    coverPhotoUrl: '',
    source: '',
  );
}

void main() {
  group('computeIngredientMatches', () {
    test('returns empty for an empty tag list', () {
      final recipes = [
        _recipe(name: 'Adobo', ingredients: ['chicken']),
      ];
      expect(computeIngredientMatches(recipes, []), isEmpty);
    });

    test('returns empty when no recipes match any tag', () {
      final recipes = [
        _recipe(name: 'Adobo', ingredients: ['chicken', 'vinegar']),
      ];
      expect(computeIngredientMatches(recipes, ['beef']), isEmpty);
    });

    test('matches when an ingredient token exactly equals the tag', () {
      final recipes = [
        _recipe(
          name: 'Adobo',
          ingredients: ['chicken', 'vinegar', 'soy sauce'],
        ),
      ];
      final result = computeIngredientMatches(recipes, ['chicken']);
      expect(result, hasLength(1));
      expect(result.first.recipe.name, 'Adobo');
      expect(result.first.matchedCount, 1);
      // 1 of 3 matched -> 33% (clamped to >=1).
      expect(result.first.matchPercentage, 33);
    });

    test(
      'does NOT match single-token tags against *unrelated* substrings (regression)',
      () {
        // The old substring-contains matcher returned true for:
        //   "rice" .contains("rice")  -> rice flour,
        //   "price" .contains("rice") -> price.
        // The token-based matcher still matches "rice" against "rice flour"
        // (the recipe DOES use rice, just with flour), but it must NOT match
        // "price" — "price" is a single unrelated token, not "rice".
        final recipes = [
          _recipe(name: 'Rice Flour Cake', ingredients: ['rice flour']),
          _recipe(name: 'Pricey Dish', ingredients: ['price']),
          _recipe(name: 'Real Rice', ingredients: ['rice']),
        ];

        final result = computeIngredientMatches(recipes, ['rice']);

        // Both "rice flour" and "rice" contain the "rice" token — they
        // legitimately match. "Pricey Dish" must NOT match.
        expect(result, hasLength(2));
        final names = result.map((m) => m.recipe.name).toSet();
        expect(names, contains('Real Rice'));
        expect(names, contains('Rice Flour Cake'));
        expect(names, isNot(contains('Pricey Dish')));
      },
    );

    test('does NOT match "egg" against "eggplant" (regression)', () {
      final recipes = [
        _recipe(name: 'Eggplant Parm', ingredients: ['eggplant']),
        _recipe(name: 'Plain Eggs', ingredients: ['egg']),
      ];
      final result = computeIngredientMatches(recipes, ['egg']);
      expect(result, hasLength(1));
      expect(result.first.recipe.name, 'Plain Eggs');
    });

    test('multi-token tag requires strict majority in ingredient tokens', () {
      // "soy sauce" (2 tokens) should match ingredient "soy sauce" (shared
      // with both tokens => 2/2 = majority) and NOT "soy vinegar" (shared 1
      // of 2 = NOT a strict majority).
      final recipes = [
        _recipe(name: 'Soy Sauce Dish', ingredients: ['soy sauce']),
        _recipe(name: 'Soy Vinegar Mix', ingredients: ['soy vinegar']),
      ];
      final result = computeIngredientMatches(recipes, ['soy sauce']);
      expect(result, hasLength(1));
      expect(result.first.recipe.name, 'Soy Sauce Dish');
    });

    test('computes missing ingredients for partial matches', () {
      final recipes = [
        _recipe(
          name: 'Adobo',
          ingredients: ['chicken', 'vinegar', 'soy sauce', 'garlic'],
        ),
      ];
      final result = computeIngredientMatches(recipes, ['chicken', 'garlic']);
      expect(result.first.matchedCount, 2);
      expect(result.first.totalIngredients, 4);
      expect(result.first.matchPercentage, 50); // 2/4 = 50%
      expect(result.first.missingIngredients, ['vinegar', 'soy sauce']);
    });

    test('sorts results by match percentage descending, then matchedCount', () {
      final recipes = [
        _recipe(
          name: 'Three-match',
          ingredients: ['chicken', 'garlic', 'rice', 'extra'],
        ),
        _recipe(name: 'Two-match', ingredients: ['chicken', 'garlic', 'extra']),
        _recipe(
          name: 'Two-match-other',
          ingredients: ['chicken', 'garlic', 'extra'],
        ),
      ];
      final result = computeIngredientMatches(recipes, ['chicken', 'garlic']);
      // Two recipes both match 2 of 3 -> 67%. The other matches 2 of 4 -> 50%.
      expect(result.first.matchPercentage, 67);
      expect(result.last.matchPercentage, 50);
    });

    test('handles recipes with empty ingredients list without crashing', () {
      final recipes = [_recipe(name: 'No-Ing', ingredients: const [])];
      expect(computeIngredientMatches(recipes, ['rice']), isEmpty);
    });

    test('is case-insensitive on the tag inputs', () {
      final recipes = [
        _recipe(name: 'Rice', ingredients: ['rice']),
      ];
      expect(computeIngredientMatches(recipes, ['RICE']).first.matchedCount, 1);
      expect(computeIngredientMatches(recipes, ['Rice']).first.matchedCount, 1);
    });

    test('trims and splits a tag with internal punctuation', () {
      // "Soy Sauce" tokenizes to {"soy", "sauce"} — equal to ingredient
      // "soy sauce" tokens.
      final recipes = [
        _recipe(name: 'A', ingredients: ['soy sauce']),
      ];
      expect(
        computeIngredientMatches(recipes, ['  Soy  Sauce  ']),
        hasLength(1),
      );
    });

    test('AND logic: only returns dishes containing ALL selected ingredients', () {
      final recipes = [
        _recipe(
          name: 'Arroz Caldo',
          ingredients: ['chicken', 'garlic', 'rice', 'ginger'],
        ),
        _recipe(
          name: 'Chicken Adobo',
          ingredients: ['chicken', 'garlic', 'vinegar', 'soy sauce'],
        ),
        _recipe(
          name: 'Garlic Rice',
          ingredients: ['garlic', 'rice', 'oil'],
        ),
        _recipe(
          name: 'Plain Rice',
          ingredients: ['rice'],
        ),
      ];

      // Requires Chicken AND Garlic AND Rice
      final results = computeIngredientMatches(
        recipes,
        ['Chicken', 'Garlic', 'Rice'],
      );

      // Only Arroz Caldo has all three!
      expect(results, hasLength(1));
      expect(results.first.recipe.name, 'Arroz Caldo');
      expect(results.first.matchedCount, 3);
      expect(results.first.missingIngredients, ['ginger']);
    });

    test('AND logic: excludes recipe missing even one selected ingredient', () {
      final recipes = [
        _recipe(
          name: 'Pork Adobo',
          ingredients: ['pork', 'garlic', 'soy sauce', 'vinegar'],
        ),
      ];

      // User has Pork, Garlic, and Eggs -> Pork Adobo has no eggs!
      final results = computeIngredientMatches(
        recipes,
        ['Pork', 'Garlic', 'Eggs'],
      );

      expect(results, isEmpty);
    });

    test('matches singular and plural variations of ingredient names', () {
      final recipes = [
        _recipe(name: 'Egg Dish', ingredients: ['1 egg']),
        _recipe(name: 'Eggs Dish', ingredients: ['4 eggs']),
        _recipe(name: 'Tomato Dish', ingredients: ['1 tomato']),
        _recipe(name: 'Tomatoes Dish', ingredients: ['3 tomatoes']),
      ];

      // Tag 'Eggs' matches both '1 egg' and '4 eggs'
      final eggResults = computeIngredientMatches(recipes, ['Eggs']);
      expect(eggResults.map((r) => r.recipe.name).toSet(), {
        'Egg Dish',
        'Eggs Dish',
      });

      // Tag 'Tomato' matches both '1 tomato' and '3 tomatoes'
      final tomatoResults = computeIngredientMatches(recipes, ['Tomato']);
      expect(tomatoResults.map((r) => r.recipe.name).toSet(), {
        'Tomato Dish',
        'Tomatoes Dish',
      });
    });

    test('matches common Filipino culinary synonyms', () {
      final recipes = [
        _recipe(name: 'Fried Egg Tagalog', ingredients: ['itlog', 'mantika']),
        _recipe(name: 'Adobo Tagalog', ingredients: ['manok', 'bawang', 'toyo', 'suka']),
      ];

      // English tags match Tagalog ingredients
      final eggMatches = computeIngredientMatches(recipes, ['Egg', 'Cooking Oil']);
      expect(eggMatches, hasLength(1));
      expect(eggMatches.first.recipe.name, 'Fried Egg Tagalog');

      final adoboMatches = computeIngredientMatches(recipes, ['Chicken', 'Garlic']);
      expect(adoboMatches, hasLength(1));
      expect(adoboMatches.first.recipe.name, 'Adobo Tagalog');
    });
  });

  group('IngredientMatchedRecipe', () {
    test('defaults missingIngredients to an empty list', () {
      final recipe = _recipe(name: 'A');
      final m = IngredientMatchedRecipe(
        recipe: recipe,
        matchPercentage: 100,
        matchedCount: 3,
        totalIngredients: 3,
      );
      expect(m.missingIngredients, isEmpty);
      expect(m.recipe.name, 'A');
      expect(m.matchPercentage, 100);
    });
  });
}
