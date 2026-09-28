import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';

/// Shared filter logic for "Ano Pong Ulam?" and other discovery surfaces.
///
/// Every matcher treats an "Any" selection as a no-op and normalizes
/// category strings through [RecipeRepository.canonicalCategory] so legacy
/// English labels and Filipino labels behave the same.
abstract final class RecipeFilters {
  static const mealTypes = [
    'Any',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snacks',
    'Drinks',
    'Sauces',
  ];

  static const budgetOptions = [
    'Any',
    '< ₱150 (Budget friendly)',
    '~ ₱150 - ₱300 (Affordable)',
    '~ ₱300 - ₱500 (Special)',
    '> ₱500 (Quite Expensive)',
  ];

  static const difficulties = ['Any', 'Easy', 'Medium', 'Hard'];

  /// Canonical categories for each time-of-day meal chip.
  static const _mealCategories = <String, Set<String>>{
    'Breakfast': {'almusal'},
    'Lunch': {'ulam', 'sabaw', 'gulay', 'inihaw', 'lamang dagat'},
    'Dinner': {'ulam', 'sabaw', 'gulay', 'inihaw', 'lamang dagat'},
    'Snacks': {'merienda', 'panghimagas', 'pulutan'},
  };

  static const _drinkKeywords = [
    'drink',
    'juice',
    'tea',
    'coffee',
    'kape',
    'tsokolate',
    'sago',
    'gulaman',
    'beverage',
    'inumin',
    'lemonade',
    'pandesal drink',
    'milktea',
    'milk tea',
    'soft drink',
    'softdrink',
    'kapeng',
  ];

  static const _sauceKeywords = [
    'sauce',
    'sauces',
    'sarsa',
    'sawsaw',
    'sawsawan',
    'gravy',
    'condiment',
    'toyomansi',
    'banana ketchup',
    'ketchup',
    'patis',
  ];

  /// Whole-word match so "tea" does not hit "steam" and "sauce" does not
  /// hit "saucy". Multi-word keywords match as exact phrases.
  static bool _containsKeyword(String text, String keyword) {
    if (keyword.contains(' ')) return text.contains(keyword);
    return RegExp(r'\b' + RegExp.escape(keyword) + r'\b').hasMatch(text);
  }

  static bool _matchesAnyKeyword(String text, List<String> keywords) =>
      keywords.any((k) => _containsKeyword(text, k));

  /// Whether [recipe] belongs under the selected [mealType] chip.
  /// `'Any'` always matches.
  ///
  /// Drinks/Sauces inspect only the recipe **name** (word-boundary keywords)
  /// or an explicit drinks/sauces category. Tags/descriptions freely mention
  /// "soy sauce" on Adobo/Asado/Sardinas and used to pull main dishes in.
  static bool mealTypeMatches(RecipeModel recipe, String mealType) {
    if (mealType == 'Any') return true;

    if (mealType == 'Drinks' || mealType == 'Sauces') {
      final name = recipe.name.toLowerCase();
      final keywords =
          mealType == 'Drinks' ? _drinkKeywords : _sauceKeywords;
      if (_matchesAnyKeyword(name, keywords)) return true;

      // Only an explicit drinks/sauces category counts — not ulam/sabaw/etc.
      final canonical = RecipeRepository.canonicalCategory(recipe.category);
      if (mealType == 'Drinks') {
        return canonical == 'drinks' || canonical == 'inumin';
      }
      return canonical == 'sauces' ||
          canonical == 'sauce' ||
          canonical == 'sarsa' ||
          canonical == 'sawsawan';
    }

    final canonical = RecipeRepository.canonicalCategory(recipe.category);
    final allowed = _mealCategories[mealType];
    if (allowed != null && allowed.contains(canonical)) return true;

    // Legacy display labels and meal words — name only (not description),
    // so "eggplant" does not count as Breakfast.
    final name = recipe.name.toLowerCase();
    final selected = mealType.toLowerCase();
    if (canonical == selected) return true;
    if (mealType == 'Breakfast' &&
        // Compound names: tapsilog, bangsilog, etc. (no leading word boundary).
        (name.contains('silog') || _containsKeyword(name, 'egg'))) {
      return true;
    }
    if (mealType == 'Snacks' && _containsKeyword(name, 'pancit')) return true;
    return false;
  }

  /// Maps a budget chip label to a tier index (0–3). `'Any'` → null.
  static int? budgetTierFromOption(String option) {
    if (option == 'Any') return null;
    if (option.contains('150') && !option.contains('300')) return 0;
    if (option.contains('300') && !option.contains('500')) return 1;
    if (option.contains('500') && option.contains('300')) return 2;
    if (option.toLowerCase().contains('expensive')) return 3;
    return null;
  }

  /// Normalizes a recipe's budget string to a tier index (0–3).
  /// Missing budget is treated as Budget friendly (matches seed data).
  static int budgetTier(RecipeModel recipe) {
    final display = recipe.approximateBudget.toLowerCase();
    if (display.contains('expensive') || display.contains('> ₱500')) return 3;
    if (display.contains('300') && display.contains('500')) return 2;
    if (display.contains('150') && display.contains('300')) return 1;
    return 0;
  }

  static bool budgetMatches(RecipeModel recipe, String option) {
    final selected = budgetTierFromOption(option);
    if (selected == null) return true;
    return budgetTier(recipe) == selected;
  }

  static bool difficultyMatches(RecipeModel recipe, String option) {
    if (option == 'Any') return true;
    return recipe.difficulty.trim().toLowerCase() ==
        option.trim().toLowerCase();
  }

  /// [maxMinutes] null = no time limit. Compares against prep + cook total.
  static bool timeMatches(RecipeModel recipe, double? maxMinutes) {
    if (maxMinutes == null) return true;
    return recipe.totalMinutes <= maxMinutes.round();
  }

  /// [maxServings] null = no servings cap.
  static bool servingsMatches(RecipeModel recipe, int? maxServings) {
    if (maxServings == null) return true;
    return recipe.servings <= maxServings;
  }
}
