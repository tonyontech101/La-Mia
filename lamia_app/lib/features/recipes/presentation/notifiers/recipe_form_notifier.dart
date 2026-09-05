import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../data/recipe_category_model.dart';
import '../../data/recipe_model.dart';

part 'recipe_form_notifier.g.dart';

/// Result returned by [RecipeFormNotifier.submitRecipe] so the widget layer
/// can react (show snackbar, navigate, etc.) without the notifier touching
/// `BuildContext`.
class RecipeSubmitResult {
  const RecipeSubmitResult({
    required this.success,
    this.message,
    this.recipeDocId,
    this.updatedRecipeId,
  });

  final bool success;
  final String? message;
  final String? recipeDocId;
  final String? updatedRecipeId;

  factory RecipeSubmitResult.success({
    String? message,
    String? recipeDocId,
    String? updatedRecipeId,
  }) =>
      RecipeSubmitResult(
        success: true,
        message: message,
        recipeDocId: recipeDocId,
        updatedRecipeId: updatedRecipeId,
      );

  factory RecipeSubmitResult.failure(String message) => RecipeSubmitResult(
        success: false,
        message: message,
      );
}

/// Manages the recipe creation / edit form state.
///
/// Holds every form field value, the selected cover image, and step
/// navigation. Provides validation and submission logic so the widget
/// layer only renders UI and reacts to results.
///
/// The notifier intentionally has **no** `BuildContext` or UI imports.
@riverpod
class RecipeFormNotifier extends _$RecipeFormNotifier {
  @override
  RecipeFormState build() {
    return const RecipeFormState();
  }

  void resetForm() => state = const RecipeFormState();

  // ── Simple field updates ─────────────────────────────────────────────────

  void updateName(String value) => state = state.copyWith(name: value);
  void updateDescription(String value) =>
      state = state.copyWith(description: value);
  void updateCategoryId(String? value) =>
      state = state.copyWith(selectedCategoryId: value);
  void updateRegion(String value) => state = state.copyWith(region: value);
  void updateDifficulty(String value) =>
      state = state.copyWith(difficulty: value);
  void updateBudget(String value) => state = state.copyWith(budget: value);
  void updateTags(String value) => state = state.copyWith(tags: value);

  void updateServings(int value) => state = state.copyWith(servings: value);
  void incrementServings() => state = state.copyWith(servings: state.servings + 1);
  void decrementServings() {
    if (state.servings > 1) {
      state = state.copyWith(servings: state.servings - 1);
    }
  }

  void updatePrepTime(int value) => state = state.copyWith(prepTimeMin: value);
  void incrementPrepTime() =>
      state = state.copyWith(prepTimeMin: state.prepTimeMin + 5);
  void decrementPrepTime() {
    if (state.prepTimeMin >= 5) {
      state = state.copyWith(prepTimeMin: state.prepTimeMin - 5);
    } else if (state.prepTimeMin > 0) {
      state = state.copyWith(prepTimeMin: 0);
    }
  }

  void updateCookTime(int value) => state = state.copyWith(cookTimeMin: value);
  void incrementCookTime() =>
      state = state.copyWith(cookTimeMin: state.cookTimeMin + 5);
  void decrementCookTime() {
    if (state.cookTimeMin >= 5) {
      state = state.copyWith(cookTimeMin: state.cookTimeMin - 5);
    } else if (state.cookTimeMin > 0) {
      state = state.copyWith(cookTimeMin: 0);
    }
  }

  // ── Photo ────────────────────────────────────────────────────────────────

  void setSelectedImageFile(File? file) {
    if (file == null) {
      state = state.copyWith(clearSelectedImageFile: true);
    } else {
      state = state.copyWith(
        selectedImageFile: file,
        clearCoverPhotoUrl: true,
      );
    }
  }

  void setSelectedCoverPhotoUrl(String? url) {
    if (url == null) {
      state = state.copyWith(clearCoverPhotoUrl: true);
    } else {
      state = state.copyWith(
        coverPhotoUrl: url,
        clearSelectedImageFile: true,
      );
    }
  }

  void clearPhoto() => state = state.copyWith(
        clearSelectedImageFile: true,
        clearCoverPhotoUrl: true,
      );

  // ── Step navigation ──────────────────────────────────────────────────────

  void goToStep(int step) {
    if (step >= 1 && step <= 5) {
      state = state.copyWith(currentStep: step);
    }
  }

