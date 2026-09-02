import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single meal assignment in the weekly planner.
class MealPlanItem {
  const MealPlanItem({
    required this.recipeId,
    required this.recipeName,
    required this.coverPhotoUrl,
    required this.category,
    this.prepTime = '',
    this.cookTime = '',
    this.servings = 4,
    this.ingredients = const [],
    this.notes = '',
  });

  final String recipeId;
  final String recipeName;
  final String coverPhotoUrl;
  final String category;
  final String prepTime;
  final String cookTime;
  final int servings;
  final List<String> ingredients;
  final String notes;

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeName': recipeName,
      'coverPhotoUrl': coverPhotoUrl,
      'category': category,
      'prepTime': prepTime,
      'cookTime': cookTime,
      'servings': servings,
      'ingredients': ingredients,
      'notes': notes,
    };
  }

  factory MealPlanItem.fromMap(Map<String, dynamic> map) {
    return MealPlanItem(
      recipeId: map['recipeId'] as String? ?? '',
      recipeName: map['recipeName'] as String? ?? 'Untitled Dish',
      coverPhotoUrl: map['coverPhotoUrl'] as String? ?? '',
      category: map['category'] as String? ?? 'Ulam',
      prepTime: map['prepTime'] as String? ?? '',
      cookTime: map['cookTime'] as String? ?? '',
      servings: (map['servings'] as num?)?.toInt() ?? 4,
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notes: map['notes'] as String? ?? '',
    );
  }
}

/// Represents the meal slots for a single day.
class MealPlanDay {
  MealPlanDay({
    required this.dateKey, // '2026-08-24'
    required this.dayOfWeek, // 'Monday'
    this.breakfast,
    this.lunch,
    this.dinner,
    this.snack,
  });

  final String dateKey;
  final String dayOfWeek;
  MealPlanItem? breakfast;
  MealPlanItem? lunch;
  MealPlanItem? dinner;
  MealPlanItem? snack;

  bool get isEmpty =>
      breakfast == null && lunch == null && dinner == null && snack == null;

  int get totalMealsCount =>
      (breakfast != null ? 1 : 0) +
      (lunch != null ? 1 : 0) +
      (dinner != null ? 1 : 0) +
      (snack != null ? 1 : 0);

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'dayOfWeek': dayOfWeek,
      if (breakfast != null) 'breakfast': breakfast!.toMap(),
      if (lunch != null) 'lunch': lunch!.toMap(),
      if (dinner != null) 'dinner': dinner!.toMap(),
      if (snack != null) 'snack': snack!.toMap(),
    };
  }

  factory MealPlanDay.fromMap(Map<dynamic, dynamic> rawMap, {required String dateKey, required String dayOfWeek}) {
    final map = Map<String, dynamic>.from(rawMap);
    return MealPlanDay(
      dateKey: map['dateKey'] as String? ?? dateKey,
      dayOfWeek: map['dayOfWeek'] as String? ?? dayOfWeek,
      breakfast: map['breakfast'] is Map
          ? MealPlanItem.fromMap(Map<String, dynamic>.from(map['breakfast'] as Map))
          : null,
      lunch: map['lunch'] is Map
          ? MealPlanItem.fromMap(Map<String, dynamic>.from(map['lunch'] as Map))
          : null,
      dinner: map['dinner'] is Map
          ? MealPlanItem.fromMap(Map<String, dynamic>.from(map['dinner'] as Map))
          : null,
      snack: map['snack'] is Map
          ? MealPlanItem.fromMap(Map<String, dynamic>.from(map['snack'] as Map))
          : null,
    );
  }
}

/// Represents a full 7-day weekly meal plan document in Firestore.
class WeeklyMealPlanModel {
  WeeklyMealPlanModel({
    required this.weekId, // e.g. 'week_2026_08_24'
    required this.startDate,
    required this.days,
    this.updatedAt,
  });

  final String weekId;
  final DateTime startDate; // Monday of the week
  final Map<String, MealPlanDay> days; // keyed by dateKey e.g. '2026-08-24'
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestore() {
    final daysMap = <String, dynamic>{};
    days.forEach((key, value) {
      daysMap[key] = value.toMap();
    });

    return {
      'weekId': weekId,
      'startDate': Timestamp.fromDate(startDate),
      'days': daysMap,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory WeeklyMealPlanModel.fromFirestore(
    Map<String, dynamic> data, {
    required String weekId,
    required DateTime startDate,
  }) {
    final rawDaysVal = data['days'];
    final rawDays = rawDaysVal is Map ? Map<dynamic, dynamic>.from(rawDaysVal) : const <dynamic, dynamic>{};
    final daysMap = <String, MealPlanDay>{};

    // Populate all 7 days of the week starting from startDate
    for (int i = 0; i < 7; i++) {
      final dayDate = startDate.add(Duration(days: i));
      final dateKey = _formatDateKey(dayDate);
      final dayName = _getDayName(dayDate.weekday);

      if (rawDays.containsKey(dateKey) && rawDays[dateKey] is Map) {
        daysMap[dateKey] = MealPlanDay.fromMap(
          Map<dynamic, dynamic>.from(rawDays[dateKey] as Map),
          dateKey: dateKey,
          dayOfWeek: dayName,
        );
      } else {
        daysMap[dateKey] = MealPlanDay(
          dateKey: dateKey,
          dayOfWeek: dayName,
        );
      }
    }

    return WeeklyMealPlanModel(
      weekId: weekId,
      startDate: data['startDate'] is Timestamp
          ? (data['startDate'] as Timestamp).toDate()
          : startDate,
      days: daysMap,
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Creates a blank 7-day meal plan for a given week Monday.
  factory WeeklyMealPlanModel.empty({required DateTime mondayDate}) {
    final weekId = _formatWeekId(mondayDate);
    final daysMap = <String, MealPlanDay>{};

    for (int i = 0; i < 7; i++) {
      final dayDate = mondayDate.add(Duration(days: i));
      final dateKey = _formatDateKey(dayDate);
      final dayName = _getDayName(dayDate.weekday);
      daysMap[dateKey] = MealPlanDay(
        dateKey: dateKey,
        dayOfWeek: dayName,
      );
    }

    return WeeklyMealPlanModel(
      weekId: weekId,
      startDate: mondayDate,
      days: daysMap,
      updatedAt: DateTime.now(),
    );
  }

  static String _formatDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatWeekId(DateTime monday) {
    final y = monday.year;
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return 'week_${y}_${m}_$d';
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Day';
    }
  }
}
