import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/presentation/notifiers/recipe_form_notifier.dart';

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

  group('RecipeModel ChefsTips Serialization Tests', () {
    test('fromFirestore parses chefsTips correctly', () {
      final docData = {
        'name': 'Kare-Kare',
        'category': 'Ulam',
        'region': 'Kapampangan',
        'prepTime': '20 mins',
        'cookTime': '60 mins',
        'servings': 6,
        'difficulty': 'Medium',
        'ingredients': ['Oxtail', 'Peanut Butter'],
        'instructions': ['Simmer oxtail until tender'],
        'chefsTips': [
          'Toast the rice powder until fragrant before mixing.',
          'Serve with warm bagoong on the side.',
        ],
        'tags': ['kare-kare'],
        'coverPhotoUrl': 'http://karekare.jpg',
        'source': '',
      };

      final model = RecipeModel.fromFirestore(docData, docId: 'recipe_kare');
      expect(model.chefsTips.length, 2);
      expect(model.chefsTips[0], 'Toast the rice powder until fragrant before mixing.');
      expect(model.chefsTips[1], 'Serve with warm bagoong on the side.');
    });

    test('toFirestore and toFirestoreForCreate serialize chefsTips correctly', () {
      final model = RecipeModel(
        name: 'Adobo',
        category: 'Ulam',
        region: 'Tagalog',
        prepTime: '15 mins',
        cookTime: '30 mins',
        servings: 4,
        difficulty: 'Easy',
        ingredients: ['Pork'],
        instructions: ['Cook'],
        chefsTips: ['Marinate overnight for richer flavor.'],
        tags: ['adobo'],
        coverPhotoUrl: '',
        source: '',
      );

      final data = model.toFirestore();
      expect(data['chefsTips'], ['Marinate overnight for richer flavor.']);

      final createData = model.toFirestoreForCreate();
      expect(createData['chefsTips'], ['Marinate overnight for richer flavor.']);
    });

    test('fromLocalJson parses chefs_tips with fallback', () {
      final json = {
        'name': 'Pancit',
        'category': 'Meryenda',
        'prep_time': '15 mins',
        'cook_time': '20 mins',
        'servings': 4,
        'difficulty': 'Easy',
        'ingredients': ['Noodles'],
        'instructions': ['Stir fry'],
        'chefs_tips': ['Use calamansi juice to brighten the flavor.'],
        'tags': ['noodles'],
      };

      final model = RecipeModel.fromLocalJson(json, coverPhotoUrl: 'http://pancit.jpg');
      expect(model.chefsTips, ['Use calamansi juice to brighten the flavor.']);
    });
  });

  group('RecipeFormState copyWith image preservation', () {
    test('preserves selectedImageFile when updating currentStep or other fields', () {
      final dummyFile = File('dummy_dish.jpg');
      final state = RecipeFormState(
        name: 'Adobo',
        selectedImageFile: dummyFile,
        currentStep: 1,
      );

      // Advance step as done in nextStep()
      final nextState = state.copyWith(currentStep: 2);

      expect(nextState.selectedImageFile, equals(dummyFile),
          reason: 'selectedImageFile must not be wiped out when advancing steps');
      expect(nextState.currentStep, 2);
    });

    test('preserves coverPhotoUrl when updating fields', () {
      const url = 'https://example.com/cover.jpg';
      final state = RecipeFormState(
        name: 'Sinigang',
        coverPhotoUrl: url,
        currentStep: 1,
      );

      final nextState = state.copyWith(currentStep: 2);

      expect(nextState.coverPhotoUrl, equals(url),
          reason: 'coverPhotoUrl must not be wiped out when advancing steps');
    });
  });

  group('Recipe Moderation and Rejection filtering tests', () {
    test('RecipeModel parses rejected status correctly', () {
      final data = {
        'name': 'isa ka laptop',
        'category': 'Ulam',
        'region': 'Philippines',
        'prepTime': '10 mins',
        'cookTime': '20 mins',
        'servings': 4,
        'difficulty': 'Easy',
        'ingredients': ['laptop'],
        'instructions': ['turn on'],
        'tags': ['gadget'],
        'coverPhotoUrl': 'https://example.com/laptop.jpg',
        'source': '',
        'status': 'rejected',
        'rejectionReason': 'Content rejected: Title is about a laptop, which is not food.',
      };

      final model = RecipeModel.fromFirestore(data, docId: 'fake_laptop_id');
      expect(model.status, 'rejected');
    });

    test('Recipe filtering strictly omits rejected recipes from published lists', () {
      final recipes = [
        RecipeModel(
          id: '1',
          name: 'Pork Adobo',
          category: 'Ulam',
          region: 'Tagalog',
          prepTime: '15 mins',
          cookTime: '30 mins',
          servings: 4,
          difficulty: 'Easy',
          ingredients: ['Pork'],
          instructions: ['Cook'],
          tags: ['adobo'],
          coverPhotoUrl: '',
          source: '',
          authorId: 'user_123',
          isSystemRecipe: false,
          status: 'approved',
        ),
        RecipeModel(
          id: '2',
          name: 'isa ka laptop',
          category: 'Ulam',
          region: 'Philippines',
          prepTime: '5 mins',
          cookTime: '5 mins',
          servings: 1,
          difficulty: 'Easy',
          ingredients: ['battery'],
          instructions: ['plug in'],
          tags: ['tech'],
          coverPhotoUrl: '',
          source: '',
          authorId: 'user_123',
          isSystemRecipe: false,
          status: 'rejected',
        ),
        RecipeModel(
          id: '3',
          name: 'Pending Sinigang',
          category: 'Sabaw',
          region: 'Tagalog',
          prepTime: '10 mins',
          cookTime: '25 mins',
          servings: 4,
          difficulty: 'Medium',
          ingredients: ['Pork', 'Tamarind'],
          instructions: ['Boil'],
          tags: ['sour'],
          coverPhotoUrl: '',
          source: '',
          authorId: 'user_123',
          isSystemRecipe: false,
          status: 'pending',
        ),
      ];

      // Simulated public view (includePending: false)
      final publicRecipes = recipes.where((r) {
        if (r.status == 'rejected') return false;
        return r.status == 'approved' || r.isSystemRecipe;
      }).toList();

      expect(publicRecipes.map((r) => r.name), ['Pork Adobo']);
      expect(publicRecipes.any((r) => r.status == 'rejected'), isFalse);

      // Simulated author profile view (includePending: true)
      final authorProfileRecipes = recipes.where((r) {
        if (r.status == 'rejected') return false;
        return r.status == 'approved' || r.status == 'pending' || r.isSystemRecipe;
      }).toList();

      expect(authorProfileRecipes.map((r) => r.name), ['Pork Adobo', 'Pending Sinigang']);
      expect(authorProfileRecipes.any((r) => r.status == 'rejected'), isFalse);
    });
  });
}
