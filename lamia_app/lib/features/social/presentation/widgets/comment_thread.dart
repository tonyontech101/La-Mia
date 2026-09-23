import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../data/comment_model.dart';
import '../../data/comment_repository.dart';
import 'comment_input.dart';
import 'comment_tile.dart';
import 'view_replies_toggle.dart';

/// Renders one top-level comment + its full reply tree (any depth).
///
/// Replies arrive pre-fetched from [CommentSection] as:
/// - [directReplies] — children of this thread's parent
/// - [repliesByParent] — parent id → children, for recursive nesting
///
/// TikTok/Facebook-style behavior:
/// - Reply is available on the parent **and** every nested reply
/// - Single `_replyTarget` tracks which comment is being replied to
/// - Submit uses that target's id as `parentCommentId` and notifies its author
/// - Depth ≥ 2 tiles show "Replying to @name"
class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.parent,
    required this.commentRepository,
    this.directReplies = const [],
    this.repliesByParent = const {},
    this.onCollapseOthers,
  });

  final CommentModel parent;
  final CommentRepository commentRepository;
  final List<CommentModel> directReplies;
  final Map<String, List<CommentModel>> repliesByParent;
  final VoidCallback? onCollapseOthers;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  static const double _treeGutter = AppSpacing.lg + 14;
  static const double _topContentIndent = 46; // avatar 34 + gap 12
  static const double _replyContentIndent = 40; // avatar 28 + gap 12

  final GlobalKey _repliesKey = GlobalKey();
  bool _expanded = false;
  bool _isSubmittingReply = false;
  CommentModel? _replyTarget;

  CommentRepository get _repo => widget.commentRepository;
  CommentModel get _parent => widget.parent;
  List<CommentModel> get _directReplies => widget.directReplies;

  void _toggleExpanded() {
    if (_expanded) {
      setState(() {
        _expanded = false;
        _replyTarget = null;
        _isSubmittingReply = false;
      });
    } else {
      widget.onCollapseOthers?.call();
      setState(() => _expanded = true);
    }
  }

  void _openReplyComposer(CommentModel target) {
    if (_isSubmittingReply) return;
    widget.onCollapseOthers?.call();
    setState(() {
      _replyTarget = target;
      _expanded = true;
    });
  }

  void _closeReplyComposer() {
    if (_isSubmittingReply) return;
    setState(() => _replyTarget = null);
  }

  void _scrollRepliesIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _repliesKey.currentContext;
      if (ctx == null || Scrollable.maybeOf(ctx) == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    });
  }

  Future<void> _submitReply(String text) async {
    if (_isSubmittingReply) return;
    final user = FirebaseAuth.instance.currentUser;
    final target = _replyTarget;
    if (user == null || target == null) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    setState(() => _isSubmittingReply = true);
    try {
      await _repo.addReply(
        recipeId: _parent.recipeId,
        parentCommentId: target.id,
        userId: user.uid,
        userName: (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'Home Cook'),
        userPhotoUrl: user.photoURL,
        text: cleanText,
        parentCommentAuthorId: target.userId,
      );
      if (mounted) {
        setState(() {
          _replyTarget = null;
          _expanded = true;
          _isSubmittingReply = false;
        });
        _scrollRepliesIntoView();
        AppSnackbar.show(context, message: 'Reply sent!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingReply = false);
        AppSnackbar.show(
          context,
          message: 'Failed to post reply: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    final replyCount = _directReplies.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top-level comment + inline composer if replying to it ──
        // Children are NOT rendered here — the expanded block below owns them
        // so each reply appears exactly once.
        _buildNode(
          comment: _parent,
          depth: 0,
          parent: null,
          user: user,
          includeChildren: false,
        ),

        // ── View replies toggle ──
        if (replyCount > 0 || _expanded)
          Padding(
            padding: const EdgeInsets.only(left: _treeGutter),
            child: ViewRepliesToggle(
              replyCount: replyCount,
              isExpanded: _expanded,
              onToggle: _toggleExpanded,
            ),
          ),

        // ── Nested reply tree (single render, animated open/close) ──
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  key: _repliesKey,
                  padding: const EdgeInsets.only(left: _treeGutter),
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      top: AppSpacing.xs,
                    ),
                    child: _directReplies.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'No replies yet',
                              style: AppTypography.caption(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final reply in _directReplies)
                                _buildNode(
                                  comment: reply,
                                  depth: 1,
                                  parent: _parent,
                                  user: user,
                                  includeChildren: true,
                                ),
                            ],
                          ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Builds a comment node and, optionally, its descendants (recursive).
  ///
  /// [includeChildren] is false only for the top-level node when collapsed —
  /// the expanded block renders direct replies itself to keep the border
  /// chrome and avoid drawing them twice.
  Widget _buildNode({
    required CommentModel comment,
    required int depth,
    required CommentModel? parent,
    required User? user,
    bool includeChildren = true,
  }) {
    final children = widget.repliesByParent[comment.id] ?? const [];
    final isTarget = _replyTarget?.id == comment.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: CommentTile(
            comment: comment,
            currentUserUid: user?.uid,
            isTopLevel: depth == 0,
            // Depth ≥ 2: show who this reply is nested under
            replyingToName: depth >= 2 ? parent?.userName : null,
            onToggleLike: () => _handleToggleLike(comment),
            onReply: user != null ? () => _openReplyComposer(comment) : null,
            onDelete: () => _handleDelete(comment: comment),
          ),
        ),

        // Inline composer sits under the target's bubble (not the avatar)
        if (isTarget && user != null)
          Padding(
            padding: EdgeInsets.only(
              left: depth == 0 ? _topContentIndent : _replyContentIndent,
              right: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: CommentInput(
              variant: CommentInputVariant.inlineReply,
              currentUser: user,
              replyingToName: comment.userName,
              isSubmitting: _isSubmittingReply,
              onSubmit: _submitReply,
              onCancel: _closeReplyComposer,
            ),
          ),

        // Descendants (nested replies always; top-level only when asked)
        if (includeChildren && children.isNotEmpty)
          ...children.map(
            (child) => _buildNode(
              comment: child,
              depth: depth + 1,
              parent: comment,
              user: user,
            ),
          ),
      ],
    );
  }

  Future<void> _handleDelete({required CommentModel comment}) async {
    final isTopLevel = comment.isTopLevel;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(isTopLevel ? 'Delete comment?' : 'Delete reply?'),
        content: Text(
          isTopLevel && _directReplies.isNotEmpty
              ? 'Delete this comment and ${_directReplies.length} ${_directReplies.length == 1 ? "reply" : "replies"}? This cannot be undone.'
              : 'Are you sure you want to remove this? This cannot be undone.',
        ),
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
        await _repo.deleteComment(
          recipeId: comment.recipeId,
          commentId: comment.id,
          isTopLevel: isTopLevel,
        );
        if (mounted) {
          AppSnackbar.show(
            context,
            message: isTopLevel ? 'Comment deleted' : 'Reply deleted',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Failed to delete: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _handleToggleLike(CommentModel comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _repo.toggleCommentLike(
      recipeId: comment.recipeId,
      commentId: comment.id,
      userId: user.uid,
    );
  }
}
