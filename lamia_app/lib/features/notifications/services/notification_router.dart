import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../app/app.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/achievements_screen.dart';
import '../../planner/presentation/weekly_meal_planner_screen.dart';
import '../data/notification_model.dart';

class NotificationRouter {
  static final RecipeRepository _recipeRepo = RecipeRepository();

  /// Parses raw JSON notification payload into target fields.
  static Map<String, dynamic>? parsePayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Navigates using the global navigator key and a serialized JSON payload string.
  static Future<void> navigateWithPayload(String rawPayload) async {
    final data = parsePayload(rawPayload);
    if (data == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final targetType = data['targetType']?.toString() ?? data['route']?.toString() ?? '';
    final targetId = data['targetId']?.toString();

    if (targetType == 'recipe' || targetType == '/recipe') {
      if (targetId != null && targetId.isNotEmpty) {
        _navigateToRecipe(context, targetId);
      }
    } else if (targetType == 'planner' || targetType == '/planner' || targetType == 'meal_reminder') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const WeeklyMealPlannerScreen(),
        ),
      );
    } else if (targetType == 'user' || targetType == '/user' || targetType == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(targetUserId: targetId),
        ),
      );
    } else if (targetType == 'achievement' || targetType == '/achievement') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AchievementsScreen(),
        ),
      );
    }
  }

  /// Routes the user to the correct screen based on the notification type/target.
  static Future<void> navigate(BuildContext context, NotificationModel notification) async {
    final targetId = notification.targetId;
    final targetType = notification.targetType;

    switch (targetType) {
      case TargetType.recipe:
        if (targetId != null && targetId.isNotEmpty) {
          _navigateToRecipe(context, targetId);
        }
        break;
      case TargetType.user:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              targetUserId: targetId,
            ),
          ),
        );
        break;
      case TargetType.planner:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeeklyMealPlannerScreen(),
          ),
        );
        break;
      case TargetType.achievement:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AchievementsScreen(),
          ),
        );
        break;
      case TargetType.url:
      case TargetType.custom:
        // No routing logic for general/announcements - keep on active screen
        break;
    }
  }

  static void _navigateToRecipe(BuildContext context, String recipeId) async {
    // Show a loading overlay dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final recipe = await _recipeRepo.getRecipe(recipeId);

    // Pop the loading dialog if it's still active
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (recipe != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load recipe details.')),
      );
    }
  }
}
