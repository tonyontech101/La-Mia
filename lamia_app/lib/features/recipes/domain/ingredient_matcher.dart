import '../data/recipe_model.dart';
import 'ingredient_matched_recipe.dart';

/// Pure ingredient-matching logic extracted out of
/// `CookByIngredientsScreen._computeMatches` so the algorithm can be
/// unit-tested in isolation (no widget tree, no Firebase).
///
/// Matching strategy (AND logic):
///   - Every selected user ingredient tag MUST be present in the recipe.
///     If any selected ingredient is missing from a recipe, that recipe is excluded.
///   - Recipe ingredients and user-supplied tags are both normalized
///     (lowercased, trimmed, stemmed for singular/plural, and mapped for
///     common Filipino culinary synonyms).
///   - Token-based matching prevents substring false positives (e.g. "egg"
///     does not match "eggplant", "rice" does not match "price").
///   - Multi-token tags ("soy sauce", "cooking oil") match when the core
///     ingredient is present in the recipe item.
List<IngredientMatchedRecipe> computeIngredientMatches(
  List<RecipeModel> recipes,
  List<String> selectedTags,
) {
  if (selectedTags.isEmpty || recipes.isEmpty) return const [];

  // Deduplicate and clean selected tags
  final cleanTags = <String>[];
  final seenTags = <String>{};
  for (final tag in selectedTags) {
    final t = _normalize(tag);
    if (t.isNotEmpty && seenTags.add(t)) {
      cleanTags.add(t);
    }
  }

  if (cleanTags.isEmpty) return const [];

  // Pre-tokenize each tag once so we don't repeat the work per ingredient.
  final tagTokensList = cleanTags.map(_tokens).toList();
  final matches = <IngredientMatchedRecipe>[];

  for (final recipe in recipes) {
    if (recipe.ingredients.isEmpty) continue;

    // Pre-tokenize all ingredients in this recipe
    final recipeIngredientTokens = recipe.ingredients.map(_tokens).toList();

    // AND LOGIC:
    // Every selected tag MUST match at least one ingredient in this recipe.
    var allTagsPresent = true;
    for (final tagTokens in tagTokensList) {
      final tagFoundInRecipe = recipeIngredientTokens.any(
        (ingTokens) => _matches(ingTokens, tagTokens),
      );
      if (!tagFoundInRecipe) {
        allTagsPresent = false;
        break;
      }
    }

    // Only dishes that have ALL the selected ingredients present are kept
    if (!allTagsPresent) continue;

    var matchedCount = 0;
    final missing = <String>[];

    for (var i = 0; i < recipe.ingredients.length; i++) {
      final ingTokens = recipeIngredientTokens[i];
      final isMatched = tagTokensList.any(
        (tagTokens) => _matches(ingTokens, tagTokens),
      );

      if (isMatched) {
        matchedCount++;
      } else {
        missing.add(recipe.ingredients[i]);
      }
    }

    final totalCount = recipe.ingredients.length;
    // Limits the match range to [1, 100]
    final matchPct = ((matchedCount / totalCount) * 100).round().clamp(1, 100);

    matches.add(
      IngredientMatchedRecipe(
        recipe: recipe,
        matchPercentage: matchPct,
        matchedCount: matchedCount,
        totalIngredients: totalCount,
        missingIngredients: missing,
      ),
    );
  }

  // Highest match percentage first; ties broken by raw matched count so
  // recipes that match more ingredients float up.
  matches.sort((a, b) {
    final byPct = b.matchPercentage.compareTo(a.matchPercentage);
    if (byPct != 0) return byPct;
    return b.matchedCount.compareTo(a.matchedCount);
  });

  return matches;
}

String _normalize(String s) => s.trim().toLowerCase();

String _normalizeToken(String token) {
  var t = token.trim().toLowerCase();
  if (t.isEmpty) return t;

  // Singularize common plural endings
  if (t.length > 4 && t.endsWith('ies')) {
    return '${t.substring(0, t.length - 3)}y';
  }
  if (t == 'leaves' || t == 'leaf') {
    return 'leaf';
  }
  if (t.length > 4 && t.endsWith('es')) {
    final base = t.substring(0, t.length - 2);
    if (base.endsWith('o') ||
        base.endsWith('ch') ||
        base.endsWith('sh') ||
        base.endsWith('x') ||
        base.endsWith('s')) {
      return base; // tomatoes -> tomato, potatoes -> potato
    }
    return t.substring(0, t.length - 1); // cloves -> clove
  }
  if (t.length > 3 && t.endsWith('s') && !t.endsWith('ss')) {
    return t.substring(0, t.length - 1); // eggs -> egg, onions -> onion
  }

  return t;
}

Set<String> _tokens(String s) {
  // Split on whitespace and common list punctuation; drop empties.
  final rawTokens = s
      .toLowerCase()
      .split(RegExp(r'[\s,/&()\-]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty);

  final tokens = <String>{};
  for (final raw in rawTokens) {
    final t = _normalizeToken(raw);
    tokens.add(t);

    // Expand known Filipino culinary terms into English equivalents
    switch (t) {
      case 'toyo':
        tokens.addAll(['soy', 'sauce']);
        break;
      case 'patis':
        tokens.addAll(['fish', 'sauce']);
        break;
      case 'mantika':
        tokens.addAll(['cooking', 'oil']);
        break;
      case 'bawang':
        tokens.add('garlic');
        break;
      case 'sibuyas':
        tokens.add('onion');
        break;
      case 'itlog':
        tokens.add('egg');
        break;
      case 'manok':
        tokens.add('chicken');
        break;
      case 'baboy':
        tokens.add('pork');
        break;
      case 'baka':
        tokens.add('beef');
        break;
      case 'suka':
        tokens.add('vinegar');
        break;
      case 'paminta':
        tokens.add('pepper');
        break;
      case 'luya':
        tokens.add('ginger');
        break;
      case 'kanin':
      case 'sinangag':
        tokens.add('rice');
        break;
    }
  }

  return tokens;
}

/// Returns true if [ingredientTokens] matches the [tagTokens] set.
bool _matches(Set<String> ingredientTokens, Set<String> tagTokens) {
  if (tagTokens.isEmpty || ingredientTokens.isEmpty) return false;

  // "cooking oil" / "oil" synonym rule: any oil ingredient matches cooking oil tag
  if (tagTokens.contains('oil') && ingredientTokens.contains('oil')) {
    return true;
  }

  var shared = 0;
  for (final t in tagTokens) {
    if (ingredientTokens.contains(t)) shared++;
  }

  // Single-token tag: present in ingredient tokens
  if (tagTokens.length == 1) {
    return shared >= 1;
  }

  // Multi-token tag: strict majority of tag's tokens
  return shared * 2 > tagTokens.length;
}
