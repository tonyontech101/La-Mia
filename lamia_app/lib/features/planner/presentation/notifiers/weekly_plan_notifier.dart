import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../recipes/data/recipe_model.dart';
import '../../data/meal_plan_model.dart';
import '../../data/meal_plan_repository.dart';

part 'weekly_plan_notifier.g.dart';

// ---------------------------------------------------------------------------
// Immutable state
// ---------------------------------------------------------------------------

/// Immutable snapshot of the weekly meal planner's business state.
class WeeklyPlanState {
  const WeeklyPlanState({
    required this.currentMonday,
    required this.selectedDayDate,
    this.currentPlan,
    this.cachedRecipes = const [],
    this.isLoading = true,
    this.isGuest = false,
    this.errorMessage,
  });

  final WeeklyMealPlanModel? currentPlan;
  final List<RecipeModel> cachedRecipes;
  final bool isLoading;
  final DateTime currentMonday;
  final DateTime selectedDayDate;
  final bool isGuest;
  final String? errorMessage;

  /// Returns a fresh state seeded to the current calendar week.
  factory WeeklyPlanState.initial({bool isGuest = false}) {
    final now = DateTime.now();
    return WeeklyPlanState(
      currentMonday: MealPlanRepository.getMondayOf(now),
      selectedDayDate: DateTime(now.year, now.month, now.day),
      isLoading: true,
      isGuest: isGuest,
    );
  }

