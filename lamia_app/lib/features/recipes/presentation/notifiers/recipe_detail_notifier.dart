import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../recipes/data/recipe_model.dart';

part 'recipe_detail_notifier.g.dart';

/// Result of a social action (like, bookmark, follow, rate).
///
/// The widget layer uses [message] / [isError] to show snackbars.
class SocialActionResult {
  const SocialActionResult({required this.success, this.message, this.isError = false});

  final bool success;
  final String? message;
  final bool isError;

  const SocialActionResult.ok([this.message])
      : success = true,
        isError = false;

  const SocialActionResult.error(this.message) : success = false, isError = true;
}

/// State held by [RecipeDetailNotifier] for the recipe detail screen.
@immutable
class RecipeDetailState {
  const RecipeDetailState({
    required this.recipe,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isFollowing = false,
    this.socialLoading = true,
    this.localLikeCount = 0,
    this.localFavoriteCount = 0,
    this.userRating = 0,
    this.localRatingAvg = 0.0,
    this.localRatingCount = 0,
  });

  factory RecipeDetailState.initial(RecipeModel recipe) => RecipeDetailState(
        recipe: recipe,
        localLikeCount: recipe.likeCount,
        localFavoriteCount: recipe.favoriteCount,
        localRatingAvg: recipe.ratingAvg,
        localRatingCount: recipe.ratingCount,
      );

  final RecipeModel recipe;
  final bool isLiked;
  final bool isBookmarked;
  final bool isFollowing;
  final bool socialLoading;
  final int localLikeCount;
  final int localFavoriteCount;
  final int userRating;
  final double localRatingAvg;
  final int localRatingCount;

  RecipeDetailState copyWith({
    RecipeModel? recipe,
    bool? isLiked,
    bool? isBookmarked,
    bool? isFollowing,
    bool? socialLoading,
    int? localLikeCount,
    int? localFavoriteCount,
    int? userRating,
    double? localRatingAvg,
    int? localRatingCount,
  }) {
    return RecipeDetailState(
      recipe: recipe ?? this.recipe,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFollowing: isFollowing ?? this.isFollowing,
      socialLoading: socialLoading ?? this.socialLoading,
      localLikeCount: localLikeCount ?? this.localLikeCount,
      localFavoriteCount: localFavoriteCount ?? this.localFavoriteCount,
      userRating: userRating ?? this.userRating,
      localRatingAvg: localRatingAvg ?? this.localRatingAvg,
      localRatingCount: localRatingCount ?? this.localRatingCount,
    );
  }
}

/// Notifier managing social + planner state for the recipe detail screen.
///
/// Accepts the initial [RecipeModel] via the [build] parameter and
/// exposes imperative methods for like / bookmark / follow / rate.
/// All UI feedback (snackbars, context) is the caller's responsibility.
@riverpod
class RecipeDetailNotifier extends _$RecipeDetailNotifier {
  @override
  RecipeDetailState build(RecipeModel recipe) {
    return RecipeDetailState.initial(recipe);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String? get _userId => ref.read(currentUserIdProvider);

  // ── Social state loading ───────────────────────────────────────────────

  /// Loads the current user's social interactions for this recipe.
  Future<void> loadSocialState() async {
    final userId = _userId;
    if (userId == null) {
      state = state.copyWith(socialLoading: false);
      return;
    }
    final recipeId = state.recipe.id;
    if (recipeId == null) {
      state = state.copyWith(socialLoading: false);
      return;
    }

    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      final favoritesRepo = ref.read(favoritesRepositoryProvider);
      final followRepo = ref.read(followRepositoryProvider);
      final ratingRepo = ref.read(ratingRepositoryProvider);

      final results = await Future.wait([
        likeRepo.isLiked(recipeId: recipeId, userId: userId),
        favoritesRepo.isSaved(recipeId: recipeId, userId: userId),
        if (state.recipe.authorId != null && !state.recipe.isSystemRecipe)
          followRepo.isFollowing(
            currentUid: userId,
            targetUid: state.recipe.authorId!,
          )
        else
          Future.value(false),
        ratingRepo.getUserRating(recipeId: recipeId, userId: userId),
      ]);

      state = state.copyWith(
        isLiked: results[0] as bool,
        isBookmarked: results[1] as bool,
        isFollowing: results[2] as bool,
        userRating: (results[3] as int?) ?? 0,
        socialLoading: false,
      );
    } catch (_) {
      state = state.copyWith(socialLoading: false);
    }
  }

  // ── Like ───────────────────────────────────────────────────────────────

