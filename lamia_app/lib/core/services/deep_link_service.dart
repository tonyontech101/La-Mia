import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import '../../app/app.dart';
import '../../features/notifications/services/notification_router.dart';
import '../../features/recipes/utils/recipe_share_helper.dart';
import '../utils/app_logger.dart';

/// Handles deep linking for incoming recipe links (e.g. `lamia://recipe/:id` or web URLs).
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Optional override for routing to a recipe. Defaults to [NotificationRouter.navigateToRecipe].
  void Function(String recipeId)? onNavigateToRecipe;

  /// Initializes deep link listening on app startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Handle the initial link if the app was opened via a deep link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        handleUri(initialUri);
      }
    } catch (e) {
      AppLogger.warning('Failed to get initial deep link: $e', 'DeepLink');
    }

    // Listen to incoming deep links while the app is running
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        handleUri(uri);
      },
      onError: (err) {
        AppLogger.warning('Deep link stream error: $err', 'DeepLink');
      },
    );
  }

  /// Processes a single incoming URI and routes appropriately.
  void handleUri(Uri uri) {
    AppLogger.info('Handling incoming deep link URI: $uri', 'DeepLink');
    final recipeId = RecipeShareHelper.parseRecipeIdFromUri(uri);
    if (recipeId != null && recipeId.isNotEmpty) {
      final navigate = onNavigateToRecipe ?? NotificationRouter.navigateToRecipe;
      if (rootNavigatorKey.currentContext != null) {
        navigate(recipeId);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigate(recipeId);
        });
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
