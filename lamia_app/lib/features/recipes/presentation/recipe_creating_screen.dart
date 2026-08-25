import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/login_screen.dart';
import 'ai_verification_screen.dart';
import '../../auth/presentation/sign_up_screen.dart';
import '../data/recipe_category_model.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import '../../home/presentation/widgets/feed_recipe_card.dart';
import '../../../core/widgets/slide_tab_switcher.dart';
import '../../../core/widgets/sliding_tab_bar.dart';

/// Models an ingredient row item in the step 3 builder.
class _IngredientRowData {
  _IngredientRowData({
    String amount = '',
    String unit = '',
    String name = '',
    String notes = '',
  })  : amountController = TextEditingController(text: amount),
        unitController = TextEditingController(text: unit),
        nameController = TextEditingController(text: name),
        notesController = TextEditingController(text: notes);

  final TextEditingController amountController;
  final TextEditingController unitController;
  final TextEditingController nameController;
  final TextEditingController notesController;

  void dispose() {
    amountController.dispose();
    unitController.dispose();
    nameController.dispose();
    notesController.dispose();
  }
}

/// Models an instruction step item in the step 4 builder.
class _InstructionStepData {
  _InstructionStepData({
    String description = '',
    String tip = '',
  })  : descriptionController = TextEditingController(text: description),
        tipController = TextEditingController(text: tip);

  final TextEditingController descriptionController;
  final TextEditingController tipController;

  void dispose() {
    descriptionController.dispose();
    tipController.dispose();
  }
}

/// Screen for creating and uploading a new recipe.
/// Redesigned as a modern 5-step wizard in a clean elevated card matching
/// the reference design.
class RecipeCreatingScreen extends StatefulWidget {
  const RecipeCreatingScreen({super.key, this.recipeToEdit});

  final RecipeModel? recipeToEdit;

  @override
  State<RecipeCreatingScreen> createState() => _RecipeCreatingScreenState();
}

class _RecipeCreatingScreenState extends State<RecipeCreatingScreen> {
  final _recipeRepo = RecipeRepository();
  int _currentStep = 1; // 1 to 5
  bool _isSaving = false;
  int _previewActiveTabIndex = 0;

  // ── Step 1: Basic Info ──────────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCoverPhotoUrl;
  File? _selectedImageFile;
  final ImagePicker _imagePicker = ImagePicker();

  // ── Step 2: Details & Times ─────────────────────────────────────────────────
  String? _selectedCategoryId;
  String _selectedRegion = 'Any region';
  String _selectedDifficulty = 'Easy';
  String _selectedBudget = '< ₱150 (Budget friendly)';
  int _servings = 4;
  int _prepTimeMin = 15;
  int _cookTimeMin = 30;
  final _tagsController = TextEditingController();

  String get _servingsDisplay {
    if (_servings <= 2) return '< 2 serves';
    if (_servings <= 4) return '~ 3-4 serves';
    if (_servings <= 6) return '~ 5-6 serves';
    if (_servings <= 8) return '~ 7-8 serves';
    return '> 8 serves';
  }

  String get _prepTimeDisplay {
    if (_prepTimeMin <= 10) return '< 10 mins';
    if (_prepTimeMin <= 20) return '~ 15 mins';
    if (_prepTimeMin <= 30) return '~ 20-30 mins';
    return '> 30 mins';
  }

  String get _cookTimeDisplay {
    if (_cookTimeMin <= 15) return '< 15 mins';
    if (_cookTimeMin <= 30) return '~ 30 mins';
    if (_cookTimeMin <= 45) return '~ 45 mins';
    if (_cookTimeMin <= 60) return '~ 60 mins';
    return '> 1 hr';
  }

  // ── Step 3: Ingredients ─────────────────────────────────────────────────────
  final List<_IngredientRowData> _ingredientItems = [];

  // ── Step 4: Instructions ────────────────────────────────────────────────────
  final List<_InstructionStepData> _instructionItems = [];

  // ── Chef's Tips ─────────────────────────────────────────────────────────────
  final List<TextEditingController> _chefsTipControllers = [];

