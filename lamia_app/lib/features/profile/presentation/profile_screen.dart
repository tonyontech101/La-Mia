import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/sign_up_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../social/data/favorites_repository.dart';
import '../../social/data/follow_repository.dart';
import '../../social/data/like_repository.dart';
import 'edit_profile_screen.dart';
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
class ProfileScreen extends StatefulWidget {
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
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  late int _selectedTabIndex; // 0: Posts, 1: Likes, 2: Saved Recipes

  final UserRepository _userRepo = UserRepository();
  final RecipeRepository _recipeRepo = RecipeRepository();
  final LikeRepository _likeRepo = LikeRepository();
  final FavoritesRepository _favoritesRepo = FavoritesRepository();
  final FollowRepository _followRepo = FollowRepository();

  UserModel? _userModel;
  List<RecipeModel> _userRecipes = [];
  List<RecipeModel> _likedRecipes = [];
  List<RecipeModel> _savedRecipes = [];
  bool _isLoading = true;
  bool _isLoadingLikes = false;
  bool _isLoadingSaved = false;
  bool _isFollowing = false;
  int? _userRank;

  /// Generation counter to discard stale profile loads when navigating
  /// between different users rapidly.
  int _profileLoadGeneration = 0;

  /// Public method to reload profile data after recipe upload or profile edits.
  Future<void> refresh() async {
    if (mounted) {
      setState(() {
        _likedRecipes = [];
        _savedRecipes = [];
      });
    }
    await _loadProfileData();
    if (_selectedTabIndex == 1) await _loadLikedRecipes();
    if (_selectedTabIndex == 2) await _loadSavedRecipes();
  }

  /// Whether we are viewing our own profile or another user's.
  bool get _isOwnProfile {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return widget.targetUserId == null || widget.targetUserId == currentUid;
  }

  /// The UID being displayed.
  String? get _displayedUid =>
      widget.targetUserId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _loadProfileData();
    if (_selectedTabIndex == 1) _loadLikedRecipes();
    if (_selectedTabIndex == 2) _loadSavedRecipes();
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
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (!_isOwnProfile && currentUid != null) {
        following = await _followRepo.isFollowing(
          currentUid: currentUid,
          targetUid: uid,
        );
      }

      // Fetch leaderboard ranking for this user (null if unranked).
      int? rank;
      try {
        rank = await _userRepo.getUserLeaderboardRank(uid);
      } catch (_) {}

      // Discard if a newer profile load has started.
      if (mounted && generation == _profileLoadGeneration) {
        setState(() {
          _userRecipes = recipes;
          _isFollowing = following;
          _userRank = rank;
        });
      }
    } catch (_) {
      if (mounted && generation == _profileLoadGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Lazily loads liked recipes when the Likes tab is first selected.
  Future<void> _loadLikedRecipes() async {
    if (_likedRecipes.isNotEmpty) return;
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

  /// Lazily loads saved recipes when the Saved tab is first selected.
  Future<void> _loadSavedRecipes() async {
    if (_savedRecipes.isNotEmpty) return;
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = _displayedUid;
    if (currentUid == null || targetUid == null) return;
    try {
      final newState = await _followRepo.toggleFollow(
        currentUid: currentUid,
        targetUid: targetUid,
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

  void _navigateToFollowersScreen() {
    final uid = _displayedUid;
    if (uid == null) return;
    final name = _userModel?.displayName ?? 'User';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowersScreen(
          userId: uid,
          displayName: name,
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
    if (index == 1) _loadLikedRecipes();
    if (index == 2) _loadSavedRecipes();
  }

  void _onRecipeTap(RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
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

    final user = FirebaseAuth.instance.currentUser;
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
                        // 2. Profile Header (Avatar, Badge, Bio, Stats)
                        ProfileHeaderWidget(
                          displayName: displayName,
                          photoUrl: photoUrl,
                          bio: bio,
                          ranking: _userRank != null ? '#$_userRank ranking' : null,
                          recipesCount: widget.isGuest
                              ? '0'
                              : (_userRecipes.isNotEmpty
                                  ? _userRecipes.length.toString()
                                  : (_userModel?.recipeCount.toString() ?? '0')),
                          followersCount:
                              _userModel?.followerCount.toString() ??
                              (widget.isGuest ? '0' : '0'),
                          likesCount:
                              _userModel?.totalLikesReceived.toString() ??
                              (widget.isGuest ? '0' : '0'),
                          isGuest: widget.isGuest,
                          isOwnProfile: _isOwnProfile,
                          isFollowing: _isFollowing,
                          onEditProfileTap: _isOwnProfile
                              ? _navigateToEditProfile
                              : null,
                          onFollowTap: !_isOwnProfile ? _toggleFollow : null,
                          onFollowersTap: _navigateToFollowersScreen,
                          onRecipesTap: () => _onTabSelected(0),
                          onLikesTap: () => _onTabSelected(1),
                        ),

                        const SizedBox(height: 24),

                        // 3. Tab Bar (Posts | Likes | Saved Recipes) matching wireframe
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.all(4),
                          // The white active pill glides smoothly between
                          // Posts / Likes / Saved Recipes.
                          child: SlidingTabBar(
                            index: _selectedTabIndex,
                            itemCount: _isOwnProfile ? 3 : 2,
                            highlight: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            onChanged: _onTabSelected,
                            builder: (context, i, isSelected) {
                              final tabs = [
                                (
                                  label: 'Posts',
                                  icon: Icons.mark_email_unread_outlined,
                                ),
                                (label: 'Likes', icon: Icons.favorite_border_rounded),
                                if (_isOwnProfile)
                                  (
                                    label: 'Saved Recipes',
                                    icon: Icons.bookmark_border_rounded,
                                  ),
                              ];
                              final tab = tabs[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedIconColor(
                                      icon: tab.icon,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        style:
                                            AppTypography.caption(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ).copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 11,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        child: Text(tab.label),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 4. 2-Column Dish Cards Grid
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
}

/// An [Icon] whose color fades smoothly to [color] whenever it changes.
class AnimatedIconColor extends StatelessWidget {
  const AnimatedIconColor({
    super.key,
    required this.icon,
    required this.color,
    this.size = 16,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedColor, _) {
        return Icon(icon, size: size, color: animatedColor);
      },
    );
  }
}