  WeeklyPlanState copyWith({
    // Use a factory callback so callers can explicitly set null.
    WeeklyMealPlanModel? Function()? currentPlan,
    List<RecipeModel>? cachedRecipes,
    bool? isLoading,
    DateTime? currentMonday,
    DateTime? selectedDayDate,
    bool? isGuest,
    String? Function()? errorMessage,
  }) {
    return WeeklyPlanState(
      currentPlan: currentPlan != null ? currentPlan() : this.currentPlan,
      cachedRecipes: cachedRecipes ?? this.cachedRecipes,
      isLoading: isLoading ?? this.isLoading,
      currentMonday: currentMonday ?? this.currentMonday,
      selectedDayDate: selectedDayDate ?? this.selectedDayDate,
      isGuest: isGuest ?? this.isGuest,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  String get selectedDateKey =>
      MealPlanRepository.formatDateKey(selectedDayDate);

  MealPlanDay get currentSelectedDay {
    final dateKey = selectedDateKey;
    if (currentPlan == null) {
      return MealPlanDay(dateKey: dateKey, dayOfWeek: _dayOfWeek(selectedDayDate.weekday));
    }
    return currentPlan!.days[dateKey] ??
        MealPlanDay(dateKey: dateKey, dayOfWeek: _dayOfWeek(selectedDayDate.weekday));
  }

  static String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday:    return 'Monday';
      case DateTime.tuesday:   return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday:  return 'Thursday';
      case DateTime.friday:    return 'Friday';
      case DateTime.saturday:  return 'Saturday';
      case DateTime.sunday:    return 'Sunday';
      default:                 return 'Day';
    }
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the weekly meal plan lifecycle: loading, stream subscription,
/// week navigation, slot CRUD, auto-fill, and grocery list generation.
///
/// The screen owns only UI concerns (dialogs, snackbars, navigation).
@riverpod
class WeeklyPlanNotifier extends _$WeeklyPlanNotifier {
  StreamSubscription<WeeklyMealPlanModel>? _planSubscription;

  @override
  WeeklyPlanState build() {
    ref.onDispose(() {
      _planSubscription?.cancel();
    });
    final auth = ref.watch(firebaseAuthProvider);
    return WeeklyPlanState.initial(isGuest: auth.currentUser == null);
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  /// Subscribes to the real-time weekly plan stream for [currentMonday].
  void loadPlan() {
    _planSubscription?.cancel();
    state = state.copyWith(isLoading: true);

    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);

    _planSubscription = mealPlanRepo
        .watchWeeklyPlan(state.currentMonday)
        .listen(
      (plan) {
        state = state.copyWith(currentPlan: () => plan, isLoading: false);
      },
      onError: (_) {
        state = state.copyWith(isLoading: false);
      },
    );
  }

  /// Fetches recipes for the picker modal. Skips if already cached.
  Future<void> loadRecipes() async {
    if (state.cachedRecipes.isNotEmpty) return;
    try {
      final recipeRepo = ref.read(recipeRepositoryProvider);
      final recipes = await recipeRepo.allRecipes(limit: 200);
      state = state.copyWith(cachedRecipes: recipes);
    } catch (_) {
      // Non-fatal — picker will show empty state.
    }
  }

  /// One-shot refresh of the current plan (pull-to-refresh).
  Future<void> refreshPlan() async {
    try {
      final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
      final plan = await mealPlanRepo.getWeeklyPlan(state.currentMonday);
      state = state.copyWith(currentPlan: () => plan);
    } catch (_) {
      // Non-fatal.
    }
  }

  // ── Week navigation ──────────────────────────────────────────────────────

  /// Moves forward or backward by [deltaWeeks] weeks.
  void changeWeek(int deltaWeeks) {
    final newMonday =
        state.currentMonday.add(Duration(days: 7 * deltaWeeks));
    state = state.copyWith(
      currentMonday: newMonday,
      selectedDayDate: newMonday,
    );
    loadPlan();
  }

  /// Resets the view to the current calendar week.
  void resetToThisWeek() {
    final now = DateTime.now();
    final thisMonday = MealPlanRepository.getMondayOf(now);

    if (state.currentMonday != thisMonday) {
      state = state.copyWith(
        currentMonday: thisMonday,
        selectedDayDate: DateTime(now.year, now.month, now.day),
      );
      loadPlan();
    } else {
      state = state.copyWith(
        selectedDayDate: DateTime(now.year, now.month, now.day),
      );
    }
  }

  /// Selects a specific day in the strip.
  void selectDay(DateTime date) {
    state = state.copyWith(selectedDayDate: date);
  }

  // ── Slot operations ──────────────────────────────────────────────────────

  /// Assigns [recipe] to [slotKey] on the given [dateKey].
  Future<void> updateSlot({
    required String dateKey,
    required String slotKey,
    required RecipeModel recipe,
  }) async {
    final currentPlan = state.currentPlan;
    if (currentPlan == null) return;

    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
    try {
      final updated = await mealPlanRepo.assignMealSlot(
        currentPlan: currentPlan,
        dateKey: dateKey,
        slot: slotKey,
        recipe: recipe,
      );
      state = state.copyWith(currentPlan: () => updated, errorMessage: () => null);
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
      rethrow;
    }
  }

  /// Removes the recipe from [slotKey] on the currently selected day.
  Future<void> removeFromSlot(String slotKey) async {
    final currentPlan = state.currentPlan;
    if (currentPlan == null) return;

    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
    try {
      final updated = await mealPlanRepo.removeMealSlot(
        currentPlan: currentPlan,
        dateKey: state.selectedDateKey,
        slot: slotKey,
      );
      state = state.copyWith(currentPlan: () => updated, errorMessage: () => null);
    } catch (e) {
      state = state.copyWith(errorMessage: () => e.toString());
      rethrow;
    }
  }

  /// Auto-fills the entire week with suggested Filipino dishes.
  Future<void> autoFill() async {
    state = state.copyWith(isLoading: true);
    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
    try {
      final generated = await mealPlanRepo.autoFillWeek(state.currentMonday);
      state = state.copyWith(
        currentPlan: () => generated,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      );
      rethrow;
    }
  }

  // ── Grocery list ─────────────────────────────────────────────────────────

  /// Generates a sorted, de-duplicated grocery list from the current plan.
  List<String> generateGroceryList() {
    final currentPlan = state.currentPlan;
    if (currentPlan == null) return [];
    final mealPlanRepo = ref.read(mealPlanRepositoryProvider);
    return mealPlanRepo.generateGroceryList(currentPlan);
  }

  /// Formats the week header range (e.g. "Aug 25 – Aug 31, 2026").
  String formatWeekRangeHeader() {
    const shortMonths = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final monday = state.currentMonday;
    final sunday = monday.add(const Duration(days: 6));
    final start = '${shortMonths[monday.month]} ${monday.day}';
    final end = '${shortMonths[sunday.month]} ${sunday.day}, ${sunday.year}';
    return '$start – $end';
  }
}
