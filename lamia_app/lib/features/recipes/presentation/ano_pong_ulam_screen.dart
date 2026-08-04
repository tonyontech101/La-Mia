import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_states.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import 'recipe_detail_screen.dart';

/// Data class representing a suggested recipe item with match score & missing items.
class SuggestedRecipeItem {
  const SuggestedRecipeItem({
    required this.recipe,
    required this.matchPercentage,
    this.missingIngredients = const [],
  });

  final RecipeModel recipe;
  final int matchPercentage;
  final List<String> missingIngredients;
}

/// "Ano Pong Ulam?" daily meal suggestion screen designed strictly according to
/// the wireframe and La Mia visual design system.
class AnoPongUlamScreen extends StatefulWidget {
  const AnoPongUlamScreen({
    super.key,
    this.onNavigateHome,
  });

  final VoidCallback? onNavigateHome;

  @override
  State<AnoPongUlamScreen> createState() => _AnoPongUlamScreenState();
}

class _AnoPongUlamScreenState extends State<AnoPongUlamScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  late Future<List<RecipeModel>> _recipesFuture;

  // Full recipe list cached after the initial load; filtering happens in memory.
  List<RecipeModel> _allRecipes = const [];

  // Committed filter states (applied to the suggestion list).
  String _selectedMealType = 'Lunch';
  String _selectedBudget = 'Budget friendly';
  double _cookingTimeMinutes = 30.0;
  bool _isCustomTime = false;
  String _selectedDifficulty = 'Easy';
  int _selectedServings = 12;

  // Pending filter states (edited inside the sheet until Apply commits them).
  String _pendingMealType = 'Lunch';
  String _pendingBudget = 'Budget friendly';
  double _pendingCookingTimeMinutes = 30.0;
  bool _pendingIsCustomTime = false;
  String _pendingDifficulty = 'Easy';
  int _pendingServings = 12;

  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
  final List<String> _budgetOptions = [
    'Budget friendly',
    'Affordable',
    'Special',
    'Quite Expensive',
  ];

  static const String _defaultMealType = 'Lunch';
  static const String _defaultBudget = 'Budget friendly';
  static const double _defaultCookingTime = 30.0;
  static const String _defaultDifficulty = 'Easy';
  static const int _defaultServings = 12;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
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

  /// Number of pending filters that differ from their default values.
  int get _pendingCount {
    var count = 0;
    if (_pendingMealType != _defaultMealType) count++;
    if (_pendingBudget != _defaultBudget) count++;
    if (_pendingCookingTimeMinutes.round() != _defaultCookingTime) count++;
    if (_pendingDifficulty != _defaultDifficulty) count++;
    if (_pendingServings != _defaultServings) count++;
    return count;
  }

  /// Number of committed filters that differ from their default values.
  int get _committedFilterCount {
    var count = 0;
    if (_selectedMealType != _defaultMealType) count++;
    if (_selectedBudget != _defaultBudget) count++;
    if (_cookingTimeMinutes.round() != _defaultCookingTime) count++;
    if (_selectedDifficulty != _defaultDifficulty) count++;
    if (_selectedServings != _defaultServings) count++;
    return count;
  }

  /// Summary text shown on the main-screen filters bar.
  String get _filtersSummary {
    if (_committedFilterCount == 0) return 'All dishes';
    return '$_selectedMealType · $_selectedBudget · '
        '${_cookingTimeMinutes.round()}m · $_selectedDifficulty · $_selectedServings';
  }

  bool _passesMealType(RecipeModel recipe) {
    // Defaults mean "Any/All": the default meal type never excludes.
    if (_selectedMealType == _defaultMealType) return true;

    final cat = recipe.category.toLowerCase();
    final selected = _selectedMealType.toLowerCase();

    switch (selected) {
      case 'breakfast':
        return cat.contains('almusal') ||
            cat.contains('breakfast') ||
            cat.contains('tapsilog');
      case 'lunch':
      case 'dinner':
        return cat.contains('ulam');
      case 'snacks':
        return cat.contains('merienda') ||
            cat.contains('panghimagas') ||
            cat.contains('snack');
      default:
        // Unknown selection: never wipe the whole list on a miss.
        return true;
    }
  }

  /// Calculates suggestion match score based on filters and recipe characteristics.
  List<SuggestedRecipeItem> _computeSuggestions(List<RecipeModel> recipes) {
    if (recipes.isEmpty) return [];

    final suggestions = <SuggestedRecipeItem>[];

    for (final recipe in recipes) {
      final parsedCookTime =
          int.tryParse(recipe.cookTime.replaceAll(RegExp(r'[^0-9]'), '')) ?? 25;

      // True-exclusion gates: drop recipes that fail any *active* filter.
      // Defaults mean "Any/All" — a gate only fires when the committed filter
      // was explicitly changed from its default value.
      if (_selectedMealType != _defaultMealType && !_passesMealType(recipe)) {
        continue;
      }
      if (_selectedDifficulty != _defaultDifficulty &&
          recipe.difficulty.toLowerCase() != _selectedDifficulty.toLowerCase()) {
        continue;
      }
      if (_cookingTimeMinutes.round() != _defaultCookingTime &&
          parsedCookTime > _cookingTimeMinutes) {
        continue;
      }
      if (_selectedServings != _defaultServings && recipe.servings > _selectedServings) {
        continue;
      }

      // Suitability score for the surviving recipes (100 = perfect fit).
      var match = 100;
      final missing = <String>[];

      // Budget placeholder proxy (kept from previous behavior): ingredient
      // count standing in for cost. Graded, not a hard gate.
      if (_selectedBudget == 'Budget friendly' && recipe.ingredients.length > 8) {
        match -= 15;
        missing.add('Special Spices');
      } else if (_selectedBudget == 'Special' && recipe.ingredients.length <= 5) {
        match -= 10;
      }

      // Recipes that barely fit the time budget score slightly lower.
      if (parsedCookTime > _cookingTimeMinutes * 0.8) {
        match -= 5;
      }

      suggestions.add(
        SuggestedRecipeItem(
          recipe: recipe,
          matchPercentage: match,
          missingIngredients: missing,
        ),
      );
    }

    // Sort by highest match percentage
    suggestions.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return suggestions;
  }

  void _showRecipeDetailsDialog(RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(recipe: recipe),
      ),
    );
  }

  void _openFilterSheet() {
    _pendingMealType = _selectedMealType;
    _pendingBudget = _selectedBudget;
    _pendingCookingTimeMinutes = _cookingTimeMinutes;
    _pendingIsCustomTime = _isCustomTime;
    _pendingDifficulty = _selectedDifficulty;
    _pendingServings = _selectedServings;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                        child: Row(
                          children: [
                            Text(
                              'Filters',
                              style: AppTypography.title(
                                color: AppColors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (_pendingCount > 0)
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
                                  '$_pendingCount pending',
                                  style: AppTypography.caption(
                                    color: AppColors.primary,
                                  ).copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.surfaceAlt,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.textPrimary,
                                  size: 18,
                                ),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1, color: AppColors.border),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenH,
                            vertical: AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Filter 1: Meal Type
                              _buildFilterBlock(
                                title: 'Meal Type',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _mealTypes
                                      .map((type) => _FilterChip(
                                            label: type,
                                            isSelected: _pendingMealType == type,
                                            onTap: () {
                                              setSheetState(() {
                                                _pendingMealType = type;
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Filter 2: Budget
                              _buildFilterBlock(
                                title: 'Budget',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _budgetOptions
                                      .map((budget) => _FilterChip(
                                            label: budget,
                                            isSelected: _pendingBudget == budget,
                                            onTap: () {
                                              setSheetState(() {
                                                _pendingBudget = budget;
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Filter 3: Cooking Time
                              _buildFilterBlock(
                                title: 'Cooking Time',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Slider Row with 4m & 45m labels as shown in wireframe
                                    Row(
                                      children: [
                                        Text(
                                          '4m',
                                          style: AppTypography.caption(
                                            color: AppColors.textSecondary,
                                          ).copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: AppColors.primary,
                                              inactiveTrackColor: AppColors.border,
                                              thumbColor: AppColors.surface,
                                              overlayColor: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 10,
                                                elevation: 3,
                                              ),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: _pendingCookingTimeMinutes
                                                  .clamp(4.0, 45.0),
                                              min: 4.0,
                                              max: 45.0,
                                              onChanged: (val) {
                                                setSheetState(() {
                                                  _pendingCookingTimeMinutes = val;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${_pendingCookingTimeMinutes.round()}m',
                                          style: AppTypography.caption(
                                            color: AppColors.primary,
                                          ).copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Custom Time & +/- Step Controls Row matching wireframe
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setSheetState(() {
                                              _pendingIsCustomTime =
                                                  !_pendingIsCustomTime;
                                            });
                                          },
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.pill),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _pendingIsCustomTime
                                                  ? AppColors.primary
                                                  : AppColors.surface,
                                              borderRadius: BorderRadius.circular(
                                                AppRadii.pill,
                                              ),
                                              border: Border.all(
                                                color: _pendingIsCustomTime
                                                    ? AppColors.primary
                                                    : AppColors.border,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: AppColors.cardShadow,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              _pendingIsCustomTime
                                                  ? 'Custom: ${_pendingCookingTimeMinutes.round()}m'
                                                  : 'Custom Time',
                                              style: AppTypography.caption(
                                                color: _pendingIsCustomTime
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                              ).copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        _StepIconButton(
                                          icon: Icons.add,
                                          onTap: () {
                                            setSheetState(() {
                                              if (_pendingCookingTimeMinutes < 120) {
                                                _pendingCookingTimeMinutes =
                                                    (_pendingCookingTimeMinutes + 5)
                                                        .clamp(4.0, 120.0);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _StepIconButton(
                                          icon: Icons.remove,
                                          onTap: () {
                                            setSheetState(() {
                                              if (_pendingCookingTimeMinutes > 4) {
                                                _pendingCookingTimeMinutes =
                                                    (_pendingCookingTimeMinutes - 5)
                                                        .clamp(4.0, 120.0);
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Filter 4: Difficulty
                              _buildFilterBlock(
                                title: 'Difficulty',
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: const ['Easy', 'Medium', 'Hard']
                                      .map((level) => _FilterChip(
                                            label: level,
                                            isSelected: _pendingDifficulty == level,
                                            onTap: () {
                                              setSheetState(() {
                                                _pendingDifficulty = level;
                                              });
                                            },
                                          ))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Filter 5: Servings
                              _buildFilterBlock(
                                title: 'Servings',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '1',
                                          style: AppTypography.caption(
                                            color: AppColors.textSecondary,
                                          ).copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: AppColors.primary,
                                              inactiveTrackColor: AppColors.border,
                                              thumbColor: AppColors.surface,
                                              overlayColor: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 10,
                                                elevation: 3,
                                              ),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: _pendingServings.toDouble(),
                                              min: 1,
                                              max: 12,
                                              divisions: 11,
                                              onChanged: (val) {
                                                setSheetState(() {
                                                  _pendingServings = val.round();
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '12',
                                          style: AppTypography.caption(
                                            color: AppColors.textSecondary,
                                          ).copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Max $_pendingServings servings',
                                          style: AppTypography.caption(
                                            color: AppColors.primary,
                                          ).copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        _StepIconButton(
                                          icon: Icons.add,
                                          onTap: () {
                                            setSheetState(() {
                                              if (_pendingServings < 12) {
                                                _pendingServings += 1;
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _StepIconButton(
                                          icon: Icons.remove,
                                          onTap: () {
                                            setSheetState(() {
                                              if (_pendingServings > 1) {
                                                _pendingServings -= 1;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sticky Apply zone (outside the Expanded, pinned to the bottom).
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border, width: 1),
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          AppSpacing.md,
                          AppSpacing.screenH,
                          AppSpacing.md + MediaQuery.of(context).padding.bottom,
                        ),
                        child: PrimaryButton(
                          label: _pendingCount == 0
                              ? 'Apply'
                              : 'Apply $_pendingCount Changes',
                          onPressed: _pendingCount > 0 ? _applyFilters : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _selectedMealType = _pendingMealType;
      _selectedBudget = _pendingBudget;
      _cookingTimeMinutes = _pendingCookingTimeMinutes;
      _isCustomTime = _pendingIsCustomTime;
      _selectedDifficulty = _pendingDifficulty;
      _selectedServings = _pendingServings;
    });
    Navigator.of(context).pop();
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
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : widget.onNavigateHome != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: widget.onNavigateHome,
                  )
                : null,
        title: Text(
          'Ano Pong Ulam?',
          style: AppTypography.title(color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Title & Subtitle Section
                  _buildHeaderSection(),

                  const SizedBox(height: 20),

                  // 2. Filters Summary Bar (opens the filter bottom sheet)
                  _buildFilterSummaryBar(),

                  const SizedBox(height: 28),

                  // 3. Suggested Recipes Section Title
                  Text(
                    'Suggested Recipes',
                    style: AppTypography.headline(color: AppColors.textPrimary).copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Recipes List
                  FutureBuilder<List<RecipeModel>>(
                    future: _recipesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SectionLoadingSkeleton(height: 300, isHorizontal: false);
                      }
                      if (snapshot.hasError) {
                        return SectionErrorState(
                          message: 'Unable to load recipes. Please check connection.',
                          onRetry: _retry,
                        );
                      }

                      final recipes = _allRecipes;
                      final suggestions = _computeSuggestions(recipes);

                      if (suggestions.isEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SectionEmptyState(
                              message: 'No recipes matched your criteria',
                              subtitle: 'Try adjusting your meal type or cooking time filters.',
                            ),
                            TextButton(
                              onPressed: _openFilterSheet,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: AppColors.secondary,
                              ),
                              child: Text(
                                'Edit filters',
                                style: AppTypography.bodyStrong(color: AppColors.secondary),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: suggestions
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: _SuggestedRecipeCard(
                                    item: item,
                                    onTap: () => _showRecipeDetailsDialog(item.recipe),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Title and Tita Guide tagline section
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Ano Pong Ulam?',
              style: AppTypography.headline(color: AppColors.textPrimary).copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Tita Approved',
                    style: AppTypography.caption(color: AppColors.primary).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "The Helpful Tita's guide to your daily Filipino cravings.",
          style: AppTypography.body(color: AppColors.textSecondary).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Compact tappable bar summarizing the committed filters. Tapping opens the
  /// filter bottom sheet.
  Widget _buildFilterSummaryBar() {
    return Semantics(
      button: true,
      label: 'Open recipe filters',
      child: InkWell(
        onTap: _openFilterSheet,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  if (_committedFilterCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          '$_committedFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _filtersSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBlock({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card - 4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Custom Filter Chip button designed for Meal Type & Budget selections
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              else
                const BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
            ],
          ),
          child: Text(
            label,
            style: AppTypography.caption(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round +/- step button for Cooking Time
class _StepIconButton extends StatelessWidget {
  const _StepIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Suggested Recipe Card matching the wireframe card component.
class _SuggestedRecipeCard extends StatelessWidget {
  const _SuggestedRecipeCard({
    required this.item,
    required this.onTap,
  });

  final SuggestedRecipeItem item;
  final VoidCallback onTap;

  Color _getMatchColor(int percentage) {
    if (percentage >= 90) return AppColors.success;
    if (percentage >= 70) return AppColors.primary;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = item.recipe;
    final matchColor = _getMatchColor(item.matchPercentage);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.border, width: 1),
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
            // 1. Dish Image & Match Badge Container
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
                            'Dish Image',
                            style: AppTypography.headline(color: AppColors.textSecondary).copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Match Percentage Badge (Top-left as in wireframe)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.cardShadow,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${item.matchPercentage}% match',
                      style: AppTypography.caption(color: matchColor).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 2. Dish Name & Details Container (Bottom Half)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dish Name
                  Text(
                    recipe.name,
                    style: AppTypography.headline(color: AppColors.textPrimary).copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Text(
                    'Classic ${recipe.region} ${recipe.category.toLowerCase()} dish with ${recipe.ingredients.take(3).join(", ")}.',
                    style: AppTypography.body(color: AppColors.textSecondary).copyWith(
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Missing Ingredient Note (if applicable)
                  if (item.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Missing Ingredient: ${item.missingIngredients.join(", ")}',
                            style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
