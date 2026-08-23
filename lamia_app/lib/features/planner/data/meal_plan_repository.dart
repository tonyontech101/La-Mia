import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import 'meal_plan_model.dart';

/// Repository managing weekly meal plan persistence (Firestore),
/// smart auto-fill suggestions, and grocery list generation.
class MealPlanRepository {
  MealPlanRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    RecipeRepository? recipeRepo,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _customRecipeRepo = recipeRepo;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final RecipeRepository? _customRecipeRepo;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  RecipeRepository get _recipeRepo => _customRecipeRepo ?? RecipeRepository();

  // In-memory cache per session
  static final Map<String, WeeklyMealPlanModel> _memoryCache = {};

  /// Helper to calculate the Monday of the current week.
  static DateTime getMondayOf(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final daysToSubtract = (clean.weekday - DateTime.monday) % 7;
    return clean.subtract(Duration(days: daysToSubtract));
  }

  static String formatWeekId(DateTime monday) {
    final y = monday.year;
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return 'week_${y}_${m}_$d';
  }

  static String formatDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Fetches the weekly meal plan for a specific Monday date.
  /// Checks memory cache, then Firestore if signed in, or returns a fresh 7-day model.
  Future<WeeklyMealPlanModel> getWeeklyPlan(DateTime mondayDate) async {
    final weekId = formatWeekId(mondayDate);
    final user = _auth.currentUser;
    final cacheKey = '${user?.uid ?? "guest"}_$weekId';

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!;
    }

