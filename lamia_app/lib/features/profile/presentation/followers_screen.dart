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

/// Full standalone screen displaying all followers of a user.
class FollowersScreen extends StatefulWidget {
  const FollowersScreen({
    super.key,
    required this.userId,
    required this.displayName,
  });

  final String userId;
  final String displayName;

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FollowRepository _followRepo = FollowRepository();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allFollowers = [];
  List<UserModel> _filteredFollowers = [];
  final Set<String> _followingIds = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoading = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final results = await _followRepo.getFollowers(widget.userId);

      Set<String> following = {};
      if (currentUid != null) {
        final followingList = await _followRepo.getFollowingIds(currentUid);
        following = followingList.toSet();
      }

      if (mounted) {
        setState(() {
          _allFollowers = results;
          _followingIds.addAll(following);
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

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredFollowers = List.from(_allFollowers);
    } else {
      _filteredFollowers = _allFollowers.where((u) {
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
      await _followRepo.toggleFollow(
        currentUid: currentUid,
        targetUid: user.uid,
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
                              'Followers',
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
                      if (!_isLoading && _allFollowers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${_allFollowers.length}',
                            style: AppTypography.caption(
                              color: AppColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Search Bar (if more than 3 followers or active search)
                if (_allFollowers.length > 3 || _searchQuery.isNotEmpty)
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
                          hintText: 'Search followers...',
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

                // 3. Followers List Content
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
                          onRefresh: _loadFollowers,
                          child: _filteredFollowers.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: MediaQuery.sizeOf(context).height * 0.45,
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
                                                    ? 'No followers found'
                                                    : 'No followers yet',
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
                                                    : 'When foodies follow ${widget.displayName}, they will appear here.',
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
                                  itemCount: _filteredFollowers.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final follower = _filteredFollowers[index];
                                    final isSelf = currentUid != null &&
                                        follower.uid == currentUid;
                                    final isFollowing =
                                        _followingIds.contains(follower.uid);
                                    final initial = follower.displayName.isNotEmpty
                                        ? follower.displayName[0].toUpperCase()
                                        : 'U';

                                    return PressableScale(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                              targetUserId: follower.uid,
                                            ),
                                          ),
                                        ).then((_) => _loadFollowers());
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
                                                child: follower.photoUrl != null &&
                                                        follower.photoUrl!.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: follower.photoUrl!,
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
                                                    follower.displayName,
                                                    style: AppTypography.bodyStrong(
                                                      color: AppColors.textPrimary,
                                                    ).copyWith(fontSize: 15),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  if (follower.bio != null &&
                                                      follower.bio!.trim().isNotEmpty)
                                                    Text(
                                                      follower.bio!.trim(),
                                                      style: AppTypography.caption(
                                                        color: AppColors.textSecondary,
                                                      ).copyWith(fontSize: 12),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  else
                                                    Text(
                                                      '${follower.recipeCount} ${follower.recipeCount == 1 ? 'recipe' : 'recipes'} • ${follower.followerCount} ${follower.followerCount == 1 ? 'follower' : 'followers'}',
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
                                                    _toggleFollowUser(follower),
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
