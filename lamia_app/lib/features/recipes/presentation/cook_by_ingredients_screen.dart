import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_states.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import '../domain/ingredient_matched_recipe.dart';
import '../domain/ingredient_matcher.dart';
import 'recipe_detail_screen.dart';

/// "Cook by Ingredients" screen allowing users to input/select available pantry ingredients as tags,
/// view quick suggestion tags, find matching recipes, and see match scores with missing ingredients.
class CookByIngredientsScreen extends StatefulWidget {
  const CookByIngredientsScreen({super.key, this.onNavigateHome});

  final VoidCallback? onNavigateHome;

  @override
  State<CookByIngredientsScreen> createState() =>
      _CookByIngredientsScreenState();
}

class _CookByIngredientsScreenState extends State<CookByIngredientsScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  final TextEditingController _ingredientController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultsKey = GlobalKey();

  late Future<List<RecipeModel>> _recipesFuture;
  List<RecipeModel> _allRecipes = const [];

  // Active user-selected ingredient tags
  final List<String> _selectedIngredients = ['Eggs', 'Garlic', 'Rice'];

  // Quick suggestion tags
  final List<String> _popularSuggestions = [
    'Rice',
    'Garlic',
    'Eggs',
    'Pork',
    'Chicken',
    'Onion',
    'Tomato',
    'Soy Sauce',
    'Vinegar',
    'Cooking Oil',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadRecipes() {
    _recipesFuture = _recipeRepository.allRecipes().then((recipes) {
      _allRecipes = recipes;
      return recipes;
    });
  }

  void _retry() {
    setState(() {
      _loadRecipes();
    });
  }

  void _addIngredientTag(String rawInput) {
    final text = rawInput.trim();
    if (text.isEmpty) return;

    // Handle comma-separated input
    final items = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    setState(() {
      for (final item in items) {
        final capitalized =
            item[0].toUpperCase() + item.substring(1).toLowerCase();
        if (!_selectedIngredients.any(
          (e) => e.toLowerCase() == capitalized.toLowerCase(),
        )) {
          _selectedIngredients.add(capitalized);
        }
      }
      _ingredientController.clear();
    });
  }

  void _removeIngredientTag(String tag) {
    setState(() {
      _selectedIngredients.removeWhere(
        (e) => e.toLowerCase() == tag.toLowerCase(),
      );
    });
  }

  void _clearAllTags() {
    setState(() {
      _selectedIngredients.clear();
    });
  }

  void _onFindRecipesPressed() {
    setState(() {});

    // Scroll smoothly down to the results section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _navigateToDetail(RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: canPop
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : widget.onNavigateHome != null
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: widget.onNavigateHome,
              )
            : null,
        title: Text(
          'Cook by Ingredients',
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title & Tagline
                  _buildHeaderSection(),

                  const SizedBox(height: 20),

                  // "Add Ingredients" Card (Matching wireframe design)
                  _buildAddIngredientsCard(),

                  const SizedBox(height: 28),

                  // Recipe Results Section Title & List
                  Container(key: _resultsKey),
                  _buildResultsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Title & Subtitle Header
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Cook by Ingredients',
              style: AppTypography.headline(color: AppColors.textPrimary)
                  .copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.kitchen_outlined,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pantry Solver',
                    style: AppTypography.caption(
                      color: AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add what you have in your fridge or kitchen, and discover dishes you can cook right now!',
          style: AppTypography.body(
            color: AppColors.textSecondary,
          ).copyWith(fontSize: 13),
        ),
      ],
    );
  }

  /// Main "Add Ingredients" Card styled matching the provided wireframe screenshot
  Widget _buildAddIngredientsCard() {
    final availableSuggestions = _popularSuggestions
        .where(
          (s) => !_selectedIngredients.any(
            (tag) => tag.toLowerCase() == s.toLowerCase(),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Ingredients',
                style: AppTypography.title(
                  color: AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              if (_selectedIngredients.isNotEmpty)
                GestureDetector(
                  onTap: _clearAllTags,
                  child: Text(
                    'Clear all',
                    style: AppTypography.caption(color: AppColors.primary)
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Inner Container: Tags display area + Text Input Field
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.field),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render selected ingredient tag chips (e.g. Eggs x, Garlic x, Rice x)
                if (_selectedIngredients.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedIngredients.map((tag) {
                      return Container(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 6,
                          top: 6,
                          bottom: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tag,
                              style: AppTypography.bodyStrong(
                                color: AppColors.textPrimary,
                              ).copyWith(fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _removeIngredientTag(tag),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Input field for ingredients
                TextField(
                  controller: _ingredientController,
                  onSubmitted: _addIngredientTag,
                  style: AppTypography.body(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _selectedIngredients.isEmpty
                        ? 'Input your ingredients here (e.g., Eggs, Garlic, Rice)...'
                        : 'Add more ingredients...',
                    hintStyle: AppTypography.body(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    suffixIcon: _ingredientController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                _addIngredientTag(_ingredientController.text),
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {}); // refresh suffix icon state
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick Suggestion Chips (e.g., + Rice, + Garlic, + Pork)
          if (availableSuggestions.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableSuggestions.take(6).map((suggestion) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      elevation: 0,
                      pressElevation: 1,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            suggestion,
                            style: AppTypography.bodyStrong(
                              color: AppColors.textPrimary,
                            ).copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      onPressed: () => _addIngredientTag(suggestion),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main Action Button: "Find Recipes"
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Find Recipes',
              onPressed: _selectedIngredients.isEmpty
                  ? null
                  : _onFindRecipesPressed,
            ),
          ),
        ],
      ),
    );
  }

  /// Results Section: Header count and list of matched recipes
  Widget _buildResultsSection() {
    return FutureBuilder<List<RecipeModel>>(
      future: _recipesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SectionLoadingSkeleton(height: 280, isHorizontal: false);
        }
        if (snapshot.hasError) {
          return SectionErrorState(
            message:
                'Unable to load recipes. Please check your internet connection.',
            onRetry: _retry,
          );
        }

        final matches = computeIngredientMatches(
          _allRecipes,
          _selectedIngredients,
        );

        if (_selectedIngredients.isEmpty) {
          return const SectionEmptyState(
            message: 'What ingredients do you have today?',
            subtitle:
                'Add ingredients in the card above or tap quick suggestions to see recipes you can make.',
          );
        }

        if (matches.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matched Recipes',
                style: AppTypography.headline(
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const SectionEmptyState(
                message: 'No matching recipes found',
                subtitle:
                    'Try adding more common ingredients like Garlic, Onion, Pork, or Rice.',
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Matching Recipes',
                  style: AppTypography.headline(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '${matches.length} found',
                    style: AppTypography.caption(
                      color: AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: matches.map((match) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _CookMatchedRecipeCard(
                    matchItem: match,
                    onTap: () => _navigateToDetail(match.recipe),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// Card component to display a matched recipe with match badge, missing items, and details.
class _CookMatchedRecipeCard extends StatelessWidget {
  const _CookMatchedRecipeCard({required this.matchItem, required this.onTap});

  final IngredientMatchedRecipe matchItem;
  final VoidCallback onTap;

  Color _getMatchBadgeColor(int pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 50) return AppColors.primary;
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = matchItem.recipe;
    final badgeColor = _getMatchBadgeColor(matchItem.matchPercentage);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Cover Photo + Match Percentage Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.card),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: recipe.coverPhotoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: AppColors.surfaceAlt,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: AppColors.surfaceAlt,
                        child: Center(
                          child: Text(
                            recipe.name,
                            style: AppTypography.headline(
                              color: AppColors.textSecondary,
                            ).copyWith(fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Match Percentage Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          matchItem.matchPercentage >= 80
                              ? Icons.check_circle_rounded
                              : Icons.local_fire_department_rounded,
                          size: 14,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${matchItem.matchPercentage}% Match',
                          style: AppTypography.caption(
                            color: badgeColor,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Card Body Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: AppTypography.headline(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${recipe.prepTime} prep • ${recipe.cookTime} cook',
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.restaurant_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.difficulty,
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (matchItem.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadii.field),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_basket_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Missing: ${matchItem.missingIngredients.take(3).join(", ")}${matchItem.missingIngredients.length > 3 ? "..." : ""}',
                              style: AppTypography.caption(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
