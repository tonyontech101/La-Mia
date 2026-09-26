import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/domain/recipe_filters.dart';

RecipeModel _recipe({
  String name = 'Test Dish',
  String category = 'Ulam',
  String description = '',
  String prepTime = '10 mins',
  String cookTime = '20 mins',
  int servings = 4,
  String difficulty = 'Easy',
  List<String> tags = const [],
  String? budget,
  List<String> ingredients = const ['a', 'b'],
}) {
  return RecipeModel(
    name: name,
    category: category,
    region: 'Tagalog',
    description: description,
    prepTime: prepTime,
    cookTime: cookTime,
    servings: servings,
    difficulty: difficulty,
    ingredients: ingredients,
    instructions: const ['cook'],
    tags: tags,
    coverPhotoUrl: '',
    source: '',
    budget: budget,
  );
}

void main() {
  group('RecipeModel.parseMinutes', () {
    test('parses hour + minute strings', () {
      expect(RecipeModel.parseMinutes('1 hr 30 mins'), 90);
      expect(RecipeModel.parseMinutes('2 hours'), 120);
      expect(RecipeModel.parseMinutes('45 mins'), 45);
      expect(RecipeModel.parseMinutes('30'), 30);
      expect(RecipeModel.parseMinutes('1h30m'), 90);
    });

    test('returns null for empty or non-numeric', () {
      expect(RecipeModel.parseMinutes(null), isNull);
      expect(RecipeModel.parseMinutes(''), isNull);
      expect(RecipeModel.parseMinutes('quick'), isNull);
    });

    test('fromFirestore prefers seeded cookTimeMin over string', () {
      final model = RecipeModel.fromFirestore(
        {
          'name': 'Adobo',
          'category': 'Ulam',
          'prepTime': '99 mins',
          'cookTime': '99 mins',
          'prepTimeMin': 15,
          'cookTimeMin': 30,
          'servings': 4,
          'difficulty': 'Easy',
          'ingredients': ['pork'],
          'instructions': ['simmer'],
          'tags': const [],
        },
        docId: 'x',
      );
      expect(model.prepTimeMin, 15);
      expect(model.cookTimeMin, 30);
      expect(model.totalMinutes, 45);
    });

    test('totalMinutes falls back to string parsing', () {
      final model = _recipe(prepTime: '15 mins', cookTime: '1 hr');
      expect(model.totalMinutes, 75);
    });
  });

  group('RecipeFilters.mealTypeMatches', () {
    test('Any always matches', () {
      expect(RecipeFilters.mealTypeMatches(_recipe(), 'Any'), isTrue);
    });

    test('Lunch includes sabaw, gulay, inihaw, lamang dagat', () {
      for (final cat in ['Sabaw', 'Gulay', 'Inihaw', 'Lamang Dagat', 'Ulam']) {
        expect(
          RecipeFilters.mealTypeMatches(_recipe(category: cat), 'Lunch'),
          isTrue,
          reason: cat,
        );
      }
    });

    test('Breakfast matches almusal and silog names', () {
      expect(
        RecipeFilters.mealTypeMatches(_recipe(category: 'Almusal'), 'Breakfast'),
        isTrue,
      );
      expect(
        RecipeFilters.mealTypeMatches(_recipe(name: 'Tapsilog'), 'Breakfast'),
        isTrue,
      );
    });

    test('Snacks matches merienda/panghimagas/pulutan', () {
      for (final cat in ['Merienda', 'Panghimagas', 'Pulutan']) {
        expect(
          RecipeFilters.mealTypeMatches(_recipe(category: cat), 'Snacks'),
          isTrue,
        );
      }
    });

    test('Drinks matches beverage keywords in name/tags only', () {
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(name: 'Calamansi Juice', category: 'Merienda'),
          'Drinks',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(name: 'Steamed Fish', category: 'Ulam'),
          'Drinks',
        ),
        isFalse,
        reason: '"steam" must not match keyword "tea"',
      );
      expect(
        RecipeFilters.mealTypeMatches(_recipe(name: 'Chicken Adobo'), 'Drinks'),
        isFalse,
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Something',
            category: 'Ulam',
            description: 'Serve with a cold drink on the side.',
          ),
          'Drinks',
        ),
        isFalse,
        reason: 'description must not decide Drinks',
      );
    });

    test('Sauces matches sauce keywords in name only', () {
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(name: 'Toyomansi Sauce', category: 'Ulam'),
          'Sauces',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Chicken Adobo',
            category: 'Ulam',
            tags: const ['sauce', 'soy sauce'],
          ),
          'Sauces',
        ),
        isFalse,
        reason: 'sauce tag must not pull Adobo into Sauces',
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Pork Asado',
            category: 'Ulam',
            tags: const ['sarsa', 'sauce'],
          ),
          'Sauces',
        ),
        isFalse,
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Bangus Sardinas',
            category: 'Lamang Dagat',
            tags: const ['sauce', 'patis'],
          ),
          'Sauces',
        ),
        isFalse,
      );
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Chicken Adobo',
            category: 'Ulam',
            description: 'Simmer chicken in soy sauce until glossy.',
          ),
          'Sauces',
        ),
        isFalse,
        reason: 'description mentioning sauce must not pull in ulam',
      );
      expect(
        RecipeFilters.mealTypeMatches(_recipe(name: 'Sinigang'), 'Sauces'),
        isFalse,
      );
    });

    test('Breakfast does not match eggplant via description', () {
      expect(
        RecipeFilters.mealTypeMatches(
          _recipe(
            name: 'Tortang Eggplant',
            category: 'Ulam',
            description: 'An eggplant omelette.',
          ),
          'Breakfast',
        ),
        isFalse,
      );
    });
  });

  group('RecipeFilters budget tiers', () {
    test('Any matches everything', () {
      expect(RecipeFilters.budgetMatches(_recipe(), 'Any'), isTrue);
    });

    test('null budget counts as Budget friendly (tier 0)', () {
      expect(RecipeFilters.budgetTier(_recipe(budget: null)), 0);
      expect(
        RecipeFilters.budgetMatches(
          _recipe(budget: null),
          '< ₱150 (Budget friendly)',
        ),
        isTrue,
      );
      expect(
        RecipeFilters.budgetMatches(
          _recipe(budget: null),
          '> ₱500 (Quite Expensive)',
        ),
        isFalse,
      );
    });

    test('maps chip labels to tiers', () {
      expect(RecipeFilters.budgetTierFromOption('Any'), isNull);
      expect(RecipeFilters.budgetTierFromOption('< ₱150 (Budget friendly)'), 0);
      expect(RecipeFilters.budgetTierFromOption('~ ₱150 - ₱300 (Affordable)'), 1);
      expect(RecipeFilters.budgetTierFromOption('~ ₱300 - ₱500 (Special)'), 2);
      expect(RecipeFilters.budgetTierFromOption('> ₱500 (Quite Expensive)'), 3);
    });

    test('recipe budget strings map to matching tiers', () {
      expect(RecipeFilters.budgetTier(_recipe(budget: 'Affordable')), 1);
      expect(RecipeFilters.budgetTier(_recipe(budget: 'Special')), 2);
      expect(RecipeFilters.budgetTier(_recipe(budget: 'Quite Expensive')), 3);
      expect(
        RecipeFilters.budgetMatches(
          _recipe(budget: 'Affordable'),
          '~ ₱150 - ₱300 (Affordable)',
        ),
        isTrue,
      );
    });
  });

  group('RecipeFilters difficulty / time / servings', () {
    test('difficulty Any and case-insensitive match', () {
      expect(RecipeFilters.difficultyMatches(_recipe(), 'Any'), isTrue);
      expect(
        RecipeFilters.difficultyMatches(_recipe(difficulty: 'Easy'), 'easy'),
        isTrue,
      );
      expect(
        RecipeFilters.difficultyMatches(_recipe(difficulty: 'Easy'), 'Hard'),
        isFalse,
      );
    });

    test('time limit uses totalMinutes', () {
      final r = _recipe(prepTime: '15 mins', cookTime: '20 mins');
      expect(RecipeFilters.timeMatches(r, null), isTrue);
      expect(RecipeFilters.timeMatches(r, 35), isTrue);
      expect(RecipeFilters.timeMatches(r, 34), isFalse);
    });

    test('servings is a max cap', () {
      final r = _recipe(servings: 6);
      expect(RecipeFilters.servingsMatches(r, null), isTrue);
      expect(RecipeFilters.servingsMatches(r, 6), isTrue);
      expect(RecipeFilters.servingsMatches(r, 4), isFalse);
    });
  });
}
