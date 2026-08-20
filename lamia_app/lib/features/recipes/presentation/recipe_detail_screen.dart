import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/slide_tab_switcher.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/presentation/login_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../social/data/comment_model.dart';
import '../../social/data/comment_repository.dart';
import '../../social/data/favorites_repository.dart';
import '../../social/data/follow_repository.dart';
import '../../social/data/like_repository.dart';
import '../data/recipe_model.dart';

/// Parses a raw instruction string into a `(title, body)` pair.
///
/// If the instruction contains a `:` the first segment becomes the title and
/// the rest becomes the body. Otherwise the title is `Step {index + 1}`.
/// Pure top-level function so it can be unit-tested in isolation.
(String title, String body) parseInstructionStep(
  int index,
  String rawInstruction,
) {
  if (rawInstruction.contains(':')) {
    final parts = rawInstruction.split(':');
    final title = parts.first.trim();
    final body = parts.sublist(1).join(':').trim();
    return (title, body);
  }
  return ('Step ${index + 1}', rawInstruction);
}

/// Generic chef's tips for any recipe that doesn't yet ship authoritative
/// tips via its Firestore document. Remove once `recipe.chefsTips` ships.
const List<String> _defaultChefsTips = [
  'Use fresh, high-quality ingredients for optimal taste and aroma.',
  'Adjust seasoning gradually to suit your personal preference.',
  'Let the dish rest for 5 minutes before serving to allow flavors to meld together.',
];

