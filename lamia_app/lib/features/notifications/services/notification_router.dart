import 'package:flutter/material.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/achievements_screen.dart';
import '../../planner/presentation/weekly_meal_planner_screen.dart';
import '../data/notification_model.dart';

class NotificationRouter {
  static final RecipeRepository _recipeRepo = RecipeRepository();

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
