import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../data/comment_model.dart';
import '../../data/comment_repository.dart';
import 'comment_input.dart';
import 'comment_tile.dart';
import 'view_replies_toggle.dart';

/// Renders one top-level comment + its (lazy, collapsible) replies.
///
/// Replies are fetched via a per-parent [StreamSubscription] that is only
/// active when the thread is expanded. Collapsed state shows a
/// "View N replies" toggle with a one-shot count.
///
/// The single-expanded policy is enforced by [CommentSection] via the
/// [onCollapseOthers] callback — when this thread expands, it tells the
/// parent to collapse all other threads.
class CommentThread extends StatefulWidget {
  const CommentThread({
    super.key,
    required this.parent,
    required this.commentRepository,
    this.onCollapseOthers,
  });

  final CommentModel parent;
  final CommentRepository commentRepository;
  final VoidCallback? onCollapseOthers;

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  bool _expanded = false;
  bool _replyingHere = false;
  List<CommentModel> _replies = [];
  StreamSubscription<List<CommentModel>>? _repliesSubscription;
  int _cachedReplyCount = 0;

  CommentRepository get _repo => widget.commentRepository;
  CommentModel get _parent => widget.parent;

  @override
  void initState() {
    super.initState();
    _cachedReplyCount = _parent.replyCount;
    if (_parent.replyCount > 0) {
      _loadReplyCount();
    }
  }

  @override
  void dispose() {
    _repliesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadReplyCount() async {
    final count = await _repo.getReplyCount(
      recipeId: _parent.recipeId,
      parentCommentId: _parent.id,
    );
    if (mounted) {
      setState(() {
        _cachedReplyCount = count;
      });
    }
  }

  void _toggleExpanded() {
    if (_expanded) {
      // Collapse
      _repliesSubscription?.cancel();
      _repliesSubscription = null;
      setState(() {
        _expanded = false;
        _replies = [];
      });
    } else {
      // Expand — collapse others first (single-expanded policy)
      widget.onCollapseOthers?.call();
      _subscribeToReplies();
      setState(() => _expanded = true);
    }
  }

  void _subscribeToReplies() {
    _repliesSubscription?.cancel();
    _repliesSubscription = _repo
        .getRepliesStream(
          recipeId: _parent.recipeId,
          parentCommentId: _parent.id,
        )
        .listen((replies) {
      if (mounted) {
        setState(() {
          _replies = replies;
          _cachedReplyCount = replies.length;
        });
      }
    });
  }

  void _openReplyComposer() {
    widget.onCollapseOthers?.call();
    setState(() => _replyingHere = true);
  }

  void _closeReplyComposer() {
    setState(() => _replyingHere = false);
  }

  Future<void> _submitReply(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    try {
      await _repo.addReply(
        recipeId: _parent.recipeId,
        parentCommentId: _parent.id,
        userId: user.uid,
        userName: (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'Home Cook'),
        userPhotoUrl: user.photoURL,
        text: cleanText,
        parentCommentAuthorId: _parent.userId,
      );
      if (mounted) {
        setState(() => _replyingHere = false);
        // Auto-expand to show the new reply
        if (!_expanded) {
          _subscribeToReplies();
          setState(() => _expanded = true);
        }
      }
    } catch (_) {
      // Errors handled by parent via AppSnackbar if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top-level comment tile ──
        CommentTile(
          comment: _parent,
          currentUserUid: user?.uid,
          isTopLevel: true,
          onReply: user != null ? _openReplyComposer : null,
          onDelete: () => _handleDelete(isTopLevel: true),
        ),

        // ── Inline reply composer ──
        if (_replyingHere && user != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg + 14, // align with bubble content
              right: AppSpacing.md,
            ),
            child: CommentInput(
              variant: CommentInputVariant.inlineReply,
              currentUser: user,
              replyingToName: _parent.userName,
              onSubmit: _submitReply,
              onCancel: _closeReplyComposer,
            ),
          ),

        // ── View replies toggle ──
        if (_cachedReplyCount > 0 || _expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg + 14,
            ),
            child: ViewRepliesToggle(
              replyCount: _cachedReplyCount,
              isExpanded: _expanded,
              onToggle: _toggleExpanded,
            ),
          ),

        // ── Replies block ──
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg + 14,
            ),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.border,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        'Loading replies...',
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...List.generate(_replies.length, (index) {
                      final reply = _replies[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.sm,
                        ),
                        child: CommentTile(
                          comment: reply,
                          currentUserUid: user?.uid,
                          isTopLevel: false,
                          onToggleLike: () => _handleToggleLike(reply),
                          onDelete: () => _handleDelete(
                            isTopLevel: false,
                            commentId: reply.id,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleDelete({
    required bool isTopLevel,
    String? commentId,
  }) async {
    final recipeId = _parent.recipeId;

    final targetId = isTopLevel ? _parent.id : commentId;
    if (targetId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(isTopLevel ? 'Delete comment?' : 'Delete reply?'),
        content: Text(
          isTopLevel && _cachedReplyCount > 0
              ? 'Delete this comment and $_cachedReplyCount ${_cachedReplyCount == 1 ? "reply" : "replies"}? This cannot be undone.'
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
          recipeId: recipeId,
          commentId: targetId,
          isTopLevel: isTopLevel,
        );
      } catch (_) {}
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
