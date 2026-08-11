import '../data/recipe_model.dart';
import 'ingredient_matched_recipe.dart';

/// Pure ingredient-matching logic extracted out of
/// `CookByIngredientsScreen._computeMatches` so the algorithm can be
/// unit-tested in isolation (no widget tree, no Firebase).
///
/// Matching strategy:
///   - Recipe ingredients and user-supplied tags are both normalized
///     (lowercased + trimmed) then split into whitespace/punctuation tokens.
///   - A tag matches an ingredient when a strict majority of the tag's
///     tokens are present in the ingredient's token set (see [_matches] for
///     the precise rule). Single-token tags therefore require that exact
///     token to be present (so "rice" matches "rice flour" — recipe uses
///     rice — but NOT "price", which tokenizes to a different token).
///   - Substring contains is never used, eliminating false positives such
///     as "egg" matching "eggplant" (different tokens).
///
/// Until the canonical ingredient dictionary + Cloud Function ships
/// (architecture §4), this is a defensive client-side best-effort matcher.
List<IngredientMatchedRecipe> computeIngredientMatches(
  List<RecipeModel> recipes,
  List<String> selectedTags,
) {
  if (selectedTags.isEmpty) return const [];

  // Pre-tokenize each tag once so we don't repeat the work per ingredient.
  final tagTokensList = selectedTags.map(_normalize).map(_tokens).toList();
  final matches = <IngredientMatchedRecipe>[];

  for (final recipe in recipes) {
    var matchedCount = 0;
    final missing = <String>[];

    for (final ingredient in recipe.ingredients) {
      final ingTokens = _tokens(ingredient);
      final isMatched = tagTokensList.any(
        (tagTokens) => _matches(ingTokens, tagTokens),
      );

      if (isMatched) {
        matchedCount++;
      } else {
        missing.add(ingredient);
      }
    }

    if (matchedCount > 0) {
      final totalCount = recipe.ingredients.isEmpty
          ? 1
          : recipe.ingredients.length;
      // Limits the match range to [1, 100] so partial matches don't show 0%
      // (matching nothing is filtered out above) or > 100% by arithmetic.
      final matchPct = ((matchedCount / totalCount) * 100).round().clamp(
        1,
        100,
      );

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

Set<String> _tokens(String s) {
  // Split on whitespace and common list punctuation; drop empties.
  return s
      .toLowerCase()
      .split(RegExp(r'[\s,/&]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();
}

/// Returns true if [ingredientTokens] matches the [tagTokens] set.
///
/// Single-token tags (the common case: "rice", "egg") match when the tag's
/// token is present anywhere in the ingredient's token set — so "chicken"
/// matches both "chicken" and "chicken thigh". This portion-of-ingredient
/// match is intentional for the La Mia pantry use-case: a user choosing
/// "chicken" wants recipes that use chicken, regardless of cut.
///
/// Multi-token tags ("soy sauce", "cooking oil") require a *strict*
/// majority of the tag's tokens to be present in the ingredient — strictly
/// more than half — so "soy sauce" does NOT match "soy vinegar" (only "soy"
/// is shared) but "rice vinegar" matches "rice vinegar".
///
/// Substring matching is never used, fixing false positives like "rice"
/// matching "price", or "egg" matching "eggplant" (which tokenizes to a
/// single token "eggplant" with no "egg" element).
bool _matches(Set<String> ingredientTokens, Set<String> tagTokens) {
  if (tagTokens.isEmpty) return false;
  var shared = 0;
  for (final t in tagTokens) {
    if (ingredientTokens.contains(t)) shared++;
  }
  // Strict majority: shared must be strictly more than half the tag tokens.
  return shared * 2 > tagTokens.length;
}
