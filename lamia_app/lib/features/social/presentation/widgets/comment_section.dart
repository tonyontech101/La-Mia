import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/login_screen.dart';
import '../../../recipes/data/recipe_model.dart';
import '../../data/comment_model.dart';
import '../../data/comment_repository.dart';
import 'comment_empty_state.dart';
import 'comment_input.dart';
import 'comment_loading_state.dart';
import 'comment_thread.dart';

/// Top-level host for the "Comments & Discussion" section on the recipe
/// detail screen.
///
/// Owns all comment state (controller, submit/delete/like handlers) and
/// renders the composer, stream of comments, and empty/loading states.
/// When this widget is extracted into threading (Phase 3–4), only this
/// file needs to grow — child widgets remain untouched.
class CommentSection extends StatefulWidget {
  CommentSection({
    super.key,
    required this.recipe,
    CommentRepository? commentRepository,
  })  : _commentRepo = commentRepository ?? CommentRepository();

  final RecipeModel recipe;
  final CommentRepository _commentRepo;

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CommentRepository get _commentRepo => widget._commentRepo;
  RecipeModel get _recipe => widget.recipe;

  // ── Handlers (moved from recipe_detail_screen.dart lines 563–663) ─────

  Future<void> _handleSubmitComment([String? text]) async {
    final commentText = (text ?? _commentController.text).trim();
    if (commentText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Please sign in to post a comment');
      }
      return;
    }

    final recipeId = _recipe.id;
    if (recipeId == null) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Unable to comment on this recipe');
      }
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      await _commentRepo.addComment(
        recipeId: recipeId,
        userId: user.uid,
        userName: (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (user.email?.split('@').first ?? 'Home Cook'),
        userPhotoUrl: user.photoURL,
        text: commentText,
        recipeAuthorId: _recipe.authorId,
        recipeTitle: _recipe.name,
      );
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        AppSnackbar.show(context, message: 'Comment shared!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Failed to post comment: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final recipeId = _recipe.id;

    if (recipeId == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Comments & Discussion',
                style: AppTypography.headline(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),

          // ── Composer / Guest gate ──
          if (user == null)
            CommentInput(
              variant: CommentInputVariant.guestGate,
              onSignIn: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          else
            CommentInput(
              variant: CommentInputVariant.composer,
              currentUser: user,
              controller: _commentController,
              isSubmitting: _isSubmittingComment,
              onSubmit: _handleSubmitComment,
            ),

          const SizedBox(height: AppSpacing.xl),

          // ── Comment list ──
          StreamBuilder<List<CommentModel>>(
            stream: _commentRepo.getCommentsStream(recipeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const CommentLoadingState();
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Couldn\'t load comments',
                          style: AppTypography.body(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return const CommentEmptyState();
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.lg),
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return CommentThread(
                    key: ValueKey(comment.id),
                    parent: comment,
                    commentRepository: _commentRepo,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