  // Region options
  final List<String> _regionOptions = [
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

  // Difficulty options
  final List<String> _difficultyOptions = [
    'Easy',
    'Medium',
    'Hard',
  ];

  // Budget options
  final List<String> _budgetOptions = [
    '< ₱150 (Budget friendly)',
    '~ ₱150 - ₱300 (Affordable)',
    '~ ₱300 - ₱500 (Special)',
    '> ₱500 (Quite Expensive)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.recipeToEdit != null) {
      final r = widget.recipeToEdit!;
      _titleController.text = r.name;
      _descriptionController.text = r.description;
      _selectedCoverPhotoUrl = r.coverPhotoUrl;

      // Category matching
      final cat = RecipeCategoryModel.defaultCategories.firstWhere(
        (c) => c.name.toLowerCase() == r.category.toLowerCase(),
        orElse: () => RecipeCategoryModel.defaultCategories.first,
      );
      _selectedCategoryId = cat.id;

      // Region matching
      if (_regionOptions.contains(r.region)) {
        _selectedRegion = r.region;
      } else if (r.region == 'Philippines') {
        _selectedRegion = 'Any region';
      } else {
        _selectedRegion = 'Other / Fusion';
      }

      // Difficulty matching
      if (_difficultyOptions.contains(r.difficulty)) {
        _selectedDifficulty = r.difficulty;
      }

      // Budget matching
      final budgetStr = r.budget;
      if (budgetStr != null) {
        final matchedBudget = _budgetOptions.firstWhere(
          (b) => b.toLowerCase().contains(budgetStr.toLowerCase()) || budgetStr.toLowerCase().contains(b.toLowerCase()),
          orElse: () => _budgetOptions.first,
        );
        _selectedBudget = matchedBudget;
      }

      _servings = r.servings;

      // Parse cook & prep times
      final prepDigits = int.tryParse(r.prepTime.replaceAll(RegExp(r'[^0-9]'), ''));
      if (prepDigits != null) _prepTimeMin = prepDigits;

      final cookDigits = int.tryParse(r.cookTime.replaceAll(RegExp(r'[^0-9]'), ''));
      if (cookDigits != null) _cookTimeMin = cookDigits;

      _tagsController.text = r.tags.join(', ');

      // Ingredients loading
      for (final ingredient in r.ingredients) {
        String name = ingredient;
        String notes = '';
        if (ingredient.contains('(') && ingredient.endsWith(')')) {
          final openParen = ingredient.lastIndexOf('(');
          name = ingredient.substring(0, openParen).trim();
          notes = ingredient.substring(openParen + 1, ingredient.length - 1).trim();
        }
        _ingredientItems.add(_IngredientRowData(name: name, notes: notes));
      }

      // Instructions loading
      for (final step in r.instructions) {
        String desc = step;
        String tip = '';
        if (step.contains('(Tip:') && step.endsWith(')')) {
          final openTip = step.lastIndexOf('(Tip:');
          desc = step.substring(0, openTip).trim();
          tip = step.substring(openTip + 5, step.length - 1).trim();
        }
        _instructionItems.add(_InstructionStepData(description: desc, tip: tip));
      }

      // Chef's tips loading
      for (final tip in r.chefsTips) {
        _chefsTipControllers.add(TextEditingController(text: tip));
      }
    }

    // Default fallbacks if empty
    if (_ingredientItems.isEmpty) {
      _ingredientItems.add(_IngredientRowData());
    }
    if (_instructionItems.isEmpty) {
      _instructionItems.add(_InstructionStepData());
    }
    if (_chefsTipControllers.isEmpty) {
      _chefsTipControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    for (final item in _ingredientItems) {
      item.dispose();
    }
    for (final item in _instructionItems) {
      item.dispose();
    }
    for (final controller in _chefsTipControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<String> get _formattedChefsTips {
    final list = <String>[];
    for (final controller in _chefsTipControllers) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        list.add(text);
      }
    }
    return list;
  }

  List<String> get _formattedIngredients {
    final list = <String>[];
    for (final item in _ingredientItems) {
      final amt = item.amountController.text.trim();
      final unit = item.unitController.text.trim();
      final name = item.nameController.text.trim();
      final notes = item.notesController.text.trim();

      if (name.isEmpty && amt.isEmpty) continue;

      final parts = <String>[];
      if (amt.isNotEmpty) parts.add(amt);
      if (unit.isNotEmpty) parts.add(unit);
      if (name.isNotEmpty) parts.add(name);
      var str = parts.join(' ');
      if (notes.isNotEmpty) {
        str += ' ($notes)';
      }
      if (str.isNotEmpty) {
        list.add(str);
      }
    }
    return list;
  }

  List<String> get _formattedInstructions {
    final list = <String>[];
    for (final item in _instructionItems) {
      final desc = item.descriptionController.text.trim();
      final tip = item.tipController.text.trim();
      if (desc.isEmpty) continue;
      if (tip.isNotEmpty) {
        list.add('$desc (Tip: $tip)');
      } else {
        list.add(desc);
      }
    }
    return list;
  }

  List<String> get _parsedTags {
    if (_tagsController.text.trim().isEmpty) return [];
    return _tagsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ── Step Navigation & Validation ────────────────────────────────────────────

  void _nextStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 1) {
      if (_titleController.text.trim().isEmpty) {
        _showToast('Please enter a recipe title');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_selectedCategoryId == null) {
        _showToast('Please select a recipe category');
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (_formattedIngredients.length < 2) {
        _showToast('Please add at least 2 ingredients');
        return;
      }
      setState(() => _currentStep = 4);
    } else if (_currentStep == 4) {
      if (_formattedInstructions.length < 2) {
        _showToast('Please add at least 2 instruction steps');
        return;
      }
      setState(() => _currentStep = 5);
    } else if (_currentStep == 5) {
      _submitRecipe();
    }
  }

  void _prevStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Photo Picker ───────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _selectedCoverPhotoUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to pick image: $e');
      }
    }
  }

  void _showPhotoSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add Dish Photo',
                  style: AppTypography.title().copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a photo or choose one from your gallery',
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Submit Recipe to Firestore ──────────────────────────────────────────────

  Future<void> _submitRecipe() async {
    final ingredients = _formattedIngredients;
    final instructions = _formattedInstructions;

    if (ingredients.length < 2) {
      _showToast('Please add at least 2 ingredients');
      setState(() => _currentStep = 3);
      return;
    }

    if (instructions.length < 2) {
      _showToast('Please add at least 2 instruction steps');
      setState(() => _currentStep = 4);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast('Please sign in to upload a recipe');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String coverUrl = _selectedCoverPhotoUrl ?? '';

      // Upload selected image file to Firebase Storage
      if (_selectedImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/recipes/recipe_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(
          _selectedImageFile!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        coverUrl = await uploadTask.ref.getDownloadURL();
      }

      if (coverUrl.isEmpty) {
        _showToast('Please add a cover photo of your dish');
        setState(() => _currentStep = 1);
        setState(() => _isSaving = false);
        return;
      }

      final categoryModel = RecipeCategoryModel.defaultCategories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
        orElse: () => RecipeCategoryModel.defaultCategories.first,
      );

      final tags = _parsedTags.isNotEmpty
          ? _parsedTags
          : [categoryModel.name.toLowerCase()];

      if (widget.recipeToEdit != null) {
        final updatedRecipe = RecipeModel(
          id: widget.recipeToEdit!.id,
          name: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: categoryModel.name,
          region: _selectedRegion == 'Any region' ? 'Philippines' : _selectedRegion,
          prepTime: '$_prepTimeMin mins',
          cookTime: '$_cookTimeMin mins',
          servings: _servings,
          difficulty: _selectedDifficulty,
          ingredients: ingredients,
          instructions: instructions,
          chefsTips: _formattedChefsTips,
          tags: tags,
          coverPhotoUrl: coverUrl,
          source: widget.recipeToEdit!.source,
          authorId: widget.recipeToEdit!.authorId,
          authorName: widget.recipeToEdit!.authorName,
          authorPhotoUrl: widget.recipeToEdit!.authorPhotoUrl,
          isSystemRecipe: widget.recipeToEdit!.isSystemRecipe,
          createdAt: widget.recipeToEdit!.createdAt,
          budget: _selectedBudget,
          status: widget.recipeToEdit!.status,
          likeCount: widget.recipeToEdit!.likeCount,
          commentCount: widget.recipeToEdit!.commentCount,
          favoriteCount: widget.recipeToEdit!.favoriteCount,
          ratingAvg: widget.recipeToEdit!.ratingAvg,
          ratingCount: widget.recipeToEdit!.ratingCount,
          trendingScore: widget.recipeToEdit!.trendingScore,
        );

        await _recipeRepo.updateRecipe(widget.recipeToEdit!.id!, updatedRecipe);

        if (!mounted) return;
        _showToast('Recipe updated successfully!');
        Navigator.pop(context, true);
        return;
      }

      final newRecipe = RecipeModel(
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: categoryModel.name,
        region: _selectedRegion == 'Any region' ? 'Philippines' : _selectedRegion,
        prepTime: '$_prepTimeMin mins',
        cookTime: '$_cookTimeMin mins',
        servings: _servings,
        difficulty: _selectedDifficulty,
        ingredients: ingredients,
        instructions: instructions,
        chefsTips: _formattedChefsTips,
        tags: tags,
        coverPhotoUrl: coverUrl,
        source: '',
        authorId: user.uid,
        authorName: user.displayName ??
            'Chef ${user.email?.split('@').first ?? 'Foodie'}',
        authorPhotoUrl: user.photoURL,
        isSystemRecipe: false,
        createdAt: DateTime.now(),
        budget: _selectedBudget,
        status: 'pending',
      );

      final newDocId = await _recipeRepo.addRecipe(newRecipe);

      if (!mounted) return;

      // Navigate to the full-screen AI verification screen
      final exitAction = await Navigator.push<VerificationExitAction>(
        context,
        MaterialPageRoute(
          builder: (_) => AiVerificationScreen(
            recipeDocId: newDocId,
            recipeName: newRecipe.name,
          ),
        ),
      );

      if (!mounted) return;

      switch (exitAction) {
        case VerificationExitAction.editRecipe:
          // Stay on the recipe editor — fields are still filled in
          break;
        case VerificationExitAction.startFresh:
          // Pop back to the previous screen so the user can open a fresh editor
          Navigator.pop(context, true);
          break;
        case VerificationExitAction.approved:
        case VerificationExitAction.backToFeed:
          Navigator.pop(context, true);
          break;
        case null:
          // User pressed system back on a non-processing phase
          break;
      }
    } catch (e) {
      if (mounted) {
        _showToast('Upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Main Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Share a Recipe',
          style: AppTypography.title(color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        child: user == null
            ? _buildGuestSignGate()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 540,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Header
                        _buildPageHeader(),
                        const SizedBox(height: 20),

                        // Main Stepper Card
                        _buildCardContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stepper Indicator
                              _buildStepperHeader(),
                              const SizedBox(height: 20),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF0F0F0),
                              ),
                              const SizedBox(height: 20),

                              // Dynamic Step Body
                              _buildStepContent(),
                              const SizedBox(height: 24),

                              // Bottom Buttons
                              _buildBottomNavigationRow(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Visual Page Header ──────────────────────────────────────────────────────

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share a Recipe',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Inspire home cooks and share your signature Filipino dishes with food lovers everywhere.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Card Container ──────────────────────────────────────────────────────────

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Stepper Header Indicator ────────────────────────────────────────────────

  Widget _buildStepperHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge(1),
        _buildStepLine(1),
        _buildStepBadge(2),
        _buildStepLine(2),
        _buildStepBadge(3),
        _buildStepLine(3),
        _buildStepBadge(4),
        _buildStepLine(4),
        _buildStepBadge(5),
      ],
    );
  }

  Widget _buildStepBadge(int stepNumber) {
    final isCompleted = _currentStep > stepNumber;
    final isActive = _currentStep == stepNumber;

    Widget content;
    BoxDecoration decoration;

    if (isCompleted) {
      // Completed step: amber circle with checkmark
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
      );
      content = const Icon(
        Icons.check_rounded,
        size: 16,
        color: Color(0xFFB45309),
      );
    } else if (isActive) {
      // Active step: solid amber circle with white text
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF59E0B),
        boxShadow: [
          BoxShadow(
            color: Color(0x33F59E0B),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );
      content = Text(
        '$stepNumber',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      // Inactive step: light gray circle with gray text
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF3F4F6),
      );
      content = Text(
        '$stepNumber',
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_currentStep > stepNumber) {
          setState(() => _currentStep = stepNumber);
        }
      },
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: decoration,
        child: content,
      ),
    );
  }

  Widget _buildStepLine(int afterStepNumber) {
    final isPassed = _currentStep > afterStepNumber;

    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isPassed ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
      ),
    );
  }

  // ── Step Content Router ─────────────────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1BasicInfo();
      case 2:
        return _buildStep2DetailsAndTimes();
      case 3:
        return _buildStep3Ingredients();
      case 4:
        return _buildStep4Instructions();
      case 5:
        return _buildStep5Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Basic Information ───────────────────────────────────────────────

  Widget _buildStep1BasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Image (Moved to top of Step 1)
        _buildFieldLabel('Hero Image'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showPhotoSelector,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: const Color(0xFFD1D5DB),
              strokeWidth: 1.5,
              radius: 12,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFFAFAFA),
              ),
              child: (_selectedImageFile != null || _selectedCoverPhotoUrl != null)
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedImageFile != null
                              ? Image.file(
                                  _selectedImageFile!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: _selectedCoverPhotoUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cover Image Selected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to change photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _selectedImageFile = null;
                              _selectedCoverPhotoUrl = null;
                            });
                          },
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 38,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Drop an image here, or click to browse',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Max 5MB. JPEG, PNG, WebP, or GIF.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Recipe Title
        _buildFieldLabel('Recipe Title *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: _buildInputDecoration(
            hint: 'e.g., Sinigang na Baboy',
          ),
        ),
        const SizedBox(height: 18),

        // Short Description
        _buildFieldLabel('Short Description'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: _buildInputDecoration(
            hint: 'A comforting sour soup perfect for rainy days...',
          ),
        ),
      ],
    );
  }

  // ── Step 2: Category & Cooking Details ──────────────────────────────────────

  Widget _buildStep2DetailsAndTimes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category
        _buildFieldLabel('Category *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
          decoration: _buildInputDecoration(hint: 'Select...'),
          items: RecipeCategoryModel.defaultCategories.map((category) {
            return DropdownMenuItem<String>(
              value: category.id,
              child: Row(
                children: [
                  Icon(category.icon, size: 18, color: const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text(category.name, style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedCategoryId = val),
        ),
        const SizedBox(height: 16),

        // Region
        _buildFieldLabel('Region'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedRegion,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
          decoration: _buildInputDecoration(hint: 'Any region'),
          items: _regionOptions.map((reg) {
            return DropdownMenuItem<String>(
              value: reg,
              child: Text(reg, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRegion = val);
          },
        ),
        const SizedBox(height: 16),

        // Difficulty
        _buildFieldLabel('Difficulty'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedDifficulty,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
          decoration: _buildInputDecoration(hint: 'Easy'),
          items: _difficultyOptions.map((diff) {
            return DropdownMenuItem<String>(
              value: diff,
              child: Text(diff, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedDifficulty = val);
          },
        ),
        const SizedBox(height: 16),

        // Cost / Budget
        _buildFieldLabel('Cost / Budget *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedBudget,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
          decoration: _buildInputDecoration(hint: 'Select Budget...'),
          items: _budgetOptions.map((budget) {
            return DropdownMenuItem<String>(
              value: budget,
              child: Text(budget, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedBudget = val);
          },
        ),
        const SizedBox(height: 16),

        // Servings Counter
        _buildFieldLabel('Servings (Approximate)'),
        const SizedBox(height: 6),
        _buildCounterBox(
          value: _servingsDisplay,
          onMinus: () {
            if (_servings > 1) setState(() => _servings--);
          },
          onPlus: () => setState(() => _servings++),
        ),
        const SizedBox(height: 16),

        // Prep Time Counter
        _buildFieldLabel('Prep Time (Approximate)'),
        const SizedBox(height: 6),
        _buildCounterBox(
          value: _prepTimeDisplay,
          onMinus: () {
            if (_prepTimeMin >= 5) {
              setState(() => _prepTimeMin -= 5);
            } else if (_prepTimeMin > 0) {
              setState(() => _prepTimeMin = 0);
            }
          },
          onPlus: () => setState(() => _prepTimeMin += 5),
        ),
        const SizedBox(height: 16),

        // Cook Time Counter
        _buildFieldLabel('Cook Time (Approximate)'),
        const SizedBox(height: 6),
        _buildCounterBox(
          value: _cookTimeDisplay,
          onMinus: () {
            if (_cookTimeMin >= 5) {
              setState(() => _cookTimeMin -= 5);
            } else if (_cookTimeMin > 0) {
              setState(() => _cookTimeMin = 0);
            }
          },
          onPlus: () => setState(() => _cookTimeMin += 5),
        ),
        const SizedBox(height: 16),

        // Tags
        _buildFieldLabel('Tags'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _tagsController,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
          decoration: _buildInputDecoration(
            hint: 'budget, lenten, freezer-friendly, kids-love-it',
          ),
        ),
      ],
    );
  }

  // ── Step 3: Ingredients ─────────────────────────────────────────────────────

  Widget _buildStep3Ingredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _ingredientItems.add(_IngredientRowData());
                });
              },
              child: const Text(
                '+ Add Ingredient',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Ingredient Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ingredientItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = _ingredientItems[index];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Amount
                SizedBox(
                  width: 58,
                  child: TextFormField(
                    controller: row.amountController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _buildMiniInputDecoration(hint: 'Amt'),
                  ),
                ),
                const SizedBox(width: 6),

                // Unit
                SizedBox(
                  width: 62,
                  child: TextFormField(
                    controller: row.unitController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _buildMiniInputDecoration(hint: 'Unit'),
                  ),
                ),
                const SizedBox(width: 6),

                // Ingredient Name
                Expanded(
                  child: TextFormField(
                    controller: row.nameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _buildMiniInputDecoration(hint: 'Ingredient name'),
                  ),
                ),
                const SizedBox(width: 6),

                // Notes
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: row.notesController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _buildMiniInputDecoration(hint: 'Notes'),
                  ),
                ),

                // Delete button if more than 1 item
                if (_ingredientItems.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      setState(() {
                        row.dispose();
                        _ingredientItems.removeAt(index);
                      });
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Step 4: Instructions ────────────────────────────────────────────────────

  Widget _buildStep4Instructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Instructions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _instructionItems.add(_InstructionStepData());
                });
              },
              child: const Text(
                '+ Add Step',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Steps List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _instructionItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final step = _instructionItems[index];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Red Circle Badge
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(top: 8),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD61A1A),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Description + Tip Inputs
                Expanded(
                  child: Column(
                    children: [
                      // Step Description
                      TextFormField(
                        controller: step.descriptionController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: _buildInputDecoration(
                          hint: 'Describe this step...',
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Optional Tip
                      TextFormField(
                        controller: step.tipController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tip for this step (optional)',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button if more than 1 step
                if (_instructionItems.length > 1) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    padding: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      setState(() {
                        step.dispose();
                        _instructionItems.removeAt(index);
                      });
                    },
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 20),

        // Chef's Tips Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chef\'s Tips',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _chefsTipControllers.add(TextEditingController());
                });
              },
              child: const Text(
                '+ Add Tip',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Share your secret techniques, ingredient substitutes, or serving advice for home cooks.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),

        // Chef's Tips List
        if (_chefsTipControllers.isEmpty) ...[
          GestureDetector(
            onTap: () {
              setState(() {
                _chefsTipControllers.add(TextEditingController());
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add_circle_outline_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Tap to add your first Chef\'s Tip...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chefsTipControllers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final controller = _chefsTipControllers[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 15,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: index == 0
                            ? 'e.g. Marinate pork overnight for richer flavor...'
                            : index == 1
                                ? 'e.g. Squeeze fresh calamansi right before serving...'
                                : 'Add another cooking tip...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        _chefsTipControllers.removeAt(index);
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // ── Step 5: Review & Publish ────────────────────────────────────────────────

  Widget _buildStep5Review() {
    final categoryModel = RecipeCategoryModel.defaultCategories.firstWhere(
      (cat) => cat.id == _selectedCategoryId,
      orElse: () => RecipeCategoryModel.defaultCategories.first,
    );

    final tags = _parsedTags.isNotEmpty
        ? _parsedTags
        : [categoryModel.name.toLowerCase()];

    final user = FirebaseAuth.instance.currentUser;

    final tempRecipe = RecipeModel(
      name: _titleController.text.trim().isEmpty
          ? 'Untitled Recipe'
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: categoryModel.name,
      region: _selectedRegion == 'Any region' ? 'Philippines' : _selectedRegion,
      prepTime: '$_prepTimeMin mins',
      cookTime: '$_cookTimeMin mins',
      servings: _servings,
      difficulty: _selectedDifficulty,
      ingredients: _formattedIngredients,
      instructions: _formattedInstructions,
      chefsTips: _formattedChefsTips,
      tags: tags,
      coverPhotoUrl: _selectedCoverPhotoUrl ??
          'https://images.unsplash.com/photo-1541014711122-4532ebbf7a94?w=600&auto=format&fit=crop&q=60',
      source: '',
      authorId: user?.uid,
      authorName: user?.displayName ?? 'Guest Chef',
      authorPhotoUrl: user?.photoURL,
      isSystemRecipe: false,
      createdAt: DateTime.now(),
      budget: _selectedBudget,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preview & Publish',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'See how your recipe will look on the feed and detail screen.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        // Section 1: Feed Card Preview
        const Text(
          'Feed Card Preview',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        FeedRecipeCard(
          recipe: tempRecipe,
          onTap: null, // Static preview
        ),
        const SizedBox(height: 24),

        // Section 2: Detail Screen Preview
        const Text(
          'Detail Screen Preview',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F6), // Slightly warm background matching reference detail screen
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mock AppBar header
              Container(
                color: const Color(0xFFFAF9F6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 22),
                    const Spacer(),
                    Text(
                      'Recipe Preview',
                      style: AppTypography.title().copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 22),
                  ],
                ),
              ),
              
              // Cover Photo Banner
              _selectedImageFile != null
                  ? Image.file(
                      _selectedImageFile!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: tempRecipe.coverPhotoUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    ),
              
              // Overlaid floating card
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildDetailSummaryCardPreview(tempRecipe),
                ),
              ),
              
              // Interactive tabs section
              Transform.translate(
                offset: const Offset(0, -10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Folder Tab Bar
                        Container(
                          padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEBE6E0),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(19),
                            ),
                          ),
                          child: SlidingTabBar(
                            index: _previewActiveTabIndex,
                            itemCount: 3,
                            highlight: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                            ),
                            onChanged: (i) => setState(() => _previewActiveTabIndex = i),
                            builder: (context, i, isActive) {
                              const titles = [
                                'Ingredients',
                                'Instructions',
                                'Chef\'s Tips',
                              ];
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 240),
                                    curve: Curves.easeOutCubic,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isActive
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF4B5563),
                                    ),
                                    child: Text(titles[i]),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Tab Contents
                        SlideTabSwitcher(
                          index: _previewActiveTabIndex,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            child: _buildPreviewActiveTabContent(tempRecipe),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewActiveTabContent(RecipeModel recipe) {
    switch (_previewActiveTabIndex) {
      case 0:
        // Tab 1: Ingredients (centered list)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recipe.ingredients.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No ingredients added yet.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                ]
              : recipe.ingredients.map((ingredient) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          ingredient,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
        );

      case 1:
        // Tab 2: Instructions (numbered list)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recipe.instructions.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No instructions added yet.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                ]
              : recipe.instructions.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final step = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD61A1A),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$idx',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF374151),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
        );

      case 2:
        // Tab 3: Chef's Tips
        final tips = recipe.chefsTips.isNotEmpty
            ? recipe.chefsTips
            : const [
                'Use fresh, high-quality ingredients for optimal taste and aroma.',
                'Adjust seasoning gradually to suit your personal preference.',
                'Let the dish rest for 5 minutes before serving to allow flavors to meld together.',
              ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.chefsTips.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Default Chef\'s Tips (None added yet):',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ...tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailSummaryCardPreview(RecipeModel recipe) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Dish Title & Like Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Dummy Rating & Likes for preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 2),
                      Text(
                        '4.8',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.favorite_rounded,
                        size: 20,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '482',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Short description
          Text(
            'A ${recipe.category.toLowerCase()} recipe'
            '${recipe.region.isEmpty || recipe.region == 'Unknown' ? '' : ' from ${recipe.region}'}'
            ' • ${recipe.budget ?? 'Budget friendly'}.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Author & Action Icons Row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Author avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: recipe.authorPhotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: recipe.authorPhotoUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Center(
                                  child: Text(
                                    recipe.authorName.isNotEmpty
                                        ? recipe.authorName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                recipe.authorName.isNotEmpty
                                    ? recipe.authorName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Recipe by ${recipe.authorName}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              border: Border.all(color: const Color(0xFFFFC1C1)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Original',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD61A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Dummy Action Icons
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.print_outlined,
                  size: 20,
                  color: Color(0xFF1F2937),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: Color(0xFF1F2937),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 20,
                  color: Color(0xFF1F2937),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metric Boxes Row (Prep, Cook, Serves)
          Row(
            children: [
              Expanded(
                child: _buildDetailMetricBoxPreview(
                  icon: Icons.access_time,
                  label: 'Prep',
                  value: recipe.prepTime
                      .replaceAll(RegExp(r'mins?'), 'm')
                      .trim(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailMetricBoxPreview(
                  icon: Icons.soup_kitchen_outlined,
                  label: 'Cook',
                  value: recipe.cookTime
                      .replaceAll(RegExp(r'mins?'), 'm')
                      .trim(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDetailMetricBoxPreview(
                  icon: Icons.flatware,
                  label: 'Serves',
                  value: '${recipe.servings}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetricBoxPreview({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1F2937)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Row ───────────────────────────────────────────────────

  Widget _buildBottomNavigationRow() {
    final isLastStep = _currentStep == 5;
    final isStep4 = _currentStep == 4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Button
        GestureDetector(
          onTap: _prevStep,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text(
              _currentStep == 1 ? 'Cancel' : '← Back',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ),

        // Right Red Pill Button
        PressableScale(
          child: GestureDetector(
            onTap: _isSaving ? null : _nextStep,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFD61A1A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33D61A1A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: _isSaving
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI Checking... 🍳',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isLastStep || isStep4 ? 'Luto Na! →' : 'Next →',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestSignGate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primary,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Join the Chef Community',
            textAlign: TextAlign.center,
            style: AppTypography.headline(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You must be signed in or registered to share your own recipes and custom dishes with the La Mia community.',
            textAlign: TextAlign.center,
            style: AppTypography.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Sign In Now',
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              );
            },
            child: Text(
              'Create an Account',
              style: AppTypography.bodyStrong(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Form Widgets ─────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildCounterBox({
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      width: 130,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          // Minus
          Expanded(
            child: InkWell(
              onTap: onMinus,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
              child: const Center(
                child: Icon(Icons.remove, size: 16, color: Color(0xFF4B5563)),
              ),
            ),
          ),
          Container(
            width: 1,
            color: const Color(0xFFE5E7EB),
          ),
          // Value
          Expanded(
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: const Color(0xFFE5E7EB),
          ),
          // Plus
          Expanded(
            child: InkWell(
              onTap: onPlus,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
              child: const Center(
                child: Icon(Icons.add, size: 16, color: Color(0xFF4B5563)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
      ),
    );
  }

  InputDecoration _buildMiniInputDecoration({
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    // Simple dash logic
    final dashWidth = 5.0;
    final dashSpace = 3.0;

    final pms = path.computeMetrics();
    for (final pm in pms) {
      var distance = 0.0;
      while (distance < pm.length) {
        canvas.drawPath(
          pm.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
