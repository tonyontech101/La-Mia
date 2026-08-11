import '../data/recipe_model.dart';

/// Item model representing a recipe matched against user selected ingredients.
class IngredientMatchedRecipe {
  const IngredientMatchedRecipe({
    required this.recipe,
    required this.matchPercentage,
    required this.matchedCount,
    required this.totalIngredients,
    this.missingIngredients = const [],
  });

  final RecipeModel recipe;
  final int matchPercentage;
  final int matchedCount;
  final int totalIngredients;
  final List<String> missingIngredients;
}
