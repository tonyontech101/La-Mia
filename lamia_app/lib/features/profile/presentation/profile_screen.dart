import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../../social/data/favorites_repository.dart';
import '../../social/data/follow_repository.dart';
import '../../social/data/like_repository.dart';
import 'edit_profile_screen.dart';
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
  });

  final bool isGuest;
  final VoidCallback? onNavigateHome;

  /// When set, displays another user's profile instead of the logged-in user.
  final String? targetUserId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTabIndex = 0; // 0: Posts, 1: Likes, 2: Saved Recipes

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
  bool _isFollowing = false;

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
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = _displayedUid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load user model + user's posted recipes in parallel.
      final results = await Future.wait([
        _userRepo.getUser(uid),
        _recipeRepo.recipesByAuthor(uid),
      ]);

      final user = results[0] as UserModel?;
      final recipes = results[1] as List<RecipeModel>;

      // Check follow status if viewing another user.
      bool following = false;
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (!_isOwnProfile && currentUid != null) {
        following = await _followRepo.isFollowing(
          currentUid: currentUid,
          targetUid: uid,
        );
      }

      if (mounted) {
        setState(() {
          _userModel = user;
          _userRecipes = recipes;
          _isFollowing = following;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lazily loads liked recipes when the Likes tab is first selected.
  Future<void> _loadLikedRecipes() async {
    if (_likedRecipes.isNotEmpty) return;
    final uid = _displayedUid;
    if (uid == null) return;
    try {
      final recipes = await _likeRepo.getLikedRecipes(uid);
      if (mounted) setState(() => _likedRecipes = recipes);
    } catch (_) {}
  }

  /// Lazily loads saved recipes when the Saved tab is first selected.
  Future<void> _loadSavedRecipes() async {
    if (_savedRecipes.isNotEmpty) return;
    final uid = _displayedUid;
    if (uid == null) return;
    try {
      final recipes = await _favoritesRepo.getSavedRecipes(uid);
      if (mounted) setState(() => _savedRecipes = recipes);
    } catch (_) {}
  }

  Future<void> _onSignOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadePageRoute(const LoginScreen()), (_) => false);
  }

  Future<void> _toggleFollow() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final targetUid = _displayedUid;
    if (currentUid == null || targetUid == null) return;
    final newState = await _followRepo.toggleFollow(
      currentUid: currentUid,
      targetUid: targetUid,
    );
    if (mounted) setState(() => _isFollowing = newState);
  }

  void _showOptionsMenu(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile Options',
                  style: AppTypography.title(
                    color: AppColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (_isOwnProfile) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Edit Profile'),
                    subtitle: Text(
                      widget.isGuest ? 'Guest user' : (user?.email ?? ''),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToEditProfile();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.bookmark_border_rounded,
                      color: AppColors.secondary,
                    ),
                    title: const Text('Saved Collections'),
                    onTap: () {
                      Navigator.pop(context);
                      _onTabSelected(2);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: const Text('Preferences & Dietary Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preferences coming soon!'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
                ],
                ListTile(
                  leading: Icon(
                    widget.isGuest ? Icons.login_rounded : Icons.logout_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    widget.isGuest ? 'Sign In / Register' : 'Sign Out',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _onSignOut();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        _userModel?.displayName ??
        (widget.isGuest
            ? 'Guest Foodie'
            : (user?.displayName ??
                  user?.email?.split('@').first ??
                  'Chef Foodie'));
    final photoUrl =
        _userModel?.photoUrl ?? (widget.isGuest ? null : user?.photoURL);
    final bio =
        _userModel?.bio ??
        (widget.isGuest
            ? 'Browsing as guest foodie. Sign in to post family recipes!'
            : null);

    final tabRecipes = _getTabRecipes();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top App Bar (Back Arrow, Title "Profile", Hamburger Options)
                  Row(
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
                        IconButton(
                          onPressed: () => _showOptionsMenu(context),
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: AppColors.textPrimary,
                            size: 26,
                          ),
                          tooltip: 'Menu Options',
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Profile Header (Avatar, Badge, Bio, Stats)
                  ProfileHeaderWidget(
                    displayName: displayName,
                    photoUrl: photoUrl,
                    bio: bio,
                    ranking: '— ranking',
                    recipesCount:
                        _userModel?.recipeCount.toString() ??
                        (widget.isGuest ? '0' : '—'),
                    likesCount:
                        _userModel?.totalLikesReceived.toString() ??
                        (widget.isGuest ? '0' : '—'),
                    followersCount:
                        _userModel?.followerCount.toString() ??
                        (widget.isGuest ? '0' : '—'),
                    isGuest: widget.isGuest,
                    isOwnProfile: _isOwnProfile,
                    isFollowing: _isFollowing,
                    onEditProfileTap: _isOwnProfile
                        ? _navigateToEditProfile
                        : null,
                    onFollowTap: !_isOwnProfile ? _toggleFollow : null,
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
                    isLoading: _isLoading,
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
