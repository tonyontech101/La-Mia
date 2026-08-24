import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../auth/data/user_model.dart';
import '../../social/data/follow_repository.dart';
import 'profile_screen.dart';

/// Full standalone screen displaying Followers and Following lists for a user.
class FollowersScreen extends StatefulWidget {
  const FollowersScreen({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialTab = 0, // 0: Followers, 1: Following
  });

  final String userId;
  final String displayName;
  final int initialTab;

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FollowRepository _followRepo = FollowRepository();
  final TextEditingController _searchController = TextEditingController();

  late int _activeTab; // 0: Followers, 1: Following
  List<UserModel> _allFollowers = [];
  List<UserModel> _allFollowing = [];
  List<UserModel> _filteredUsers = [];
  final Set<String> _followingIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final followers = await _followRepo.getFollowers(widget.userId);
      final following = await _followRepo.getFollowing(widget.userId);
      final myFollowingList = currentUid != null
          ? await _followRepo.getFollowingIds(currentUid)
          : <String>[];

      if (mounted) {
        setState(() {
          _allFollowers = followers;
          _allFollowing = following;
          _followingIds.addAll(myFollowingList);
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<UserModel> get _currentList =>
      _activeTab == 0 ? _allFollowers : _allFollowing;

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    final current = _currentList;
    if (query.isEmpty) {
      _filteredUsers = List.from(current);
    } else {
      _filteredUsers = current.where((u) {
        final nameMatch = u.displayName.toLowerCase().contains(query);
        final bioMatch = u.bio?.toLowerCase().contains(query) ?? false;
        return nameMatch || bioMatch;
      }).toList();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilter();
    });
  }

  void _onTabChanged(int index) {
    if (_activeTab == index) return;
    setState(() {
      _activeTab = index;
      _applyFilter();
    });
  }

  Future<void> _toggleFollowUser(UserModel user) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == user.uid) return;

    final isCurrentlyFollowing = _followingIds.contains(user.uid);
    setState(() {
      if (isCurrentlyFollowing) {
        _followingIds.remove(user.uid);
      } else {
        _followingIds.add(user.uid);
      }
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await _followRepo.toggleFollow(
        currentUid: currentUid,
        targetUid: user.uid,
        currentUserName: currentUser?.displayName,
        currentUserPhotoUrl: currentUser?.photoURL,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isCurrentlyFollowing) {
            _followingIds.add(user.uid);
          } else {
            _followingIds.remove(user.uid);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

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
                // 1. Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH - 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeTab == 0 ? 'Followers' : 'Following',
                              style: AppTypography.headline(
                                color: AppColors.textPrimary,
                              ).copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              widget.displayName,
                              style: AppTypography.caption(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Tab Bar Switcher (Followers | Following)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Followers (${_allFollowers.length})',
                            isSelected: _activeTab == 0,
                            onTap: () => _onTabChanged(0),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Following (${_allFollowing.length})',
                            isSelected: _activeTab == 1,
                            onTap: () => _onTabChanged(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // 3. Search Bar
                if (_currentList.length > 3 || _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                      vertical: 6,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.cardShadow,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: AppTypography.body(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: _activeTab == 0
                              ? 'Search followers...'
                              : 'Search following...',
                          hintStyle: AppTypography.body(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // 4. List Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadData,
                          child: _filteredUsers.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.sizeOf(context).height * 0.40,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 72,
                                                height: 72,
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceAlt,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: AppColors.border,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.people_outline_rounded,
                                                  size: 36,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                _searchQuery.isNotEmpty
                                                    ? 'No users found'
                                                    : (_activeTab == 0
                                                        ? 'No followers yet'
                                                        : 'Not following anyone yet'),
                                                style: AppTypography.headline(
                                                  color: AppColors.textPrimary,
                                                ).copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _searchQuery.isNotEmpty
                                                    ? 'No one matches "$_searchQuery". Try another search.'
                                                    : (_activeTab == 0
                                                        ? 'When foodies follow ${widget.displayName}, they will appear here.'
                                                        : 'When ${widget.displayName} follows chefs, they will appear here.'),
                                                style: AppTypography.body(
                                                  color: AppColors.textSecondary,
                                                ).copyWith(fontSize: 13),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.screenH,
                                    vertical: 8,
                                  ),
                                  itemCount: _filteredUsers.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final user = _filteredUsers[index];
                                    final isSelf = currentUid != null &&
                                        user.uid == currentUid;
                                    final isFollowing =
                                        _followingIds.contains(user.uid);
                                    final initial = user.displayName.isNotEmpty
                                        ? user.displayName[0].toUpperCase()
                                        : 'U';

                                    return PressableScale(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                              targetUserId: user.uid,
                                            ),
                                          ),
                                        ).then((_) => _loadData());
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.card,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
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
                                            // Avatar
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.surfaceAlt,
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.35),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: ClipOval(
                                                child: user.photoUrl != null &&
                                                        user.photoUrl!.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: user.photoUrl!,
                                                        fit: BoxFit.cover,
                                                        placeholder: (context, url) =>
                                                            const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                        errorWidget: (context, url, error) =>
                                                            Center(
                                                          child: Text(
                                                            initial,
                                                            style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Center(
                                                        child: Text(
                                                          initial,
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Name & Bio & Recipe count
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    user.displayName,
                                                    style: AppTypography.bodyStrong(
                                                      color: AppColors.textPrimary,
                                                    ).copyWith(fontSize: 15),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  if (user.bio != null &&
                                                      user.bio!.trim().isNotEmpty)
                                                    Text(
                                                      user.bio!.trim(),
                                                      style: AppTypography.caption(
                                                        color: AppColors.textSecondary,
                                                      ).copyWith(fontSize: 12),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  else
                                                    Text(
                                                      '${user.recipeCount} ${user.recipeCount == 1 ? 'recipe' : 'recipes'} • ${user.followerCount} ${user.followerCount == 1 ? 'follower' : 'followers'}',
                                                      style: AppTypography.caption(
                                                        color: AppColors.textSecondary
                                                            .withValues(alpha: 0.75),
                                                      ).copyWith(fontSize: 11),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Follow / Following Action Button
                                            if (!isSelf && currentUid != null) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _toggleFollowUser(user),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isFollowing
                                                      ? AppColors.surfaceAlt
                                                      : AppColors.primary,
                                                  foregroundColor: isFollowing
                                                      ? AppColors.textPrimary
                                                      : AppColors.onPrimary,
                                                  elevation: isFollowing ? 0 : 2,
                                                  shape: const StadiumBorder(),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                                  side: isFollowing
                                                      ? const BorderSide(
                                                          color: AppColors.border,
                                                        )
                                                      : BorderSide.none,
                                                ),
                                                child: Text(
                                                  isFollowing ? 'Following' : '+ Follow',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.caption(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