  /// Toggles the like state. Returns a [SocialActionResult] with an
  /// optional message the widget can display as a snackbar.
  Future<SocialActionResult> toggleLike() async {
    final userId = _userId;
    if (userId == null) {
      return const SocialActionResult.error('Sign in to like recipes');
    }
    final recipeId = state.recipe.id;
    if (recipeId == null || recipeId.isEmpty) {
      return const SocialActionResult.error('Cannot like this recipe');
    }

    try {
      final likeRepo = ref.read(likeRepositoryProvider);
      final newState = await likeRepo.toggleLike(
        recipeId: recipeId,
        userId: userId,
        recipeAuthorId: state.recipe.authorId,
        senderName: null, // populated by Firebase auth in repo if needed
        senderPhotoUrl: null,
        recipeTitle: state.recipe.name,
      );
      state = state.copyWith(
        isLiked: newState,
        localLikeCount: (state.localLikeCount + (newState ? 1 : -1)).clamp(0, 999999),
      );
      return const SocialActionResult.ok();
    } catch (e, st) {
      AppLogger.error('Error toggling like: $e', error: e, stackTrace: st);
      return SocialActionResult.error('Could not update like: $e');
    }
  }

  // ── Bookmark ───────────────────────────────────────────────────────────

  /// Toggles the bookmark state.
  Future<SocialActionResult> toggleBookmark() async {
    final userId = _userId;
    if (userId == null) {
      return const SocialActionResult.error('Sign in to save recipes');
    }
    final recipeId = state.recipe.id;
    if (recipeId == null || recipeId.isEmpty) {
      return const SocialActionResult.error('Cannot save this recipe');
    }

    try {
      final favoritesRepo = ref.read(favoritesRepositoryProvider);
      final newState = await favoritesRepo.toggleSave(
        recipeId: recipeId,
        userId: userId,
      );
      state = state.copyWith(
        isBookmarked: newState,
        localFavoriteCount:
            (state.localFavoriteCount + (newState ? 1 : -1)).clamp(0, 999999),
      );
      return SocialActionResult.ok(
        newState ? 'Recipe saved' : 'Recipe removed from saved',
      );
    } catch (e, st) {
      AppLogger.error(
        'Error toggling bookmark: $e',
        error: e,
        stackTrace: st,
      );
      return SocialActionResult.error('Could not save recipe: $e');
    }
  }

  // ── Follow ─────────────────────────────────────────────────────────────

  /// Toggles the follow state for the recipe author.
  Future<SocialActionResult> toggleFollow() async {
    final userId = _userId;
    if (userId == null) {
      return const SocialActionResult.error('Sign in to follow chefs');
    }
    final authorId = state.recipe.authorId;
    if (authorId == null || state.recipe.isSystemRecipe) {
      return const SocialActionResult.ok();
    }

    try {
      final followRepo = ref.read(followRepositoryProvider);
      final newState = await followRepo.toggleFollow(
        currentUid: userId,
        targetUid: authorId,
      );
      state = state.copyWith(isFollowing: newState);
      return SocialActionResult.ok(
        newState
            ? 'Following ${state.recipe.authorName}'
            : 'Unfollowed ${state.recipe.authorName}',
      );
    } catch (e, st) {
      AppLogger.error('Error toggling follow: $e', error: e, stackTrace: st);
      return SocialActionResult.error('Could not update follow: $e');
    }
  }

  // ── Rating ─────────────────────────────────────────────────────────────

  /// Submits a [rating] for this recipe (1-5 stars).
  Future<SocialActionResult> handleRate(int rating) async {
    final userId = _userId;
    if (userId == null) {
      return const SocialActionResult.error(
          'Please sign in to rate this recipe');
    }
    final recipeId = state.recipe.id;
    if (recipeId == null) {
      return const SocialActionResult.error('Cannot rate this recipe');
    }

    try {
      final ratingRepo = ref.read(ratingRepositoryProvider);
      await ratingRepo.submitRating(
        recipeId: recipeId,
        userId: userId,
        rating: rating,
      );
      state = state.copyWith(userRating: rating);
      // Reload the recipe to pick up updated ratingAvg / ratingCount.
      await reloadRecipe();
      return const SocialActionResult.ok('Thank you for rating this recipe!');
    } catch (e) {
      return SocialActionResult.error('Could not submit rating: $e');
    }
  }

  // ── Recipe reload ──────────────────────────────────────────────────────

  /// Re-fetches the recipe from Firestore to update counters.
  Future<void> reloadRecipe() async {
    final recipeId = state.recipe.id;
    if (recipeId == null) return;
    try {
      final recipeRepo = ref.read(recipeRepositoryProvider);
      final updated = await recipeRepo.getRecipe(recipeId);
      if (updated != null) {
        state = state.copyWith(
          recipe: updated,
          localLikeCount: updated.likeCount,
          localFavoriteCount: updated.favoriteCount,
          localRatingAvg: updated.ratingAvg,
          localRatingCount: updated.ratingCount,
        );
      }
    } catch (_) {}
  }
}
