import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_loading_dialog.dart';
import '../../../core/widgets/slide_tab_switcher.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../social/data/follow_repository.dart';
import '../../social/presentation/widgets/comment_section.dart';
import '../data/recipe_model.dart';
import '../utils/recipe_share_helper.dart';
import 'notifiers/recipe_detail_notifier.dart';
import 'recipe_creating_screen.dart';
import 'widgets/planner_slot_picker.dart';
import 'widgets/popping_rating_bar.dart';
import 'widgets/vertical_popping_button.dart';

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
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.screenTitle = 'Featured Recipe',
  });

  final RecipeModel recipe;
  final String screenTitle;

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int _activeTabIndex = 0; // 0: Ingredients, 1: Instructions, 2: Chef's Tips

  @override
  void initState() {
    super.initState();
    // Schedule social-state load after the first frame so ref is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(recipeDetailNotifierProvider(widget.recipe).notifier)
          .loadSocialState();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openMoreMenu() {
    final detailState = ref.read(recipeDetailNotifierProvider(widget.recipe));
    final recipe = detailState.recipe;
    final userId = ref.read(currentUserIdProvider);
    final isAuthor = userId != null &&
        recipe.authorId == userId &&
        !recipe.isSystemRecipe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title: Share to
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Share to',
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Row 1: Share options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildTikTokActionItem(
                      icon: Icons.ios_share_rounded,
                      label: 'Share this recipe',
                      iconColor: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareRecipe();
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildTikTokActionItem(
                      icon: Icons.link_rounded,
                      label: 'Copy link',
                      iconColor: const Color(0xFF27AE60),
                      backgroundColor: const Color(0xFF27AE60).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        final url = RecipeShareHelper.generateRecipeUrl(recipe.id ?? '');
                        Clipboard.setData(ClipboardData(text: url));
                        AppSnackbar.show(
                          context,
                          message: 'Recipe link copied to clipboard!',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 0.8,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),

              // Title: Recipe Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Recipe Actions',
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Row 2: Action options (horizontal scroll like TikTok)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildTikTokActionItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Add to planner',
                      iconColor: const Color(0xFFE67E22),
                      backgroundColor: const Color(0xFFE67E22).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openAddToPlannerPicker();
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildTikTokActionItem(
                      icon: Icons.shopping_basket_rounded,
                      label: 'Add to groceries',
                      iconColor: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final userId = ref.read(currentUserIdProvider);
                        if (userId == null) {
                          AppSnackbar.show(context, message: 'Please sign in to add to grocery list');
                          return;
                        }
                        try {
                          final groceryRepo = ref.read(groceryListRepositoryProvider);
                          await groceryRepo.addIngredientsFromRecipe(
                            userId: userId,
                            recipe: recipe,
                          );
                          if (mounted) {
                            AppSnackbar.show(
                              context,
                              message: '${recipe.ingredients.length} ingredients added to grocery list.',
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackbar.show(context, message: 'Could not add to grocery list: $e', isError: true);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildTikTokActionItem(
                      icon: Icons.flag_rounded,
                      label: 'Report',
                      iconColor: AppColors.error,
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showReportDialog(recipe);
                      },
                    ),
                    if (isAuthor) ...[
                      const SizedBox(width: 10),
                      _buildTikTokActionItem(
                        icon: Icons.edit_rounded,
                        label: 'Edit recipe',
                        iconColor: const Color(0xFF8E44AD),
                        backgroundColor: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeCreatingScreen(recipeToEdit: recipe),
                            ),
                          ).then((updated) {
                            if (updated == true) {
                              ref
                                  .read(recipeDetailNotifierProvider(widget.recipe).notifier)
                                  .reloadRecipe();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildTikTokActionItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        iconColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmDeleteRecipe();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Bottom Cancel Button (TikTok style)
              Container(
                height: 0.8,
                color: AppColors.border.withValues(alpha: 0.7),
              ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: const Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTikTokActionItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 54,
                height: 54,
                child: Center(
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(RecipeModel recipe) {
    String selectedReason = 'Inappropriate content';
    final reasons = [
      'Inappropriate content',
      'Misleading or dangerous recipe',
      'Spam or advertising',
      'Not an authentic or original recipe',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.flag_rounded, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text(
                'Report Recipe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please select why you are reporting this recipe:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ...reasons.map((reason) {
                final isSelected = selectedReason == reason;
                return InkWell(
                  onTap: () => setDialogState(() => selectedReason = reason),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                try {
                  FirebaseFirestore.instance.collection('reports').add({
                    'recipeId': recipe.id,
                    'recipeName': recipe.name,
                    'authorId': recipe.authorId,
                    'reporterId': ref.read(currentUserIdProvider),
                    'reason': selectedReason,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } catch (_) {}
                AppSnackbar.show(
                  context,
                  message: 'Report submitted. Thank you for keeping La Mia safe.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecipe() {
    final detailState = ref.read(recipeDetailNotifierProvider(widget.recipe));
    final recipe = detailState.recipe;
    final recipeId = recipe.id;
    if (recipeId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Recipe',
          style: AppTypography.headline(color: AppColors.textPrimary)
              .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this recipe permanently? This action cannot be undone.',
          style: AppTypography.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTypography.body(color: AppColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final recipeRepo = ref.read(recipeRepositoryProvider);
                await AppLoadingDialog.runWithLoading(
                  context,
                  () => recipeRepo.deleteRecipe(recipeId),
                  message: 'Deleting recipe...',
                );
                if (mounted) {
                  AppSnackbar.show(context, message: 'Recipe deleted successfully.');
                  Navigator.pop(context, true); // Pop details screen with refresh trigger
                }
              } catch (e) {
                if (mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Failed to delete recipe: $e',
                    isError: true,
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.body(color: AppColors.error)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddToPlannerPicker() {
    final detailState = ref.read(recipeDetailNotifierProvider(widget.recipe));
    final plannerRepo = ref.read(mealPlanRepositoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlannerSlotPicker(recipe: detailState.recipe, plannerRepo: plannerRepo),
    );
  }

  void _navigateToAuthorProfile() {
    final detailState = ref.read(recipeDetailNotifierProvider(widget.recipe));
    final recipe = detailState.recipe;
    final authorId = recipe.authorId;
    if (authorId == null || recipe.isSystemRecipe) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: authorId)),
    );
  }

  /// Shares a human-readable text summary of the recipe via the OS share sheet.
  Future<void> _shareRecipe() async {
    final detailState = ref.read(recipeDetailNotifierProvider(widget.recipe));
    final recipe = detailState.recipe;
    final authorProfile = (recipe.authorId != null && !recipe.isSystemRecipe)
        ? ref.read(userProfileProvider(recipe.authorId!)).valueOrNull
        : null;
    final authorName = (authorProfile != null && authorProfile.displayName.isNotEmpty)
        ? authorProfile.displayName
        : (recipe.authorName.isNotEmpty ? recipe.authorName : widget.recipe.authorName);

    final text = RecipeShareHelper.generateShareText(
      recipe: recipe,
      authorName: authorName,
    );

    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : null;

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: recipe.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // Graceful fallback for devices or environments where native share sheet is unavailable
      final url = RecipeShareHelper.generateRecipeUrl(recipe.id ?? '');
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Sharing is unavailable on this device. Recipe link copied!',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(recipeDetailNotifierProvider(widget.recipe));
    final recipe = detailState.recipe;
    final followingIds = ref.watch(currentUserFollowingIdsProvider).value;
    final followerIds = ref.watch(currentUserFollowerIdsProvider).value;
    final isFollowingAuthor = (recipe.authorId != null && followingIds != null)
        ? followingIds.contains(recipe.authorId)
        : detailState.isFollowing;
    final authorFollowsYou = recipe.authorId != null && followerIds?.contains(recipe.authorId) == true;
    final authorProfile = (recipe.authorId != null && !recipe.isSystemRecipe)
        ? ref.watch(userProfileProvider(recipe.authorId!)).valueOrNull
        : null;
    final effectiveAuthorName = (authorProfile != null && authorProfile.displayName.isNotEmpty)
        ? authorProfile.displayName
        : (recipe.authorName.isNotEmpty
            ? recipe.authorName
            : widget.recipe.authorName);
    final effectiveAuthorPhotoUrl = authorProfile?.photoUrl ??
        recipe.authorPhotoUrl ??
        widget.recipe.authorPhotoUrl;
    final chefsTips = recipe.chefsTips.isNotEmpty
        ? recipe.chefsTips
        : _defaultChefsTips;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textPrimary),
            onPressed: _openMoreMenu,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            // 1. Large Dish Image Banner (Hero)
            SizedBox(
              height: 250,
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
                        color: const Color(0xFFE5DDD0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.restaurant_rounded,
                              size: 54,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Dish Image',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

            // 2. Main Overlaid Summary Card (Single elevated card matching wireframe)
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Top-Right Rating Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              recipe.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Top Right Rating Badge Pill: ★ 4.9 (1.2k)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE7DD),
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  detailState.localRatingAvg > 0
                                      ? detailState.localRatingAvg.toStringAsFixed(1)
                                      : '4.9',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  detailState.localRatingCount > 0
                                      ? '(${detailState.localRatingCount >= 1000 ? "${(detailState.localRatingCount / 1000).toStringAsFixed(1)}k" : detailState.localRatingCount})'
                                      : '(1.2k)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Short description
                      Text(
                        recipe.description.isNotEmpty
                            ? recipe.description
                            : 'A popular ${recipe.category.toLowerCase()} recipe dated back in traditional Filipino culinary history.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tags Row (Dark capsule chips with white icons/text)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Chip 1: Prep/Cook Time
                          _buildCapsuleChip(
                            icon: Icons.access_time_rounded,
                            label: recipe.approximatePrepTime.isNotEmpty
                                ? recipe.approximatePrepTime
                                : (recipe.prepTime.isNotEmpty ? recipe.prepTime : '15 mins'),
                          ),
                          // Chip 2: Category
                          _buildCapsuleChip(
                            icon: Icons.egg_alt_outlined,
                            label: recipe.category.isNotEmpty ? recipe.category : 'Breakfast',
                          ),
                          // Chip 3: Difficulty
                          _buildCapsuleChip(
                            icon: Icons.restaurant_menu_rounded,
                            label: recipe.difficulty.isNotEmpty ? recipe.difficulty : 'Breakfast',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Author and Action Row
                      Row(
                        children: [
                          // Author Profile Link (Avatar + Username + Follow)
                          Expanded(
                            child: GestureDetector(
                              onTap: recipe.isSystemRecipe
                                  ? null
                                  : _navigateToAuthorProfile,
                              child: Row(
                                children: [
                                  // Circular Avatar
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFD6D1C9),
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: recipe.isSystemRecipe
                                          ? Image.asset(
                                              'assets/images/logo.png',
                                              width: 38,
                                              height: 38,
                                              fit: BoxFit.cover,
                                            )
                                          : effectiveAuthorPhotoUrl != null
                                              ? CachedNetworkImage(
                                                  imageUrl: effectiveAuthorPhotoUrl,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, _, _) => Center(
                                                    child: Text(
                                                      effectiveAuthorName.isNotEmpty
                                                          ? effectiveAuthorName[0].toUpperCase()
                                                          : 'U',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(
                                                    effectiveAuthorName.isNotEmpty
                                                        ? effectiveAuthorName[0].toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Username and Follow button
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          effectiveAuthorName.toLowerCase(),
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (!recipe.isSystemRecipe &&
                                            recipe.authorId != null &&
                                            recipe.authorId != ref.read(currentUserIdProvider)) ...[
                                          const SizedBox(height: 1),
                                          GestureDetector(
                                            onTap: detailState.socialLoading
                                                ? null
                                                : _handleFollowTap,
                                            child: Text(
                                              isFollowingAuthor
                                                  ? 'following'
                                                  : (authorFollowsYou ? 'follow back' : '+ follow'),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ] else if (recipe.isSystemRecipe) ...[
                                          const SizedBox(height: 2),
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.verified_rounded,
                                                size: 13,
                                                color: AppColors.primary,
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Official Recipe',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Social Buttons (Likes, Saves, Share)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Heart (Like) popping button
                              VerticalPoppingButton(
                                activeIcon: Icons.favorite_rounded,
                                inactiveIcon: Icons.favorite_rounded,
                                isActive: detailState.isLiked,
                                activeColor: AppColors.error,
                                inactiveColor: const Color(0xFF6E6259),
                                count: detailState.localLikeCount,
                                onTap: detailState.socialLoading
                                    ? () {}
                                    : _handleLikeTap,
                              ),
                              const SizedBox(width: 6),
                              // Bookmark (Save) popping button
                              VerticalPoppingButton(
                                activeIcon: Icons.bookmark_rounded,
                                inactiveIcon: Icons.bookmark_rounded,
                                isActive: detailState.isBookmarked,
                                activeColor: AppColors.primary,
                                inactiveColor: const Color(0xFF6E6259),
                                count: detailState.localFavoriteCount,
                                onTap: detailState.socialLoading
                                    ? () {}
                                    : _handleBookmarkTap,
                              ),
                              const SizedBox(width: 6),
                              // 3-dot More menu popping button
                              VerticalPoppingButton(
                                activeIcon: Icons.more_horiz_rounded,
                                inactiveIcon: Icons.more_horiz_rounded,
                                isActive: false,
                                activeColor: AppColors.textPrimary,
                                inactiveColor: const Color(0xFF6E6259),
                                showCount: false,
                                label: 'More',
                                onTap: _openMoreMenu,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Divider 1
                      const Divider(
                        color: AppColors.border,
                        height: 1,
                        thickness: 1.0,
                      ),
                      const SizedBox(height: 16),

                      // Metric Row (Prep, Cook, Serves)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricColumn(
                              icon: Icons.access_time_rounded,
                              label: 'Prep',
                              value: recipe.prepTime.isNotEmpty ? recipe.prepTime : '15m',
                            ),
                          ),
                          Expanded(
                            child: _buildMetricColumn(
                              icon: Icons.soup_kitchen_rounded,
                              label: 'Cook',
                              value: recipe.cookTime.isNotEmpty ? recipe.cookTime : '45m',
                            ),
                          ),
                          Expanded(
                            child: _buildMetricColumn(
                              icon: Icons.room_service_rounded,
                              label: 'Serves',
                              value: '${recipe.servings}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Divider 2
                      const Divider(
                        color: AppColors.border,
                        height: 1,
                        thickness: 1.0,
                      ),
                      const SizedBox(height: 16),

                      // Centered Rating Prompt & Interactive Stars
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'How do you rate this recipe?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            PoppingRatingBar(
                              initialRating: detailState.userRating,
                              onRatingChanged: _handleRateRecipe,
                              activeColor: AppColors.accent,
                              inactiveColor: const Color(0xFFDCD4CA),
                              starSize: 28,
                            ),
                          ],
                        ),
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
                    color: AppColors.border,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Folder Tab Bar
                    Container(
                      padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceAlt,
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
                                  fontSize: 12.5,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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

                    // Tab Body Content
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
              child: CommentSection(recipe: recipe),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF63564D), // Warm dark pill matching wireframe
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: AppColors.textPrimary),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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

  // ── Social action handlers that delegate to the notifier ──────────────

  Future<void> _handleLikeTap() async {
    final notifier =
        ref.read(recipeDetailNotifierProvider(widget.recipe).notifier);
    final result = await notifier.toggleLike();
    if (mounted && result.message != null) {
      AppSnackbar.show(context, message: result.message!, isError: result.isError);
    }
  }

  Future<void> _handleBookmarkTap() async {
    final notifier =
        ref.read(recipeDetailNotifierProvider(widget.recipe).notifier);
    final result = await notifier.toggleBookmark();
    if (mounted && result.message != null) {
      AppSnackbar.show(context, message: result.message!, isError: result.isError);
    }
  }

  Future<void> _handleFollowTap() async {
    final notifier =
        ref.read(recipeDetailNotifierProvider(widget.recipe).notifier);
    final result = await notifier.toggleFollow();
    if (mounted && result.message != null) {
      AppSnackbar.show(context, message: result.message!, isError: result.isError);
    }
  }

  Future<void> _handleRateRecipe(int rating) async {
    final notifier =
        ref.read(recipeDetailNotifierProvider(widget.recipe).notifier);
    final result = await notifier.handleRate(rating);
    if (mounted && result.message != null) {
      AppSnackbar.show(context, message: result.message!, isError: result.isError);
    }
  }
}
