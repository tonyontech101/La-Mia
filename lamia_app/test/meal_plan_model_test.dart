import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/planner/data/meal_plan_model.dart';
import 'package:lamia_app/features/planner/data/meal_plan_repository.dart';

void main() {
  group('MealPlanItem Serialization Tests', () {
    test('toMap and fromMap work symmetrically', () {
      const item = MealPlanItem(
        recipeId: 'rec_123',
        recipeName: 'Pork Sinigang',
        coverPhotoUrl: 'http://image.jpg',
        category: 'Ulam',
        prepTime: '15 mins',
        cookTime: '35 mins',
        servings: 4,
        ingredients: ['Pork', 'Tamarind', 'Kangkong'],
        notes: 'Extra sour',
      );

      final map = item.toMap();
      expect(map['recipeId'], 'rec_123');
      expect(map['recipeName'], 'Pork Sinigang');
      expect(map['ingredients'], ['Pork', 'Tamarind', 'Kangkong']);

      final restored = MealPlanItem.fromMap(map);
      expect(restored.recipeId, 'rec_123');
      expect(restored.recipeName, 'Pork Sinigang');
      expect(restored.ingredients.length, 3);
      expect(restored.notes, 'Extra sour');
    });
  });

  group('MealPlanDay and WeeklyMealPlanModel Tests', () {
    test('MealPlanDay counts total meals correctly', () {
      final day = MealPlanDay(dateKey: '2026-08-24', dayOfWeek: 'Monday');
      expect(day.isEmpty, isTrue);
      expect(day.totalMealsCount, 0);

      day.breakfast = const MealPlanItem(
        recipeId: '1',
        recipeName: 'Tapsilog',
        coverPhotoUrl: '',
        category: 'Almusal',
      );
      day.lunch = const MealPlanItem(
        recipeId: '2',
        recipeName: 'Adobo',
        coverPhotoUrl: '',
        category: 'Ulam',
      );

      expect(day.isEmpty, isFalse);
      expect(day.totalMealsCount, 2);
    });

    test('WeeklyMealPlanModel empty creates all 7 days', () {
      final monday = DateTime(2026, 8, 24);
      final plan = WeeklyMealPlanModel.empty(mondayDate: monday);

      expect(plan.days.length, 7);
      expect(plan.days.containsKey('2026-08-24'), isTrue); // Monday
      expect(plan.days.containsKey('2026-08-30'), isTrue); // Sunday
    });

    test('MealPlanRepository helper methods compute Monday correctly', () {
      // Wednesday Aug 26, 2026
      final wednesday = DateTime(2026, 8, 26);
      final monday = MealPlanRepository.getMondayOf(wednesday);

      expect(monday.weekday, DateTime.monday);
      expect(monday.day, 24);
      expect(monday.month, 8);
      expect(monday.year, 2026);
    });

    test('MealPlanRepository generates unique grocery list from assigned recipes', () {
      final monday = DateTime(2026, 8, 24);
      final plan = WeeklyMealPlanModel.empty(mondayDate: monday);
      final repo = MealPlanRepository();

      plan.days['2026-08-24']!.breakfast = const MealPlanItem(
        recipeId: '1',
        recipeName: 'Eggs',
        coverPhotoUrl: '',
        category: 'Almusal',
        ingredients: ['Eggs', 'Garlic', 'Rice'],
      );

      plan.days['2026-08-24']!.lunch = const MealPlanItem(
        recipeId: '2',
        recipeName: 'Adobo',
        coverPhotoUrl: '',
        category: 'Ulam',
        ingredients: ['Pork', 'Soy Sauce', 'Vinegar', 'Garlic'],
      );

      final groceryList = repo.generateGroceryList(plan);
      expect(groceryList.contains('Garlic'), isTrue);
      expect(groceryList.contains('Eggs'), isTrue);
      expect(groceryList.contains('Soy Sauce'), isTrue);
      // 'Garlic' should only appear once despite being in both dishes
      expect(groceryList.where((i) => i == 'Garlic').length, 1);
    });

    test('WeeklyMealPlanModel.fromFirestore handles dynamic and untyped nested maps from Firestore', () {
      final monday = DateTime(2026, 8, 24);
      final rawFirestoreData = <dynamic, dynamic>{
        'weekId': 'week_2026_08_24',
        'days': <dynamic, dynamic>{
          '2026-08-24': <dynamic, dynamic>{
            'dateKey': '2026-08-24',
            'dayOfWeek': 'Monday',
            'breakfast': <dynamic, dynamic>{
              'recipeId': 'rec_1',
              'recipeName': 'Sinangag with Egg',
              'coverPhotoUrl': 'https://example.com/egg.jpg',
              'category': 'Almusal',
              'prepTime': '10m',
              'cookTime': '10m',
              'servings': 2,
              'ingredients': <dynamic>['Rice', 'Egg'],
              'notes': 'Yum',
            },
            'lunch': null,
            'dinner': null,
            'snack': null,
          }
        }
      };

      final plan = WeeklyMealPlanModel.fromFirestore(
        Map<String, dynamic>.from(rawFirestoreData),
        weekId: 'week_2026_08_24',
        startDate: monday,
      );

      expect(plan.days['2026-08-24']?.breakfast, isNotNull);
      expect(plan.days['2026-08-24']?.breakfast?.recipeName, 'Sinangag with Egg');
      expect(plan.days['2026-08-24']?.breakfast?.ingredients, ['Rice', 'Egg']);
    });
  });
}