/// Screen displaying complete details of a recipe, featuring:
/// - Header image & back navigation
/// - Floating summary card with ratings, likes, author action bar, and metric boxes
/// - Folder-style tabbed section for Ingredients, Instructions, and Chef's Tips
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.screenTitle = 'Featured Recipe',
  });

  final RecipeModel recipe;
  final String screenTitle;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _activeTabIndex = 0; // 0: Ingredients, 1: Instructions, 2: Chef's Tips

  // ── Social state ────────────────────────────────────────────────────────
  final LikeRepository _likeRepo = LikeRepository();
  final FavoritesRepository _favoritesRepo = FavoritesRepository();
  final FollowRepository _followRepo = FollowRepository();
  final CommentRepository _commentRepo = CommentRepository();

  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFollowing = false;
  bool _socialLoading = true;
  int _localLikeCount = 0;

  // ── Comments State ──────────────────────────────────────────────────────
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.recipe.likeCount;
    _loadSocialState();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _socialLoading = false);
      return;
    }
    final recipeId = widget.recipe.id;
    if (recipeId == null) {
      if (mounted) setState(() => _socialLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _likeRepo.isLiked(recipeId: recipeId, userId: user.uid),
        _favoritesRepo.isSaved(recipeId: recipeId, userId: user.uid),
        if (widget.recipe.authorId != null && !widget.recipe.isSystemRecipe)
          _followRepo.isFollowing(
            currentUid: user.uid,
            targetUid: widget.recipe.authorId!,
          )
        else
          Future.value(false),
      ]);
      if (mounted) {
        setState(() {
          _isLiked = results[0];
          _isBookmarked = results[1];
          _isFollowing = results[2];
          _socialLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _socialLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.show(context, message: 'Sign in to like recipes');
      return;
    }
    final recipeId = widget.recipe.id;
    if (recipeId == null) return;
    final newState = await _likeRepo.toggleLike(
      recipeId: recipeId,
      userId: user.uid,
      recipeAuthorId: widget.recipe.authorId,
    );
    if (mounted) {
      setState(() {
        _isLiked = newState;
        _localLikeCount += newState ? 1 : -1;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.show(context, message: 'Sign in to save recipes');
      return;
    }
    final recipeId = widget.recipe.id;
    if (recipeId == null) return;
    final newState = await _favoritesRepo.toggleSave(
      recipeId: recipeId,
      userId: user.uid,
    );
    if (mounted) {
      setState(() => _isBookmarked = newState);
      AppSnackbar.show(
        context,
        message: newState ? 'Recipe saved' : 'Recipe removed from saved',
      );
    }
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.show(context, message: 'Sign in to follow chefs');
      return;
    }
    final authorId = widget.recipe.authorId;
    if (authorId == null || widget.recipe.isSystemRecipe) return;
    final newState = await _followRepo.toggleFollow(
      currentUid: user.uid,
      targetUid: authorId,
    );
    if (mounted) {
      setState(() => _isFollowing = newState);
      AppSnackbar.show(
        context,
        message: newState
            ? 'Following ${widget.recipe.authorName}'
            : 'Unfollowed ${widget.recipe.authorName}',
      );
    }
  }

  void _navigateToAuthorProfile() {
    final authorId = widget.recipe.authorId;
    if (authorId == null || widget.recipe.isSystemRecipe) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: authorId)),
    );
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.show(context, message: 'Please sign in to post a comment');
      return;
    }

    final recipeId = widget.recipe.id;
    if (recipeId == null) {
      AppSnackbar.show(context, message: 'Unable to comment on this recipe');
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      await _commentRepo.addComment(
        recipeId: recipeId,
        userId: user.uid,
        userName: (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'Home Cook'),
        userPhotoUrl: user.photoURL,
        text: text,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus();
      if (mounted) {
        AppSnackbar.show(context, message: 'Comment shared!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Failed to post comment: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _handleDeleteComment(CommentModel comment) async {
    final recipeId = widget.recipe.id;
    if (recipeId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete comment?'),
        content: const Text('Are you sure you want to remove your comment? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _commentRepo.deleteComment(
          recipeId: recipeId,
          commentId: comment.id,
        );
        if (mounted) {
          AppSnackbar.show(context, message: 'Comment deleted');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(context, message: 'Failed to delete comment: $e');
        }
      }
    }
  }

  Future<void> _handleToggleCommentLike(CommentModel comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.show(context, message: 'Sign in to like comments');
      return;
    }
    final recipeId = widget.recipe.id;
    if (recipeId == null) return;

    await _commentRepo.toggleCommentLike(
      recipeId: recipeId,
      commentId: comment.id,
      userId: user.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final chefsTips = _defaultChefsTips;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.screenTitle,
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            // 1. Large Dish Image Banner
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: recipe.coverPhotoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceAlt,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceAlt,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.restaurant,
                              size: 54,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Dish Image',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Main Overlaid Summary Card
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.7),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Dish Title & Like Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              recipe.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Like button + count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (recipe.ratingAvg > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 18,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      recipe.ratingAvg.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _socialLoading ? null : _toggleLike,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        _isLiked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        key: ValueKey(_isLiked),
                                        size: 20,
                                        color: _isLiked
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _localLikeCount > 0
                                          ? '$_localLikeCount'
                                          : 'Like',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isLiked
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Short description — neutral intro built from the
                      // recipe's own `category` + `region` fields. Don't
                      // fabricate history claims ("early 19th century").
                      Text(
                        'A ${recipe.category.toLowerCase()} recipe'
                        '${recipe.region.isEmpty || recipe.region == 'Unknown' ? '' : ' from ${recipe.region}'}'
                        ' • ${recipe.approximateBudget}.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Author & Action Icons Row
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: recipe.isSystemRecipe
                                  ? null
                                  : _navigateToAuthorProfile,
                              child: Row(
                                children: [
                                  // Author avatar
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: recipe.isSystemRecipe
                                          ? AppColors.primary.withValues(
                                              alpha: 0.12,
                                            )
                                          : AppColors.border.withValues(
                                              alpha: 0.6,
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: recipe.isSystemRecipe
                                        ? const Icon(
                                            Icons.restaurant_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          )
                                        : recipe.authorPhotoUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl: recipe.authorPhotoUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) => Center(
                                                child: Text(
                                                  recipe.authorName.isNotEmpty
                                                      ? recipe.authorName[0]
                                                            .toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              recipe.authorName.isNotEmpty
                                                  ? recipe.authorName[0]
                                                        .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Recipe by ${recipe.authorName}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (recipe.isSystemRecipe) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Original',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Follow button — only for non-system recipes
                                  if (!recipe.isSystemRecipe &&
                                      recipe.authorId != null &&
                                      recipe.authorId !=
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid)
                                    GestureDetector(
                                      onTap: _socialLoading
                                          ? null
                                          : _toggleFollow,
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isFollowing
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.12,
                                                )
                                              : AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          _isFollowing
                                              ? 'Following'
                                              : '+ Follow',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _isFollowing
                                                ? AppColors.primary
                                                : AppColors.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Print, Share, Bookmark Actions
                          IconButton(
                            onPressed: () {
                              AppSnackbar.show(
                                context,
                                message: 'Recipe sent to printer',
                              );
                            },
                            tooltip: 'Print recipe',
                            icon: const Icon(
                              Icons.print_outlined,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              AppSnackbar.show(
                                context,
                                message: 'Recipe link copied to clipboard',
                              );
                            },
                            tooltip: 'Share recipe',
                            icon: const Icon(
                              Icons.share_outlined,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          IconButton(
                            onPressed: _socialLoading ? null : _toggleBookmark,
                            tooltip: _isBookmarked
                                ? 'Remove bookmark'
                                : 'Save recipe',
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                key: ValueKey(_isBookmarked),
                                size: 20,
                                color: _isBookmarked
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Metric Boxes Row (Prep, Cook, Serves)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              icon: Icons.access_time,
                              label: 'Prep',
                              value: recipe.approximatePrepTime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              icon: Icons.soup_kitchen_outlined,
                              label: 'Cook',
                              value: recipe.approximateCookTime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              icon: Icons.flatware,
                              label: 'Serves',
                              value: recipe.approximateServings,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Tabbed Content Container (Ingredients, Instructions, Chef's Tips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Column(
                  children: [
                    // Folder Tab Bar — the white active tab glides smoothly
                    // between Ingredients / Instructions / Chef's Tips.
                    Container(
                      padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBE6E0),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(19),
                        ),
                      ),
                      child: SlidingTabBar(
                        index: _activeTabIndex,
                        itemCount: 3,
                        highlight: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                        ),
                        onChanged: (i) => setState(() => _activeTabIndex = i),
                        builder: (context, i, isActive) {
                          const titles = [
                            'Ingredients',
                            'Instructions',
                            'Chef\'s Tips',
                          ];
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isActive
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                                child: Text(titles[i]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Tab Body Content — slides horizontally in the direction
                    // of the tapped tab between Ingredients / Instructions /
                    // Chef's Tips.
                    SlideTabSwitcher(
                      index: _activeTabIndex,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildActiveTabContent(recipe, chefsTips),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Community Discussion & Comments Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCommentsSection(recipe),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.textPrimary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(RecipeModel recipe, List<String> chefsTips) {
    switch (_activeTabIndex) {
      case 0:
        // Tab 1: Ingredients
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recipe.ingredients.map((ingredient) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                ingredient,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            );
          }).toList(),
        );

      case 1:
        // Tab 2: Instructions
        return Column(
          children: recipe.instructions.asMap().entries.map((entry) {
            final idx = entry.key;
            final (stepTitle, stepBody) = parseInstructionStep(
              idx,
              entry.value,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F0EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2DFD8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stepBody,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 2:
        // Tab 3: Chef's Tips
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: chefsTips.map((tip) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCommentsSection(RecipeModel recipe) {
    final user = FirebaseAuth.instance.currentUser;
    final recipeId = recipe.id;

    if (recipeId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Comments & Discussion',
                style: AppTypography.title(color: AppColors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Add comment box
          if (user == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F7F4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sign in to join the conversation and share tips!',
                      style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                      child: user.photoURL != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: user.photoURL!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Center(
                                  child: Text(
                                    user.displayName?.isNotEmpty == true
                                        ? user.displayName![0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                user.displayName?.isNotEmpty == true
                                    ? user.displayName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F7F4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _commentController,
                          maxLines: null,
                          minLines: 2,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Tried this recipe? Share your thoughts, substitutions, or tips...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingComment ? null : _handleSubmitComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _isSubmittingComment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isSubmittingComment ? 'Posting...' : 'Post Comment',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Real-time Stream of Comments
          StreamBuilder<List<CommentModel>>(
            stream: _commentRepo.getCommentsStream(recipeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No comments yet',
                        style: AppTypography.bodyStrong(
                          color: AppColors.textPrimary,
                        ).copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share your cooking experience with this dish!',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF0EFEA)),
                ),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  final isAuthor = user?.uid == comment.userId;
                  final isLiked = user != null && comment.isLikedBy(user.uid);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Commenter Avatar
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                          child: comment.userPhotoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(17),
                                  child: CachedNetworkImage(
                                    imageUrl: comment.userPhotoUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Center(
                                      child: Text(
                                        comment.userName.isNotEmpty
                                            ? comment.userName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    comment.userName.isNotEmpty
                                        ? comment.userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),

                        // Comment Bubble & Meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      comment.userName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${comment.timeAgo}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isAuthor)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Delete comment',
                                      onPressed: () => _handleDeleteComment(comment),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _handleToggleCommentLike(comment),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isLiked
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          size: 14,
                                          color: isLiked
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                        ),
                                        if (comment.likeCount > 0) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '${comment.likeCount}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isLiked
                                                  ? AppColors.error
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