    if (user != null) {
      try {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('mealPlans')
            .doc(weekId);

        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          final plan = WeeklyMealPlanModel.fromFirestore(
            docSnap.data()!,
            weekId: weekId,
            startDate: mondayDate,
          );
          _memoryCache[cacheKey] = plan;
          return plan;
        }
      } catch (_) {
        // Fallback to memory or empty week
      }
    }

    final newPlan = WeeklyMealPlanModel.empty(mondayDate: mondayDate);
    _memoryCache[cacheKey] = newPlan;
    return newPlan;
  }

  /// Saves the updated weekly plan to Firestore and local memory cache.
  Future<void> saveWeeklyPlan(WeeklyMealPlanModel plan) async {
    final user = _auth.currentUser;
    final weekId = plan.weekId;
    final cacheKey = '${user?.uid ?? "guest"}_$weekId';

    _memoryCache[cacheKey] = plan;

    if (user != null) {
      try {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('mealPlans')
            .doc(weekId);

        await docRef.set(plan.toFirestore(), SetOptions(merge: true));
      } catch (_) {
        // Firestore rules or offline handling
      }
    }
  }

  /// Assigns a recipe to a specific meal slot in a day.
  Future<WeeklyMealPlanModel> assignMealSlot({
    required WeeklyMealPlanModel currentPlan,
    required String dateKey,
    required String slot, // 'breakfast', 'lunch', 'dinner', 'snack'
    required RecipeModel recipe,
  }) async {
    final item = MealPlanItem(
      recipeId: recipe.id ?? '',
      recipeName: recipe.name,
      coverPhotoUrl: recipe.coverPhotoUrl,
      category: recipe.category,
      prepTime: recipe.prepTime,
      cookTime: recipe.cookTime,
      servings: recipe.servings,
      ingredients: recipe.ingredients,
    );

    final day = currentPlan.days[dateKey] ??
        MealPlanDay(dateKey: dateKey, dayOfWeek: 'Day');

    switch (slot.toLowerCase()) {
      case 'breakfast':
      case 'almusal':
        day.breakfast = item;
        break;
      case 'lunch':
      case 'tanghalian':
        day.lunch = item;
        break;
      case 'dinner':
      case 'hapunan':
        day.dinner = item;
        break;
      case 'snack':
      case 'meryenda':
        day.snack = item;
        break;
    }

    currentPlan.days[dateKey] = day;
    await saveWeeklyPlan(currentPlan);
    return currentPlan;
  }

  /// Removes a recipe from a specific meal slot.
  Future<WeeklyMealPlanModel> removeMealSlot({
    required WeeklyMealPlanModel currentPlan,
    required String dateKey,
    required String slot,
  }) async {
    final day = currentPlan.days[dateKey];
    if (day == null) return currentPlan;

    switch (slot.toLowerCase()) {
      case 'breakfast':
      case 'almusal':
        day.breakfast = null;
        break;
      case 'lunch':
      case 'tanghalian':
        day.lunch = null;
        break;
      case 'dinner':
      case 'hapunan':
        day.dinner = null;
        break;
      case 'snack':
      case 'meryenda':
        day.snack = null;
        break;
    }

    currentPlan.days[dateKey] = day;
    await saveWeeklyPlan(currentPlan);
    return currentPlan;
  }

  /// Clears all meals for the week.
  Future<WeeklyMealPlanModel> clearWeek(DateTime mondayDate) async {
    final emptyPlan = WeeklyMealPlanModel.empty(mondayDate: mondayDate);
    await saveWeeklyPlan(emptyPlan);
    return emptyPlan;
  }

  /// Smart auto-fill for the entire week using available curated Filipino recipes.
  /// Balances traditional breakfasts (Silog, Champorado), hearty lunch viands,
  /// comfort dinner soups, and afternoon meryenda.
  Future<WeeklyMealPlanModel> autoFillWeek(DateTime mondayDate) async {
    final newPlan = WeeklyMealPlanModel.empty(mondayDate: mondayDate);
    final allRecipes = await _recipeRepo.allRecipes(limit: 200);

    if (allRecipes.isEmpty) return newPlan;

    // Filter recipes by category
    final breakfasts = allRecipes
        .where((r) =>
            r.category.toLowerCase().contains('almusal') ||
            r.category.toLowerCase().contains('breakfast') ||
            r.name.toLowerCase().contains('silog') ||
            r.name.toLowerCase().contains('egg'))
        .toList();

    final mainUlams = allRecipes
        .where((r) =>
            r.category.toLowerCase().contains('ulam') ||
            r.category.toLowerCase().contains('main') ||
            r.category.toLowerCase().contains('chicken') ||
            r.category.toLowerCase().contains('pork') ||
            r.category.toLowerCase().contains('beef') ||
            r.category.toLowerCase().contains('fish') ||
            r.category.toLowerCase().contains('soup') ||
            r.category.toLowerCase().contains('gulay'))
        .toList();

    final meryendas = allRecipes
        .where((r) =>
            r.category.toLowerCase().contains('meryenda') ||
            r.category.toLowerCase().contains('snack') ||
            r.category.toLowerCase().contains('dessert') ||
            r.category.toLowerCase().contains('pancit'))
        .toList();

    // Helper to pick a varied recipe
    RecipeModel pickRecipe(List<RecipeModel> pool, int index) {
      if (pool.isNotEmpty) {
        return pool[index % pool.length];
      }
      return allRecipes[index % allRecipes.length];
    }

    int idx = 0;
    for (int i = 0; i < 7; i++) {
      final dayDate = mondayDate.add(Duration(days: i));
      final dateKey = formatDateKey(dayDate);
      final day = newPlan.days[dateKey]!;

      // 1. Breakfast
      final bRecipe = pickRecipe(breakfasts.isNotEmpty ? breakfasts : allRecipes, idx);
      day.breakfast = MealPlanItem(
        recipeId: bRecipe.id ?? '',
        recipeName: bRecipe.name,
        coverPhotoUrl: bRecipe.coverPhotoUrl,
        category: bRecipe.category,
        prepTime: bRecipe.prepTime,
        cookTime: bRecipe.cookTime,
        servings: bRecipe.servings,
        ingredients: bRecipe.ingredients,
      );

      // 2. Lunch
      final lRecipe = pickRecipe(mainUlams.isNotEmpty ? mainUlams : allRecipes, idx + 1);
      day.lunch = MealPlanItem(
        recipeId: lRecipe.id ?? '',
        recipeName: lRecipe.name,
        coverPhotoUrl: lRecipe.coverPhotoUrl,
        category: lRecipe.category,
        prepTime: lRecipe.prepTime,
        cookTime: lRecipe.cookTime,
        servings: lRecipe.servings,
        ingredients: lRecipe.ingredients,
      );

      // 3. Dinner
      final dRecipe = pickRecipe(mainUlams.isNotEmpty ? mainUlams : allRecipes, idx + 2);
      day.dinner = MealPlanItem(
        recipeId: dRecipe.id ?? '',
        recipeName: dRecipe.name,
        coverPhotoUrl: dRecipe.coverPhotoUrl,
        category: dRecipe.category,
        prepTime: dRecipe.prepTime,
        cookTime: dRecipe.cookTime,
        servings: dRecipe.servings,
        ingredients: dRecipe.ingredients,
      );

      // 4. Meryenda
      final sRecipe = pickRecipe(meryendas.isNotEmpty ? meryendas : allRecipes, idx + 3);
      day.snack = MealPlanItem(
        recipeId: sRecipe.id ?? '',
        recipeName: sRecipe.name,
        coverPhotoUrl: sRecipe.coverPhotoUrl,
        category: sRecipe.category,
        prepTime: sRecipe.prepTime,
        cookTime: sRecipe.cookTime,
        servings: sRecipe.servings,
        ingredients: sRecipe.ingredients,
      );

      idx += 4;
      newPlan.days[dateKey] = day;
    }

    await saveWeeklyPlan(newPlan);
    return newPlan;
  }

  /// Generates a consolidated grocery checklist from all ingredients in the weekly meal plan.
  List<String> generateGroceryList(WeeklyMealPlanModel plan) {
    final rawSet = <String>{};

    for (final day in plan.days.values) {
      if (day.breakfast != null) rawSet.addAll(day.breakfast!.ingredients);
      if (day.lunch != null) rawSet.addAll(day.lunch!.ingredients);
      if (day.dinner != null) rawSet.addAll(day.dinner!.ingredients);
      if (day.snack != null) rawSet.addAll(day.snack!.ingredients);
    }

    final sorted = rawSet.where((s) => s.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return sorted;
  }
}
