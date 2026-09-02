import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/auth_service_provider.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_loading_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/sign_up_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../recipes/presentation/recipe_creating_screen.dart';
import '../../social/data/favorites_repository.dart';
import '../../social/data/follow_repository.dart';
import '../../social/data/like_repository.dart';
import 'edit_profile_screen.dart';
import 'achievements_screen.dart';
import 'followers_screen.dart';
import 'widgets/app_right_sidebar.dart';
import 'widgets/dish_card_grid.dart';
import 'widgets/profile_header_widget.dart';

/// Full Profile Screen with real Firestore data.
///
/// Supports two modes:
/// - **Own profile**: when [targetUserId] is null, shows the logged-in user
/// - **Other user**: when [targetUserId] is set, shows that user's profile
///   with a follow button instead of edit.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.isGuest = false,
    this.onNavigateHome,
    this.targetUserId,
    this.initialTabIndex = 0,
  });

  final bool isGuest;
  final VoidCallback? onNavigateHome;

  /// When set, displays another user's profile instead of the logged-in user.
  final String? targetUserId;

  final int initialTabIndex;

  @override
  ConsumerState<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends ConsumerState<ProfileScreen> {
  late int _selectedTabIndex; // 0: Posts, 1: Likes, 2: Saved Recipes

  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  RecipeRepository get _recipeRepo => ref.read(recipeRepositoryProvider);
  LikeRepository get _likeRepo => ref.read(likeRepositoryProvider);
  FavoritesRepository get _favoritesRepo => ref.read(favoritesRepositoryProvider);
  FollowRepository get _followRepo => ref.read(followRepositoryProvider);

  UserModel? _userModel;
  List<RecipeModel> _userRecipes = [];
  List<RecipeModel> _likedRecipes = [];
  List<RecipeModel> _savedRecipes = [];
  bool _isLoading = true;
  bool _isLoadingLikes = false;
  bool _isLoadingSaved = false;
  bool _isFollowing = false;
  int? _topContributorRank;
  int? _mostCookedRank;
  bool _isChefOfMonth = false;
  int? _followingCount;
  int? _followerCount;
  int? _totalPostLikes;

  /// Generation counter to discard stale profile loads when navigating
  /// between different users rapidly.
  int _profileLoadGeneration = 0;

  /// Public method to reload profile data after recipe upload or profile edits.
  Future<void> refresh() async {
    await _loadProfileData();
    if (_selectedTabIndex == 1) {
      await _loadLikedRecipes(force: true);
    } else if (_selectedTabIndex == 2) {
      await _loadSavedRecipes(force: true);
    } else {
      if (mounted) {
        setState(() {
          _likedRecipes = [];
          _savedRecipes = [];
        });
      }
    }
  }

  /// Whether we are viewing our own profile or another user's.
  bool get _isOwnProfile {
    final currentUid = ref.read(currentUserIdProvider);
    return widget.targetUserId == null || widget.targetUserId == currentUid;
  }

  /// The UID being displayed.
  String? get _displayedUid =>
      widget.targetUserId ?? ref.read(currentUserIdProvider);

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _loadProfileData();
    if (_selectedTabIndex == 1) _loadLikedRecipes(force: true);
    if (_selectedTabIndex == 2) _loadSavedRecipes(force: true);
  }

  Future<void> _loadProfileData() async {
    final generation = ++_profileLoadGeneration;
    final uid = _displayedUid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // A recipe query must not hide the profile itself. In particular, a
      // missing recipe index or a transient query error used to discard the
      // freshly saved user document and leave the placeholder bio on screen.
      final user = await _userRepo.getUser(uid);

      if (mounted && generation == _profileLoadGeneration) {
        setState(() {
          _userModel = user;
          _isLoading = false;
        });
      }

      List<RecipeModel> recipes = [];
      try {
        recipes = await _recipeRepo.recipesByAuthor(
          uid,
          includePending: _isOwnProfile,
        );
      } catch (_) {
        // Keep the loaded profile usable even when posts cannot load.
      }

      // Check follow status if viewing another user.
      bool following = false;
      final currentUid = ref.read(currentUserIdProvider);
      if (!_isOwnProfile && currentUid != null) {
        following = await _followRepo.isFollowing(
          currentUid: currentUid,
          targetUid: uid,
        );
      }

      int? topContributorRank;
      int? mostCookedRank;
      bool isChefOfMonth = false;
      try {
        final rankings = await Future.wait([
          _userRepo.topContributorsByFollowers(limit: 100),
          _userRepo.mostCookedByUploadedRecipes(limit: 100),
          _recipeRepo.recipesCreatedThisMonth(),
        ]);
        topContributorRank = _rankForUser(
          rankings[0] as List<UserModel>,
          uid,
        );
        mostCookedRank = _rankForUser(rankings[1] as List<UserModel>, uid);
        final monthRecipes = rankings[2] as List<RecipeModel>;
        isChefOfMonth =
            monthRecipes.isNotEmpty && monthRecipes.first.authorId == uid;
      } catch (_) {}

      // Fetch real-time count of following and followers directly from subcollections
      int? followingCount;
      int? followerCount;
      try {
        final followingFuture = _followRepo.getFollowingIds(uid);
        final followerFuture = _followRepo.getFollowerIds(uid);
        final counts = await Future.wait([followingFuture, followerFuture]);
        followingCount = counts[0].length;
        followerCount = counts[1].length;
      } catch (_) {}

      // Calculate total likes received across all of the author's recipe posts
      final totalPostLikes = recipes.fold<int>(
        0,
        (acc, recipe) => acc + recipe.likeCount,
      );

      // Discard if a newer profile load has started.
      if (mounted && generation == _profileLoadGeneration) {
        final updatedUser = (user ?? _userModel)?.copyWith(
          totalLikesReceived: totalPostLikes,
        );
        setState(() {
          _userModel = updatedUser ?? _userModel;
          _userRecipes = recipes;
          _totalPostLikes = totalPostLikes;
          _isFollowing = following;
          _topContributorRank = topContributorRank;
          _mostCookedRank = mostCookedRank;
          _isChefOfMonth = isChefOfMonth;
          _followingCount = followingCount;
          _followerCount = followerCount;
        });

        // Self-heal user document in Firestore if followingCount or totalLikesReceived is out of sync and it is own profile
        if (_isOwnProfile && user != null) {
          final updates = <String, dynamic>{};
          if (followingCount != null && user.followingCount != followingCount) {
            updates['followingCount'] = followingCount;
          }
          if (user.totalLikesReceived != totalPostLikes) {
            updates['totalLikesReceived'] = totalPostLikes;
          }
          if (updates.isNotEmpty) {
            ref.read(firebaseFirestoreProvider).collection('users').doc(uid).set(
              updates,
              SetOptions(merge: true),
            );
          }
        }
      }
    } catch (_) {
      if (mounted && generation == _profileLoadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  int? _rankForUser(List<UserModel> users, String uid) {
    final index = users.indexWhere((user) => user.uid == uid);
    return index == -1 ? null : index + 1;
  }

  /// Loads liked recipes.
  Future<void> _loadLikedRecipes({bool force = false}) async {
    if (!force && _likedRecipes.isNotEmpty) return;
    final uid = _displayedUid;
    if (uid == null) return;
    if (mounted) setState(() => _isLoadingLikes = true);
    try {
      final recipes = await _likeRepo.getLikedRecipes(uid);
      if (mounted) {
        setState(() {
          _likedRecipes = recipes;
          _isLoadingLikes = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLikes = false);
    }
  }

  /// Loads saved recipes.
  Future<void> _loadSavedRecipes({bool force = false}) async {
    if (!force && _savedRecipes.isNotEmpty) return;
    final uid = _displayedUid;
    if (uid == null) return;
    if (mounted) setState(() => _isLoadingSaved = true);
    try {
      final recipes = await _favoritesRepo.getSavedRecipes(uid);
      if (mounted) {
        setState(() {
          _savedRecipes = recipes;
          _isLoadingSaved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = ref.read(currentUserIdProvider);
    final targetUid = _displayedUid;
    if (currentUid == null || targetUid == null) return;
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      final newState = await _followRepo.toggleFollow(
        currentUid: currentUid,
        targetUid: targetUid,
        currentUserName: currentUser?.displayName,
        currentUserPhotoUrl: currentUser?.photoURL,
      );
      if (mounted) {
        setState(() {
          _isFollowing = newState;
          if (_userModel != null) {
            final currentCount = _userModel!.followerCount;
            _userModel = _userModel!.copyWith(
              followerCount: newState
                  ? currentCount + 1
                  : (currentCount > 0 ? currentCount - 1 : 0),
            );
          }
        });
        AppSnackbar.show(
          context,
          message: newState ? 'Following chef' : 'Unfollowed chef',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Could not update follow status: $e');
      }
    }
  }

  void _showOptionsMenu(BuildContext context) {
    showAppRightSidebar(
      context: context,
      isGuest: widget.isGuest,
    );
  }

  void _navigateToFollowersScreen({int initialTab = 0}) {
    final uid = _displayedUid;
    if (uid == null) return;
    final name = _userModel?.displayName ?? 'User';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowersScreen(
          userId: uid,
          displayName: name,
          initialTab: initialTab,
        ),
      ),
    ).then((_) => _loadProfileData());
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    ).then((_) {
      // Reload profile data when returning from edit screen.
      _loadProfileData();
    });
  }

  void _onTabSelected(int index) {
    setState(() => _selectedTabIndex = index);
    if (index == 1) _loadLikedRecipes(force: true);
    if (index == 2) _loadSavedRecipes(force: true);
  }

  void _onRecipeTap(RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    ).then((_) {
      if (mounted) {
        _loadProfileData();
        if (_selectedTabIndex == 1) _loadLikedRecipes(force: true);
        if (_selectedTabIndex == 2) _loadSavedRecipes(force: true);
      }
    });
  }

  void _showPostOptionsSheet(RecipeModel recipe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.textPrimary),
                title: Text(
                  'Edit Recipe',
                  style: AppTypography.body(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeCreatingScreen(recipeToEdit: recipe),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _loadProfileData();
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text(
                  'Delete Recipe',
                  style: AppTypography.body(color: AppColors.error)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _showDeleteConfirmationDialog(recipe);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(RecipeModel recipe) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Post?',
            style: AppTypography.headline(color: AppColors.textPrimary)
                .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will permanently remove "${recipe.name}" and all its data. This action cannot be undone.',
            style: AppTypography.body(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: AppTypography.body(color: AppColors.textSecondary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx); // Close dialog

                final recipeId = recipe.id;
                if (recipeId == null) return;

                // Optimistically remove from state so the recipe grid updates immediately
                final previousUserRecipes = List<RecipeModel>.from(_userRecipes);
                setState(() {
                  _userRecipes.removeWhere((r) => r.id == recipeId);
                });

                try {
                  await AppLoadingDialog.runWithLoading(
                    context,
                    () => _recipeRepo.deleteRecipe(recipeId),
                    message: 'Deleting recipe...',
                  );
                  if (mounted) {
                    AppSnackbar.show(
                      context,
                      message: 'Post deleted successfully.',
                    );
                    _loadProfileData();
                  }
                } catch (e) {
                  // Revert on error
                  if (mounted) {
                    setState(() {
                      _userRecipes = previousUserRecipes;
                    });
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
        );
      },
    );
  }

  List<RecipeModel> _getTabRecipes() {
    switch (_selectedTabIndex) {
      case 0:
        return _userRecipes;
      case 1:
        return _likedRecipes;
      case 2:
        return _savedRecipes;
      default:
        return _userRecipes;
    }
  }

  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              children: [
                // 1. Top App Bar (Back Arrow, Title "Profile", Hamburger Options)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH - 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            widget.onNavigateHome?.call();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        tooltip: 'Back',
                      ),
                      Text(
                        'Profile',
                        style: AppTypography.headline(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                      HamburgerButton(
                        onTap: () => _showOptionsMenu(context),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Create Account / Guest View
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Prominent Visual Icon / Badge
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.accent.withValues(alpha: 0.22),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title & Subtitle
                        Text(
                          'Create an Account',
                          style: AppTypography.headline(
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Join La Mia to share your family recipes, bookmark favorites, follow top chefs, and compete on the leaderboard.',
                            style: AppTypography.body(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 14, height: 1.45),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Perks / Features list
                        _buildFeatureTile(
                          icon: Icons.soup_kitchen_rounded,
                          iconColor: AppColors.primary,
                          title: 'Publish Secret Recipes',
                          subtitle:
                              'Upload step-by-step cooking guides, ingredients, and mouthwatering photos.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureTile(
                          icon: Icons.bookmark_added_rounded,
                          iconColor: AppColors.secondary,
                          title: 'Save & Collect Favorites',
                          subtitle:
                              'Bookmark irresistible recipes to cook anytime from your personalized collection.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureTile(
                          icon: Icons.workspace_premium_rounded,
                          iconColor: AppColors.accent,
                          title: 'Earn Chef Rankings',
                          subtitle:
                              'Receive likes from fellow foodies and get featured on the community leaderboard.',
                        ),

                        const SizedBox(height: 28),

                        // Main Call to Action: Create an Account button
                        PrimaryButton(
                          label: 'Create an Account',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            ).then((_) => _loadProfileData());
                          },
                        ),

                        const SizedBox(height: 12),

                        // Secondary Action: Log In button
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ).then((_) => _loadProfileData());
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.button),
                            ),
                            backgroundColor: AppColors.surface,
                          ),
                          child: Text(
                            'Already have an account? Log In',
                            style: AppTypography.button(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyStrong(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwnProfile && widget.isGuest) {
      return _buildGuestView(context);
    }

    final user = ref.read(authServiceProvider).currentUser;
    final displayName =
        _isOwnProfile
            ? (_userModel?.displayName ??
                  (widget.isGuest
                      ? 'Guest Foodie'
                      : (user?.displayName ??
                            user?.email?.split('@').first ??
                            'Chef Foodie')))
            : (_userModel?.displayName ?? 'Chef');
    // When viewing another user, never fall back to the logged-in user's photo.
    final photoUrl =
        _isOwnProfile
            ? (_userModel?.photoUrl ??
                  (widget.isGuest ? null : user?.photoURL))
            : _userModel?.photoUrl;
    final bio =
        _isOwnProfile
            ? (_userModel?.bio ??
                  (widget.isGuest
                      ? 'Browsing as guest foodie. Sign in to post family recipes!'
                      : null))
            : _userModel?.bio;
    final achievements = AchievementCatalog.forUser(
      _userModel,
      isChefOfMonth: _isChefOfMonth,
    );
    final achievementXp = achievements
        .where((achievement) => achievement.isUnlocked)
        .fold<int>(
          0,
          (total, achievement) => total + achievement.xpReward,
        );
    final achievementLevel = _userModel == null
        ? null
        : AchievementLevel.fromXp(achievementXp);
    final featuredAchievement = _userModel?.featuredAchievementId != null
        ? achievements
            .where(
              (a) =>
                  a.id == _userModel!.featuredAchievementId &&
                  a.isUnlocked,
            )
            .firstOrNull
        : null;

    final tabRecipes = _getTabRecipes();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              children: [
                // 1. Top App Bar (Back Arrow, Title "Profile", Hamburger Options)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH - 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            widget.onNavigateHome?.call();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        tooltip: 'Back',
                      ),
                      Text(
                        _isOwnProfile ? 'Profile' : displayName,
                        style: AppTypography.headline(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                      if (_isOwnProfile)
                        HamburgerButton(
                          onTap: () => _showOptionsMenu(context),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 380
                          ? AppSpacing.md
                          : AppSpacing.screenH,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. Profile Header (Avatar, Nickname, @handle, Bio, #ranking badge, Achievements callout, Stats)
                        ProfileHeaderWidget(
                          displayName: displayName,
                          username: _userModel?.displayName != null
                              ? _userModel!.displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')
                              : (user?.displayName?.toLowerCase().replaceAll(RegExp(r'\s+'), '_') ??
                                  user?.email?.split('@').first),
                          photoUrl: photoUrl,
                          bio: bio,
                          rankingLabel: _topContributorRank != null
                              ? '#$_topContributorRank ranking'
                              : (_mostCookedRank != null
                                  ? '#$_mostCookedRank ranking'
                                  : (achievementLevel != null
                                      ? '#Level ${achievementLevel.number} ranking'
                                      : (_userRecipes.isNotEmpty
                                          ? '#${_userRecipes.length} ranking'
                                          : '#24 ranking'))),
                          achievementLevelLabel: achievementLevel == null
                              ? null
                              : 'Level ${achievementLevel.number} ${achievementLevel.title}',
                          onAchievementsTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AchievementsScreen(
                                  isGuest: widget.isGuest,
                                  user: _userModel,
                                  isChefOfMonth: _isChefOfMonth,
                                ),
                              ),
                            );
                          },
                          recognitions: [
                            if (featuredAchievement != null)
                              ProfileRecognition(
                                label: featuredAchievement.title,
                                icon: featuredAchievement.icon,
                                color: featuredAchievement.badgeColor,
                                detail: '⭐ Equipped',
                                onTap: _isOwnProfile ? _navigateToEditProfile : null,
                              )
                            else if (_isOwnProfile && !widget.isGuest)
                              ProfileRecognition(
                                label: 'Showcase Badge',
                                icon: Icons.military_tech_outlined,
                                color: AppColors.secondary,
                                detail: '+ Equip',
                                onTap: _navigateToEditProfile,
                              ),
                            if (_topContributorRank != null)
                              ProfileRecognition(
                                label: 'Top Contributor',
                                detail: '#$_topContributorRank',
                                icon: Icons.people_alt_rounded,
                                color: AppColors.secondary,
                              )
                            else
                              const ProfileRecognition(
                                label: 'Top Contributor',
                                icon: Icons.people_alt_rounded,
                                color: AppColors.secondary,
                              ),
                            if (_mostCookedRank != null)
                              ProfileRecognition(
                                label: 'Most Cooked',
                                detail: '#$_mostCookedRank',
                                icon: Icons.restaurant_menu_rounded,
                                color: AppColors.primary,
                              )
                            else
                              const ProfileRecognition(
                                label: 'Most Cooked',
                                icon: Icons.restaurant_menu_rounded,
                                color: AppColors.primary,
                              ),
                            if (_isChefOfMonth)
                              const ProfileRecognition(
                                label: 'Chef of the Month',
                                icon: Icons.workspace_premium_rounded,
                                color: AppColors.accent,
                              ),
                          ],
                          recipeCount: widget.isGuest
                              ? '0'
                              : _userRecipes.length.toString(),
                          likesCount: widget.isGuest
                              ? '0'
                              : (_totalPostLikes?.toString() ??
                                  _userModel?.totalLikesReceived.toString() ??
                                  '0'),
                          followersCount: widget.isGuest
                              ? '0'
                              : (_followerCount?.toString() ??
                                  _userModel?.followerCount.toString() ??
                                  '0'),
                          followingCount: widget.isGuest
                              ? '0'
                              : (_followingCount?.toString() ??
                                  _userModel?.followingCount.toString() ??
                                  '0'),
                          isGuest: widget.isGuest,
                          isOwnProfile: _isOwnProfile,
                          isFollowing: _isFollowing,
                          onEditProfileTap: _isOwnProfile
                              ? _navigateToEditProfile
                              : null,
                          onFollowTap: !_isOwnProfile ? _toggleFollow : null,
                          onRecipesTap: () => _onTabSelected(0),
                          onLikesTap: () => _onTabSelected(1),
                          onFollowersTap: () =>
                              _navigateToFollowersScreen(initialTab: 0),
                          onFollowingTap: () =>
                              _navigateToFollowersScreen(initialTab: 1),
                        ),

                        const SizedBox(height: 14),

                        // 3. Tab Bar with 3 Icons matching wireframe (Posts | Likes | Saved)
                        _buildWireframeTabBar(),

                        const SizedBox(height: 14),

                        // 4. 3-Column Dish Cards Grid
                        DishCardGrid(
                          recipes: tabRecipes,
                          isLoading: _isLoading ||
                              (_selectedTabIndex == 1 && _isLoadingLikes) ||
                              (_selectedTabIndex == 2 && _isLoadingSaved),
                          emptyMessage: _selectedTabIndex == 0
                              ? 'No recipe posts created yet'
                              : _selectedTabIndex == 1
                              ? 'No liked recipes yet'
                              : 'No saved recipes yet',
                          onRecipeTap: _onRecipeTap,
                          onRecipeLongPress: (_isOwnProfile && _selectedTabIndex == 0 && !widget.isGuest)
                              ? _showPostOptionsSheet
                              : null,
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWireframeTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTabIconButton(
            index: 0,
            icon: _selectedTabIndex == 0
                ? Icons.drafts_rounded
                : Icons.drafts_outlined,
            tooltip: 'Posts',
          ),
          _buildTabIconButton(
            index: 1,
            icon: _selectedTabIndex == 1
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            tooltip: 'Likes',
          ),
          if (_isOwnProfile)
            _buildTabIconButton(
              index: 2,
              icon: _selectedTabIndex == 2
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              tooltip: 'Saved Recipes',
            ),
        ],
      ),
    );
  }

  Widget _buildTabIconButton({
    required int index,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: PressableScale(
          pressedScale: 0.93,
          onTap: () => _onTabSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 7.5),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.onPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

