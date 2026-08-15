import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/slide_tab_switcher.dart';
import '../../../core/widgets/sliding_tab_bar.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import 'widgets/dish_card_grid.dart';
import 'widgets/profile_header_widget.dart';

/// Full Profile Screen designed according to the wireframe.
///
/// Includes App Bar (Back, Title, Hamburger options), Profile Header,
/// Stat row, Tab Switcher (Posts, Likes, Saved Recipes), and 2-column Dish Grid.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isGuest = false, this.onNavigateHome});

  final bool isGuest;
  final VoidCallback? onNavigateHome;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTabIndex = 0; // 0: Posts, 1: Likes, 2: Saved Recipes
  final RecipeRepository _recipeRepository = RecipeRepository();

  List<RecipeModel> _allRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final recipes = await _recipeRepository.allRecipes(limit: 20);
      if (mounted) {
        setState(() {
          _allRecipes = recipes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onSignOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(fadePageRoute(const LoginScreen()), (_) => false);
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit profile coming soon!'),
                      ),
                    );
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
                    setState(() => _selectedTabIndex = 2);
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
                      const SnackBar(content: Text('Preferences coming soon!')),
                    );
                  },
                ),
                const Divider(height: 24),
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

  void _onRecipeTap(RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  List<RecipeModel> _getTabRecipes() {
    if (_allRecipes.isEmpty) return [];
    switch (_selectedTabIndex) {
      case 0:
        // Posts (take first 6 recipes as user posts)
        return _allRecipes.take(6).toList();
      case 1:
        // Likes (take next subset)
        return _allRecipes.skip(2).take(6).toList();
      case 2:
        // Saved Recipes
        return _allRecipes.skip(4).take(6).toList();
      default:
        return _allRecipes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = widget.isGuest
        ? 'Guest Foodie'
        : (user?.displayName ?? user?.email?.split('@').first ?? 'Chef Foodie');
    final photoUrl = widget.isGuest ? null : user?.photoURL;

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
                        'Profile',
                        style: AppTypography.headline(
                          color: AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                      ),
                      IconButton(
                        onPressed: () => _showOptionsMenu(context),
                        icon: const Icon(
                          Icons.menu_rounded,
                          color: AppColors.textPrimary,
                          size: 26,
                        ),
                        tooltip: 'Menu Options',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Profile Header (Avatar, Badge, Bio, Stats)
                  // Stats placeholders (`—`) until real user stats ship —
                  // don't fabricate follower/like counts.
                  ProfileHeaderWidget(
                    displayName: displayName,
                    photoUrl: photoUrl,
                    bio: widget.isGuest
                        ? 'Browsing as guest foodie. Sign in to post family recipes!'
                        : 'Passionate home cook & Filipino food lover. Sharing traditional family recipes!',
                    ranking: '— ranking',
                    recipesCount: widget.isGuest ? '0' : '—',
                    likesCount: widget.isGuest ? '0' : '—',
                    followersCount: widget.isGuest ? '0' : '—',
                    isGuest: widget.isGuest,
                    onEditProfileTap: () => _showOptionsMenu(context),
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
                      itemCount: 3,
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
                      onChanged: (i) => setState(() => _selectedTabIndex = i),
                      builder: (context, i, isSelected) {
                        const tabs = [
                          (
                            label: 'Posts',
                            icon: Icons.mark_email_unread_outlined,
                          ),
                          (
                            label: 'Likes',
                            icon: Icons.favorite_border_rounded,
                          ),
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
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  style: AppTypography.caption(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ).copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                  child: Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. 2-Column Dish Cards Grid matching wireframe — slides
                  // between Posts / Likes / Saved Recipes.
                  SlideTabSwitcher(
                    index: _selectedTabIndex,
                    child: DishCardGrid(
                      recipes: tabRecipes,
                      isLoading: _isLoading,
                      emptyMessage: _selectedTabIndex == 0
                          ? 'No recipe posts created yet'
                          : _selectedTabIndex == 1
                          ? 'No liked recipes yet'
                          : 'No saved recipes yet',
                      onRecipeTap: _onRecipeTap,
                    ),
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