  void nextStep() {
    if (state.currentStep < 5) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void prevStep() {
    if (state.currentStep > 1) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── Display helpers ──────────────────────────────────────────────────────

  String get servingsDisplay {
    if (state.servings <= 2) return '< 2 serves';
    if (state.servings <= 4) return '~ 3-4 serves';
    if (state.servings <= 6) return '~ 5-6 serves';
    if (state.servings <= 8) return '~ 7-8 serves';
    return '> 8 serves';
  }

  String get prepTimeDisplay {
    if (state.prepTimeMin <= 10) return '< 10 mins';
    if (state.prepTimeMin <= 20) return '~ 15 mins';
    if (state.prepTimeMin <= 30) return '~ 20-30 mins';
    return '> 30 mins';
  }

  String get cookTimeDisplay {
    if (state.cookTimeMin <= 15) return '< 15 mins';
    if (state.cookTimeMin <= 30) return '~ 30 mins';
    if (state.cookTimeMin <= 45) return '~ 45 mins';
    if (state.cookTimeMin <= 60) return '~ 60 mins';
    return '> 1 hr';
  }

  // ── Tag parsing ──────────────────────────────────────────────────────────

  List<String> get parsedTags {
    if (state.tags.trim().isEmpty) return [];
    return state.tags
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── Validation ───────────────────────────────────────────────────────────

  /// Validates the current step and returns an error message, or `null`
  /// if valid. The widget should show the message as a snackbar.
  String? validateStep(
    int step, {
    List<String>? formattedIngredients,
    List<String>? formattedInstructions,
  }) {
    switch (step) {
      case 1:
        if (state.name.trim().isEmpty) {
          return 'Please enter a recipe title';
        }
        if (state.selectedImageFile == null &&
            (state.coverPhotoUrl == null || state.coverPhotoUrl!.trim().isEmpty)) {
          return 'Please add a cover photo of your dish';
        }
        return null;
      case 2:
        if (state.selectedCategoryId == null) {
          return 'Please select a recipe category';
        }
        return null;
      case 3:
        if ((formattedIngredients?.length ?? 0) < 2) {
          return 'Please add at least 2 ingredients';
        }
        return null;
      case 4:
        if ((formattedInstructions?.length ?? 0) < 2) {
          return 'Please add at least 2 instruction steps';
        }
        return null;
      default:
        return null;
    }
  }

  // ── Formatting helpers ───────────────────────────────────────────────────

  /// Turns ingredient row data (amount, unit, name, notes) into display
  /// strings like `"2 cups rice (jasmine)"`.
  static List<String> formatIngredients(
    List<({String amount, String unit, String name, String notes})> rows,
  ) {
    final list = <String>[];
    for (final row in rows) {
      final amt = row.amount.trim();
      final unit = row.unit.trim();
      final name = row.name.trim();
      final notes = row.notes.trim();
      if (name.isEmpty && amt.isEmpty) continue;
      final parts = <String>[];
      if (amt.isNotEmpty) parts.add(amt);
      if (unit.isNotEmpty) parts.add(unit);
      if (name.isNotEmpty) parts.add(name);
      var str = parts.join(' ');
      if (notes.isNotEmpty) str += ' ($notes)';
      if (str.isNotEmpty) list.add(str);
    }
    return list;
  }

  /// Turns instruction step data (description, tip) into display strings
  /// like `"Boil water (Tip: use filtered)"`.
  static List<String> formatInstructions(
    List<({String description, String tip})> steps,
  ) {
    final list = <String>[];
    for (final step in steps) {
      final desc = step.description.trim();
      final tip = step.tip.trim();
      if (desc.isEmpty) continue;
      if (tip.isNotEmpty) {
        list.add('$desc (Tip: $tip)');
      } else {
        list.add(desc);
      }
    }
    return list;
  }

  /// Filters empty tips from a list of tip strings.
  static List<String> formatChefsTips(List<String> tips) {
    return tips.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  // ── Submit recipe ────────────────────────────────────────────────────────

  /// Validates, uploads the cover photo (if a local file was picked),
  /// and persists the recipe to Firestore.
  ///
  /// The caller (widget) passes the formatted ingredients, instructions,
  /// and chef's tips that it collected from its own TextEditingControllers.
  /// This keeps text-editing concerns in the widget layer.
  Future<RecipeSubmitResult> submitRecipe({
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> chefsTips,
    RecipeModel? recipeToEdit,
  }) async {
    // ── Validate ──
    final ingredientError =
        validateStep(3, formattedIngredients: ingredients);
    if (ingredientError != null) {
      return RecipeSubmitResult.failure(ingredientError);
    }

    final instructionError =
        validateStep(4, formattedInstructions: instructions);
    if (instructionError != null) {
      return RecipeSubmitResult.failure(instructionError);
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      return RecipeSubmitResult.failure('Please sign in to upload a recipe');
    }

    // ── Upload cover image ──
    String coverUrl = state.coverPhotoUrl ?? '';

    if (state.selectedImageFile != null) {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(
              'users/${user.uid}/recipes/recipe_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(
        state.selectedImageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      coverUrl = await uploadTask.ref.getDownloadURL();
    }

    if (coverUrl.isEmpty) {
      return RecipeSubmitResult.failure('Please add a cover photo of your dish');
    }

    // ── Resolve category ──
    final categoryModel = RecipeCategoryModel.defaultCategories.firstWhere(
      (cat) => cat.id == state.selectedCategoryId,
      orElse: () => RecipeCategoryModel.defaultCategories.first,
    );

    final tags = parsedTags.isNotEmpty
        ? parsedTags
        : [categoryModel.name.toLowerCase()];

    final recipeRepo = ref.read(recipeRepositoryProvider);

    // ── Update existing recipe ──
    if (recipeToEdit != null) {
      final updatedRecipe = RecipeModel(
        id: recipeToEdit.id,
        name: state.name.trim(),
        description: state.description.trim(),
        category: categoryModel.name,
        region: state.region == 'Any region' ? 'Philippines' : state.region,
        prepTime: '${state.prepTimeMin} mins',
        cookTime: '${state.cookTimeMin} mins',
        servings: state.servings,
        difficulty: state.difficulty,
        ingredients: ingredients,
        instructions: instructions,
        chefsTips: chefsTips,
        tags: tags,
        coverPhotoUrl: coverUrl,
        source: recipeToEdit.source,
        authorId: recipeToEdit.authorId,
        authorName: recipeToEdit.authorName,
        authorPhotoUrl: recipeToEdit.authorPhotoUrl,
        isSystemRecipe: recipeToEdit.isSystemRecipe,
        createdAt: recipeToEdit.createdAt,
        budget: state.budget,
        status: recipeToEdit.status,
        likeCount: recipeToEdit.likeCount,
        commentCount: recipeToEdit.commentCount,
        favoriteCount: recipeToEdit.favoriteCount,
        ratingAvg: recipeToEdit.ratingAvg,
        ratingCount: recipeToEdit.ratingCount,
        trendingScore: recipeToEdit.trendingScore,
      );

      await recipeRepo.updateRecipe(recipeToEdit.id!, updatedRecipe);

      return RecipeSubmitResult.success(
        message: 'Recipe updated successfully!',
        updatedRecipeId: recipeToEdit.id,
      );
    }

    // ── Create new recipe ──
    final newRecipe = RecipeModel(
      name: state.name.trim(),
      description: state.description.trim(),
      category: categoryModel.name,
      region: state.region == 'Any region' ? 'Philippines' : state.region,
      prepTime: '${state.prepTimeMin} mins',
      cookTime: '${state.cookTimeMin} mins',
      servings: state.servings,
      difficulty: state.difficulty,
      ingredients: ingredients,
      instructions: instructions,
      chefsTips: chefsTips,
      tags: tags,
      coverPhotoUrl: coverUrl,
      source: '',
      authorId: user.uid,
      authorName:
          user.displayName ?? 'Chef ${user.email?.split('@').first ?? 'Foodie'}',
      authorPhotoUrl: user.photoURL,
      isSystemRecipe: false,
      createdAt: DateTime.now(),
      budget: state.budget,
      status: 'pending',
    );

    final newDocId = await recipeRepo.addRecipe(newRecipe);

    return RecipeSubmitResult.success(
      recipeDocId: newDocId,
    );
  }

  // ── Pre-fill from existing recipe (edit mode) ────────────────────────────

  /// Populates the form state from an existing [RecipeModel] so the widget
  /// can pre-fill its controllers in `initState`.
  void loadRecipeForEdit(RecipeModel recipe) {
    final regionOptions = [
      'Any region',
      'Tagalog',
      'Ilocano',
      'Kapampangan',
      'Bicolano',
      'Cebuano',
      'Ilonggo',
      'Waray',
      'Mindanaoan',
      'Other / Fusion',
    ];
    final difficultyOptions = ['Easy', 'Medium', 'Hard'];
    final budgetOptions = [
      '< ₱150 (Budget friendly)',
      '~ ₱150 - ₱300 (Affordable)',
      '~ ₱300 - ₱500 (Special)',
      '> ₱500 (Quite Expensive)',
    ];

    // Category
    final cat = RecipeCategoryModel.defaultCategories.firstWhere(
      (c) => c.name.toLowerCase() == recipe.category.toLowerCase(),
      orElse: () => RecipeCategoryModel.defaultCategories.first,
    );

    // Region
    String region;
    if (regionOptions.contains(recipe.region)) {
      region = recipe.region;
    } else if (recipe.region == 'Philippines') {
      region = 'Any region';
    } else {
      region = 'Other / Fusion';
    }

    // Difficulty
    final difficulty = difficultyOptions.contains(recipe.difficulty)
        ? recipe.difficulty
        : 'Easy';

    // Budget
    String budget;
    if (recipe.budget != null) {
      budget = budgetOptions.firstWhere(
        (b) =>
            b.toLowerCase().contains(recipe.budget!.toLowerCase()) ||
            recipe.budget!.toLowerCase().contains(b.toLowerCase()),
        orElse: () => budgetOptions.first,
      );
    } else {
      budget = budgetOptions.first;
    }

    // Servings
    final servings = recipe.servings;

    // Prep time
    final prepDigits =
        int.tryParse(recipe.prepTime.replaceAll(RegExp(r'[^0-9]'), ''));
    final prepTimeMin = prepDigits ?? 15;

    // Cook time
    final cookDigits =
        int.tryParse(recipe.cookTime.replaceAll(RegExp(r'[^0-9]'), ''));
    final cookTimeMin = cookDigits ?? 30;

    // Tags
    final tags = recipe.tags.join(', ');

    // Ingredients → raw strings (widget parses into controllers)
    final ingredientStrings = <String>[];
    for (final ingredient in recipe.ingredients) {
      ingredientStrings.add(ingredient);
    }

    // Instructions → raw strings (widget parses into controllers)
    final instructionStrings = <String>[];
    for (final step in recipe.instructions) {
      instructionStrings.add(step);
    }

    // Chef's tips → raw strings (widget parses into controllers)
    final tipStrings = <String>[];
    for (final tip in recipe.chefsTips) {
      tipStrings.add(tip);
    }

    state = RecipeFormState(
      name: recipe.name,
      description: recipe.description,
      selectedCategoryId: cat.id,
      region: region,
      difficulty: difficulty,
      budget: budget,
      servings: servings,
      prepTimeMin: prepTimeMin,
      cookTimeMin: cookTimeMin,
      tags: tags,
      coverPhotoUrl: recipe.coverPhotoUrl,
      ingredientStrings: ingredientStrings,
      instructionStrings: instructionStrings,
      tipStrings: tipStrings,
    );
  }
}

/// Immutable state for the recipe creation / edit form.
class RecipeFormState {
  const RecipeFormState({
    this.name = '',
    this.description = '',
    this.selectedCategoryId,
    this.region = 'Any region',
    this.difficulty = 'Easy',
    this.budget = '< ₱150 (Budget friendly)',
    this.servings = 4,
    this.prepTimeMin = 15,
    this.cookTimeMin = 30,
    this.tags = '',
    this.selectedImageFile,
    this.coverPhotoUrl,
    this.currentStep = 1,
    this.ingredientStrings = const [],
    this.instructionStrings = const [],
    this.tipStrings = const [],
  });

  final String name;
  final String description;
  final String? selectedCategoryId;
  final String region;
  final String difficulty;
  final String budget;
  final int servings;
  final int prepTimeMin;
  final int cookTimeMin;
  final String tags;
  final File? selectedImageFile;
  final String? coverPhotoUrl;
  final int currentStep;

  /// Raw ingredient strings from edit-mode pre-fill.
  /// The widget parses these into `_IngredientRowData` controllers.
  final List<String> ingredientStrings;

  /// Raw instruction strings from edit-mode pre-fill.
  final List<String> instructionStrings;

  /// Raw tip strings from edit-mode pre-fill.
  final List<String> tipStrings;

  RecipeFormState copyWith({
    String? name,
    String? description,
    String? selectedCategoryId,
    String? region,
    String? difficulty,
    String? budget,
    int? servings,
    int? prepTimeMin,
    int? cookTimeMin,
    String? tags,
    File? selectedImageFile,
    bool clearSelectedImageFile = false,
    String? coverPhotoUrl,
    bool clearCoverPhotoUrl = false,
    int? currentStep,
    List<String>? ingredientStrings,
    List<String>? instructionStrings,
    List<String>? tipStrings,
  }) {
    return RecipeFormState(
      name: name ?? this.name,
      description: description ?? this.description,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      region: region ?? this.region,
      difficulty: difficulty ?? this.difficulty,
      budget: budget ?? this.budget,
      servings: servings ?? this.servings,
      prepTimeMin: prepTimeMin ?? this.prepTimeMin,
      cookTimeMin: cookTimeMin ?? this.cookTimeMin,
      tags: tags ?? this.tags,
      selectedImageFile: clearSelectedImageFile
          ? null
          : (selectedImageFile ?? this.selectedImageFile),
      coverPhotoUrl: clearCoverPhotoUrl
          ? null
          : (coverPhotoUrl ?? this.coverPhotoUrl),
      currentStep: currentStep ?? this.currentStep,
      ingredientStrings: ingredientStrings ?? this.ingredientStrings,
      instructionStrings: instructionStrings ?? this.instructionStrings,
      tipStrings: tipStrings ?? this.tipStrings,
    );
  }
}
