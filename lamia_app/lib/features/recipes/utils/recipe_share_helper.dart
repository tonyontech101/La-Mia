import '../data/recipe_model.dart';

/// Helper utility for creating and parsing recipe share text, links, and deep link URIs.
class RecipeShareHelper {
  const RecipeShareHelper._();

  static const String baseWebUrl = 'https://la-mia-e348d.web.app/recipe';
  static const String customScheme = 'lamia';

  /// Generates the standard web recipe URL.
  static String generateRecipeUrl(String recipeId) {
    return '$baseWebUrl/$recipeId';
  }

  /// Generates the custom deep link scheme URL (e.g. lamia://recipe/:id).
  static String generateDeepLinkUrl(String recipeId) {
    return '$customScheme://recipe/$recipeId';
  }

  /// Parses a recipe ID from an incoming URI.
  /// Handles:
  /// - `lamia://recipe/123`
  /// - `https://lamia.app/recipe/123`
  /// - `https://*.web.app/recipe/123` or `https://*.firebaseapp.com/recipe/123`
  static String? parseRecipeIdFromUri(Uri uri) {
    // 1. Custom scheme: lamia://recipe/123 or lamia:///recipe/123
    if (uri.scheme.toLowerCase() == customScheme) {
      if (uri.host == 'recipe' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'recipe') {
        return uri.pathSegments[1];
      }
    }

    // 2. HTTP/HTTPS URLs: https://lamia.app/recipe/123 or https://*.web.app/recipe/123
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments[0] == 'recipe') {
        final host = uri.host.toLowerCase();
        if (host == 'lamia.app' || host.endsWith('.web.app') || host.endsWith('.firebaseapp.com')) {
          return segments[1];
        }
      }
    }

    return null;
  }

  /// Generates a clean TikTok-style share text with the recipe link.
  ///
  /// Instead of pasting the entire recipe transcript with all ingredients and steps,
  /// this creates an inviting short hook and clickable URL, prompting chat apps (Messenger,
  /// WhatsApp, etc.) to generate a rich link preview card.
  ///
  /// Set [linkOnly] to true to output solely the recipe URL.
  static String generateShareText({
    required RecipeModel recipe,
    required String authorName,
    bool linkOnly = false,
  }) {
    final recipeUrl = generateRecipeUrl(recipe.id ?? '');
    if (linkOnly) {
      return recipeUrl;
    }

    final byAuthor = (authorName.isNotEmpty && authorName != 'La Mia')
        ? ' by $authorName'
        : '';

    return 'Check out "${recipe.name}"$byAuthor on La Mia! 🍽️\n$recipeUrl';
  }
}
