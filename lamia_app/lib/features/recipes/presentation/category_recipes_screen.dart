import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/section_states.dart';
import '../../home/presentation/widgets/feed_recipe_card.dart';
import '../data/recipe_category_model.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import 'recipe_detail_screen.dart';

/// A focused, standalone collection for one Filipino recipe category.
class CategoryRecipesScreen extends ConsumerStatefulWidget {
  const CategoryRecipesScreen({super.key, required this.category});

  final RecipeCategoryModel category;

  @override
  ConsumerState<CategoryRecipesScreen> createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends ConsumerState<CategoryRecipesScreen> {
  RecipeRepository get _recipeRepository => ref.read(recipeRepositoryProvider);
  late Future<List<RecipeModel>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _loadRecipes();
  }

  Future<List<RecipeModel>> _loadRecipes() =>
      _recipeRepository.recipesByCategory(widget.category.id, limit: 50);

  Future<void> _refresh() async {
    setState(() => _recipesFuture = _loadRecipes());
    await _recipesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: FutureBuilder<List<RecipeModel>>(
              future: _recipesFuture,
              builder: (context, snapshot) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _CategoryHeader(category: category)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH, 8, AppSpacing.screenH, 28),
                      sliver: SliverToBoxAdapter(child: _buildContent(snapshot)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AsyncSnapshot<List<RecipeModel>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SectionLoadingSkeleton(height: 420, isHorizontal: false);
    }
    if (snapshot.hasError) {
      return SectionErrorState(
        message: 'Could not load ${widget.category.name} recipes. Try again.',
        onRetry: _refresh,
      );
    }
    final recipes = snapshot.data ?? const <RecipeModel>[];
    if (recipes.isEmpty) {
      return SectionEmptyState(
        message: 'No ${widget.category.name} recipes yet',
        subtitle: 'New dishes in this collection will appear here.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < recipes.length; i++)
          FadeInView(
            key: ValueKey('category-${widget.category.id}-${recipes[i].id ?? recipes[i].name}'),
            delay: Duration(milliseconds: (i % 6) * 50),
            duration: const Duration(milliseconds: 400),
            offset: const Offset(0, 16),
            child: FeedRecipeCard(
              recipe: recipes[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: recipes[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final RecipeCategoryModel category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenH - 8, 4, AppSpacing.screenH, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back to Cook',
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Icon(category.icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: AppTypography.title(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(category.tagline, style: AppTypography.caption(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
