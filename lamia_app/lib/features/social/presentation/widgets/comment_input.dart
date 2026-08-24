import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// Variant for the comment input.
enum CommentInputVariant {
  /// Full composer shown to signed-in users (avatar + field + submit).
  composer,

  /// Gate shown to signed-out users (sign-in prompt + button).
  guestGate,

  /// Compact inline reply composer (no avatar, "Replying to @name" + cancel).
  inlineReply,
}

/// The comment composer — three variants via [variant].
///
/// - [composer]: avatar + multiline field + "Post Comment" button.
/// - [guestGate]: lock icon + sign-in prompt.
/// - [inlineReply]: compact single-line field with replying-to hint.
class CommentInput extends StatefulWidget {
  const CommentInput({
    super.key,
    required this.variant,
    this.currentUser,
    this.controller,
    this.replyingToName,
    this.isSubmitting = false,
    this.onSubmit,
    this.onCancel,
    this.onSignIn,
  });

  final CommentInputVariant variant;
  final User? currentUser;
  final TextEditingController? controller;
  final String? replyingToName;
  final bool isSubmitting;
  final ValueChanged<String>? onSubmit;
  final VoidCallback? onCancel;
  final VoidCallback? onSignIn;

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  late final TextEditingController _internalController;
  late final FocusNode _focusNode;
  bool _focused = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == CommentInputVariant.guestGate) {
      return _buildGuestGate();
    }
    if (widget.variant == CommentInputVariant.inlineReply) {
      return _buildInlineReply();
    }
    return _buildComposer();
  }

  // ── Guest gate ─────────────────────────────────────────────────────────

  Widget _buildGuestGate() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sign in to join the conversation and share tips!',
              style: AppTypography.caption(color: AppColors.textSecondary)
                  .copyWith(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: widget.onSignIn,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            child: Text(
              'Sign In',
              style: AppTypography.button(color: AppColors.onPrimary)
                  .copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full composer ──────────────────────────────────────────────────────

  Widget _buildComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildComposerAvatar(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTextField()),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed:
                widget.isSubmitting || _effectiveController.text.trim().isEmpty
                    ? null
                    : () => widget.onSubmit?.call(_effectiveController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primaryDisabled,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            icon: widget.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(
              widget.isSubmitting ? 'Posting...' : 'Post Comment',
              style: AppTypography.button(color: AppColors.onPrimary)
                  .copyWith(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ── Inline reply ───────────────────────────────────────────────────────

  Widget _buildInlineReply() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${widget.replyingToName ?? "comment"}',
                    style: AppTypography.caption(color: AppColors.textSecondary),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: Text(
                      'Cancel',
                      style: AppTypography.label(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _effectiveController,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: AppTypography.caption(color: AppColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: widget.isSubmitting ||
                        _effectiveController.text.trim().isEmpty
                    ? null
                    : () => widget.onSubmit?.call(_effectiveController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primaryDisabled,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.reply_rounded, size: 14),
                label: Text(
                  widget.isSubmitting ? 'Replying...' : 'Reply',
                  style: AppTypography.button(color: AppColors.onPrimary)
                      .copyWith(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _buildComposerAvatar() {
    final user = widget.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName;
    final initial =
        displayName?.isNotEmpty == true ? displayName![0].toUpperCase() : 'U';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: photoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    initial,
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
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(
          color: _focused ? AppColors.borderFocus : AppColors.border,
        ),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: _focusNode,
        maxLines: null,
        minLines: 2,
        textInputAction: TextInputAction.newline,
        style: AppTypography.body(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText:
              'Tried this recipe? Share your thoughts, substitutions, or tips...',
          hintStyle: AppTypography.body(color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
