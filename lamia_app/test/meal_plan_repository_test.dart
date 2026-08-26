import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lamia_app/features/planner/data/meal_plan_model.dart';
import 'package:lamia_app/features/planner/data/meal_plan_repository.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';

class MockUser implements User {
  @override
  String get uid => 'mock_user_123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements FirebaseAuth {
  MockFirebaseAuth({this.mockUser});
  final User? mockUser;

  @override
  User? get currentUser => mockUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MealPlanRepository Unit & Logic Tests', () {
    test('formatWeekId and formatDateKey return correct formats', () {
      final date = DateTime(2026, 8, 24); // A Monday
      expect(MealPlanRepository.formatWeekId(date), 'week_2026_08_24');
      expect(MealPlanRepository.formatDateKey(date), '2026-08-24');
    });

    test('getWeeklyPlan in guest/offline mode returns a blank plan and caches it', () async {
      final mockAuth = MockFirebaseAuth(mockUser: null);
      final mockFirestore = MockFirebaseFirestore();
      final repo = MealPlanRepository(firestore: mockFirestore, auth: mockAuth);
      final date = DateTime(2026, 8, 24);

      final plan = await repo.getWeeklyPlan(date);
      expect(plan.weekId, 'week_2026-08-24');
      expect(plan.days.length, 7);

      // Verify subsequent calls return cached plan
      final cachedPlan = await repo.getWeeklyPlan(date);
      expect(identical(plan, cachedPlan), isTrue);
    });

    test('assignMealSlot assigns a recipe to a slot and updates cache', () async {
      final mockAuth = MockFirebaseAuth(mockUser: null);
      final mockFirestore = MockFirebaseFirestore();
      final repo = MealPlanRepository(firestore: mockFirestore, auth: mockAuth);
      final date = DateTime(2026, 8, 31); // Different week to avoid cache pollution
      final plan = await repo.getWeeklyPlan(date);

      final recipe = RecipeModel(
        id: 'rec_adobo',
        name: 'Chicken Adobo',
        category: 'Ulam',
        region: 'National',
        prepTime: '15 mins',
        cookTime: '30 mins',
        servings: 4,
        difficulty: 'Easy',
        ingredients: ['Chicken', 'Soy Sauce', 'Vinegar'],
        instructions: ['Simmer everything'],
        tags: ['chicken', 'adobo'],
        coverPhotoUrl: 'http://example.com/adobo.jpg',
        source: '',
      );

      final dateKey = MealPlanRepository.formatDateKey(date);
      final updated = await repo.assignMealSlot(
        currentPlan: plan,
        dateKey: dateKey,
        slot: 'lunch',
        recipe: recipe,
      );

      expect(updated.days[dateKey]?.lunch, isNotNull);
      expect(updated.days[dateKey]?.lunch?.recipeId, 'rec_adobo');
      expect(updated.days[dateKey]?.lunch?.recipeName, 'Chicken Adobo');
    });

    test('removeMealSlot clears the slot and updates cache', () async {
      final mockAuth = MockFirebaseAuth(mockUser: null);
      final mockFirestore = MockFirebaseFirestore();
      final repo = MealPlanRepository(firestore: mockFirestore, auth: mockAuth);
      final date = DateTime(2026, 9, 7); // Different week to avoid cache pollution
      final plan = await repo.getWeeklyPlan(date);

      final recipe = RecipeModel(
        id: 'rec_tapsi',
        name: 'Tapsilog',
        category: 'Almusal',
        region: 'Luzon',
        prepTime: '10 mins',
        cookTime: '10 mins',
        servings: 1,
        difficulty: 'Easy',
        ingredients: ['Beef', 'Rice', 'Egg'],
        instructions: ['Fry'],
        tags: ['breakfast'],
        coverPhotoUrl: '',
        source: '',
      );

      final dateKey = MealPlanRepository.formatDateKey(date);
      await repo.assignMealSlot(
        currentPlan: plan,
        dateKey: dateKey,
        slot: 'breakfast',
        recipe: recipe,
      );

      expect(plan.days[dateKey]?.breakfast, isNotNull);

      final updated = await repo.removeMealSlot(
        currentPlan: plan,
        dateKey: dateKey,
        slot: 'breakfast',
      );

      expect(updated.days[dateKey]?.breakfast, isNull);
    });

    test('clearWeek empties all meals in the week', () async {
      final mockAuth = MockFirebaseAuth(mockUser: null);
      final mockFirestore = MockFirebaseFirestore();
      final repo = MealPlanRepository(firestore: mockFirestore, auth: mockAuth);
      final date = DateTime(2026, 9, 14); // Different week to avoid cache pollution
      final plan = await repo.getWeeklyPlan(date);

      final recipe = RecipeModel(
        id: '1',
        name: 'Fried Rice',
        category: 'Almusal',
        region: 'National',
        prepTime: '5 mins',
        cookTime: '10 mins',
        servings: 2,
        difficulty: 'Easy',
        ingredients: ['Rice', 'Garlic'],
        instructions: ['Stir-fry'],
        tags: [],
        coverPhotoUrl: '',
        source: '',
      );

      final dateKey = MealPlanRepository.formatDateKey(date);
      await repo.assignMealSlot(
        currentPlan: plan,
        dateKey: dateKey,
        slot: 'breakfast',
        recipe: recipe,
      );

      final cleared = await repo.clearWeek(date);
      expect(cleared.days[dateKey]?.breakfast, isNull);
    });

    test('generateGroceryList aggregates ingredients and removes duplicates', () async {
      final mockAuth = MockFirebaseAuth(mockUser: null);
      final mockFirestore = MockFirebaseFirestore();
      final repo = MealPlanRepository(firestore: mockFirestore, auth: mockAuth);
      final date = DateTime(2026, 9, 21); // Different week to avoid cache pollution
      final plan = await repo.getWeeklyPlan(date);

      final r1 = RecipeModel(
        id: '1',
        name: 'Dish A',
        category: 'Ulam',
        region: '',
        prepTime: '',
        cookTime: '',
        servings: 4,
        difficulty: 'Easy',
        ingredients: ['Onion', 'Garlic', 'Pork'],
        instructions: [],
        tags: [],
        coverPhotoUrl: '',
        source: '',
      );

      final r2 = RecipeModel(
        id: '2',
        name: 'Dish B',
        category: 'Ulam',
        region: '',
        prepTime: '',
        cookTime: '',
        servings: 4,
        difficulty: 'Easy',
        ingredients: ['Onion', 'Tomato', 'Fish'],
        instructions: [],
        tags: [],
        coverPhotoUrl: '',
        source: '',
      );

      final dateKey = MealPlanRepository.formatDateKey(date);
      await repo.assignMealSlot(currentPlan: plan, dateKey: dateKey, slot: 'lunch', recipe: r1);
      await repo.assignMealSlot(currentPlan: plan, dateKey: dateKey, slot: 'dinner', recipe: r2);

      final list = repo.generateGroceryList(plan);
      expect(list.length, 5); // Garlic, Onion, Pork, Tomato, Fish (duplicates merged)
      expect(list.contains('Onion'), isTrue);
      expect(list.where((item) => item == 'Onion').length, 1);
    });
  });
}
