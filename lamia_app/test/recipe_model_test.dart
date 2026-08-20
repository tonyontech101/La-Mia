import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';

void main() {
  group('RecipeModel Budget Serialization Tests', () {
    test('fromFirestore parses budget correctly', () {
      final docData = {
        'name': 'Chicken Adobo',
        'category': 'Ulam',
        'region': 'Tagalog',
        'prepTime': '15 mins',
        'cookTime': '30 mins',
        'servings': 4,
        'difficulty': 'Easy',
        'ingredients': ['Chicken', 'Soy Sauce', 'Vinegar'],
        'instructions': ['Cook it'],
        'tags': ['adobo'],
        'coverPhotoUrl': 'http://image.jpg',
        'source': '',
        'authorId': 'chef123',
        'authorName': 'Chef Boy Logro',
        'isSystemRecipe': false,
        'budget': 'Affordable',
      };

      final model = RecipeModel.fromFirestore(docData, docId: 'recipe_abc');

      expect(model.id, 'recipe_abc');
      expect(model.name, 'Chicken Adobo');
      expect(model.budget, 'Affordable');
    });

    test('toFirestore serializes budget correctly', () {
      final model = RecipeModel(
        name: 'Sinigang',
        category: 'Ulam',
        region: 'Any region',
        prepTime: '20 mins',
        cookTime: '40 mins',
        servings: 6,
        difficulty: 'Medium',
        ingredients: ['Pork', 'Tamarind'],
        instructions: ['Boil'],
        tags: ['sour'],
        coverPhotoUrl: '',
        source: '',
        budget: 'Budget friendly',
      );

      final data = model.toFirestore();
      expect(data['budget'], 'Budget friendly');
    });

    test('fromLocalJson parses budget correctly with default fallback', () {
      final json = {
        'name': 'Lechon',
        'category': 'Ulam',
        'prep_time': '30 mins',
        'cook_time': '120 mins',
        'servings': 12,
        'difficulty': 'Hard',
        'ingredients': ['Whole pig'],
        'instructions': ['Roast'],
        'tags': ['feast'],
      };

      final model = RecipeModel.fromLocalJson(json, coverPhotoUrl: 'http://lechon.jpg');
      expect(model.budget, 'Budget friendly'); // Default fallback
    });

    test('approximation getters return formatted relational values', () {
      final fastModel = RecipeModel(
        name: 'Quick Egg',
        category: 'Almusal',
        region: 'Tagalog',
        prepTime: '5 mins',
        cookTime: '10 mins',
        servings: 1,
        difficulty: 'Easy',
        ingredients: ['Egg'],
        instructions: ['Fry'],
        tags: ['egg'],
        coverPhotoUrl: '',
        source: '',
        budget: 'Budget friendly',
      );

      expect(fastModel.approximatePrepTime, '< 10 mins');
      expect(fastModel.approximateCookTime, '< 15 mins');
      expect(fastModel.approximateServings, '< 2 servings');
      expect(fastModel.approximateBudget, '< ₱150 (Budget friendly)');

      final slowFeastModel = RecipeModel(
        name: 'Slow Roast Pig',
        category: 'Inihaw',
        region: 'Cebuano',
        prepTime: '45 mins',
        cookTime: '180 mins',
        servings: 10,
        difficulty: 'Hard',
        ingredients: ['Pork'],
        instructions: ['Roast'],
        tags: ['roast'],
        coverPhotoUrl: '',
        source: '',
        budget: 'Quite Expensive',
      );

      expect(slowFeastModel.approximatePrepTime, '> 30 mins');
      expect(slowFeastModel.approximateCookTime, '> 1 hr');
      expect(slowFeastModel.approximateServings, '> 8 servings');
      expect(slowFeastModel.approximateBudget, '> ₱500 (Quite Expensive)');
    });
  });
}
