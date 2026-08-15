import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/sign_up_screen.dart';
import '../data/recipe_category_model.dart';
import '../data/recipe_model.dart';
import '../data/recipe_repository.dart';
import 'recipe_ingredients_screen.dart';
import 'recipe_instructions_screen.dart';
import 'recipe_more_options_screen.dart';

/// Screen for creating and uploading a new recipe.
/// Redesigned with a TikTok-inspired layout: Category, Time, and Budget
/// are dropdown fields; Ingredients, Instructions, and More Options
/// navigate to dedicated editing screens.
class RecipeCreatingScreen extends StatefulWidget {
  const RecipeCreatingScreen({super.key});

  @override
  State<RecipeCreatingScreen> createState() => _RecipeCreatingScreenState();
}

class _RecipeCreatingScreenState extends State<RecipeCreatingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipeRepo = RecipeRepository();

  // Controllers and Form States
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  final _budgetController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedCoverPhotoUrl;
  bool _isSaving = false;

  // Form List States (managed via sub-screens)
  List<String> _ingredients = [];
  List<String> _instructions = [];

  // More Options States
  int _servings = 4;
  String _selectedDifficulty = 'Easy';
  String _region = 'Tagalog';
  String _source = '';
  List<String> _tags = [];

  // Dropdown States
  String? _selectedTimeOption;
  bool _isCustomTime = false;
  String? _selectedBudgetOption;
  bool _isCustomBudget = false;

  final List<String> _timePresets = [
    '< 15 minutes',
    '< 30 minutes',
    '> 30m < 1h',
    '> 5minutes < 2h',
    '> 2h',
    'Custom...',
  ];

  final List<String> _budgetPresets = [
    '< ₱100',
    '₱150 - ₱300',
    '₱300 - ₱500',
    '₱500+',
    'Custom...',
  ];

  // Predefined gorgeous Filipino photo presets for high-fidelity mock upload
  final List<Map<String, String>> _photoPresets = [
    {
      'name': 'Adobo',
      'url': 'https://images.unsplash.com/photo-1541014711122-4532ebbf7a94?w=600&auto=format&fit=crop&q=60',
    },
    {
      'name': 'Sinigang',
      'url': 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=60',
    },
    {
      'name': 'Inihaw / BBQ',
      'url': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=60',
    },
    {
      'name': 'Gulay / Veggies',
      'url': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=60',
    },
    {
      'name': 'Dessert / Sweets',
      'url': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&auto=format&fit=crop&q=60',
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  // Opens photo selection preset sheet
  void _showPhotoSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
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
                  'Select Dish Photo',
                  style: AppTypography.title().copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a photo style or simulate a custom upload',
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoPresets.length,
                    itemBuilder: (context, index) {
                      final item = _photoPresets[index];
                      return PressableScale(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCoverPhotoUrl = item['url'];
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: item['url']!,
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    color: Colors.black38,
                                    alignment: Alignment.bottomCenter,
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      item['name']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary),
                  title: const Text('Simulate Camera / Gallery Upload'),
                  onTap: () {
                    Navigator.pop(context);
                    _simulateImageUpload();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Mock upload showing progress spinner
  void _simulateImageUpload() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Uploading image from gallery...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context); // Close loader
        setState(() {
          // Fallback to adobo preset image
          _selectedCoverPhotoUrl = _photoPresets.first['url'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    });
  }

  // Submits the new recipe to Firestore
  void _submitRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recipe category!')),
      );
      return;
    }

    // Resolve time value
    final time = _isCustomTime ? _timeController.text.trim() : (_selectedTimeOption ?? '');
    if (time.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set the estimated time!')),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient!')),
      );
      return;
    }

    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one instruction step!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final categoryModel = RecipeCategoryModel.defaultCategories
          .firstWhere((cat) => cat.id == _selectedCategoryId);

      final newRecipe = RecipeModel(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: categoryModel.name, // "Almusal", "Ulam", etc.
        region: _region.trim(),
        prepTime: 'Estimated',
        cookTime: time,
        servings: _servings,
        difficulty: _selectedDifficulty,
        ingredients: _ingredients,
        instructions: _instructions,
        tags: _tags.isNotEmpty
            ? _tags
            : [categoryModel.name.toLowerCase()],
        coverPhotoUrl: _selectedCoverPhotoUrl ??
            'https://images.unsplash.com/photo-1541014711122-4532ebbf7a94?w=600&auto=format&fit=crop&q=60',
        source: _source.trim(),
        authorId: user?.uid,
        authorName: user?.displayName ?? 'Guest Chef',
        authorPhotoUrl: user?.photoURL,
        isSystemRecipe: false,
        createdAt: DateTime.now(),
      );

      await _recipeRepo.addRecipe(newRecipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Successfully uploaded ${newRecipe.name}!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Upload failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Recipe Creating Page',
          style: AppTypography.title(color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: user == null
                ? _buildGuestSignGate()
                : _buildUploadForm(),
          ),
        ),
      ),
    );
  }

  // Visual screen gating for Guests
  Widget _buildGuestSignGate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
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
              Navigator.pop(context); // Close upload screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close upload screen
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

  // Upload Form structure redesigned (TikTok inspired)
  Widget _buildUploadForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Recipe Photo Section
            Text(
              'Recipe Photo',
              style: AppTypography.bodyStrong().copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showPhotoSelector,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardShadow,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _selectedCoverPhotoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: _selectedCoverPhotoUrl!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  onPressed: _showPhotoSelector,
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click to add dish photo',
                            style: AppTypography.bodyStrong(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Dish Name input
            TextFormField(
              controller: _nameController,
              decoration: _buildInputDecoration('Dish name', null),
              style: AppTypography.body(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter the dish name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 3. Dish Description input
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _buildInputDecoration('Write your dish description here...', null),
              style: AppTypography.body(),
            ),
            const SizedBox(height: 24),

            const Divider(color: AppColors.border, thickness: 1, height: 16),
            const SizedBox(height: 8),

            // 4. Category Dropdown
            Text(
              'Category',
              style: AppTypography.bodyStrong().copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: _buildInputDecoration('Select category', Icons.grid_view_rounded),
              items: RecipeCategoryModel.defaultCategories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(category.icon, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                });
              },
              validator: (val) => val == null ? 'Please select a category' : null,
            ),
            const SizedBox(height: 16),

            // 5. Estimated Time Dropdown
            Text(
              'Estimated Time',
              style: AppTypography.bodyStrong().copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTimeOption,
              decoration: _buildInputDecoration('Select preparation time', Icons.timer_outlined),
              items: _timePresets.map((preset) {
                return DropdownMenuItem<String>(
                  value: preset,
                  child: Text(preset),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedTimeOption = val;
                  _isCustomTime = val == 'Custom...';
                  if (!_isCustomTime && val != null) {
                    _timeController.text = val;
                  } else if (_isCustomTime) {
                    _timeController.clear();
                  }
                });
              },
              validator: (val) => val == null ? 'Please select estimated time' : null,
            ),
            if (_isCustomTime) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _timeController,
                decoration: _buildInputDecoration(
                  'Enter custom time (e.g. >5minutes <2h)',
                  Icons.schedule_rounded,
                ),
                style: AppTypography.body(),
                validator: (val) {
                  if (_isCustomTime && (val == null || val.trim().isEmpty)) {
                    return 'Please enter custom estimated time';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),

            // 6. Budget Dropdown
            Text(
              'Budget',
              style: AppTypography.bodyStrong().copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedBudgetOption,
              decoration: _buildInputDecoration('Select estimated budget', Icons.payments_outlined),
              items: _budgetPresets.map((preset) {
                return DropdownMenuItem<String>(
                  value: preset,
                  child: Text(preset),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedBudgetOption = val;
                  _isCustomBudget = val == 'Custom...';
                  if (!_isCustomBudget && val != null) {
                    _budgetController.text = val;
                  } else if (_isCustomBudget) {
                    _budgetController.clear();
                  }
                });
              },
              validator: (val) => val == null ? 'Please select estimated budget' : null,
            ),
            if (_isCustomBudget) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _budgetController,
                decoration: _buildInputDecoration(
                  'Enter custom budget (e.g. ₱250)',
                  Icons.money_rounded,
                ),
                style: AppTypography.body(),
                validator: (val) {
                  if (_isCustomBudget && (val == null || val.trim().isEmpty)) {
                    return 'Please enter custom budget';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),

            const Divider(color: AppColors.border, thickness: 1, height: 32),

            // 7. Prepare the Ingredients Option Tile
            _TikTokOptionTile(
              icon: Icons.soup_kitchen_outlined,
              title: 'Prepare the Ingredients',
              valueText: _ingredients.isEmpty ? 'Tap to add' : '${_ingredients.length} items',
              onTap: () async {
                final result = await Navigator.push<List<String>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeIngredientsScreen(
                      initialIngredients: _ingredients,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _ingredients = result;
                  });
                }
              },
            ),

            // 8. Add Instructions Option Tile
            _TikTokOptionTile(
              icon: Icons.list_rounded,
              title: 'Add Instructions',
              valueText: _instructions.isEmpty ? 'Tap to add' : '${_instructions.length} steps',
              onTap: () async {
                final result = await Navigator.push<List<String>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeInstructionsScreen(
                      initialInstructions: _instructions,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _instructions = result;
                  });
                }
              },
            ),

            // 9. More Options Option Tile
            _TikTokOptionTile(
              icon: Icons.more_horiz_rounded,
              title: 'More options',
              valueText: 'Difficulty: $_selectedDifficulty',
              onTap: () async {
                final result = await Navigator.push<MoreOptionsResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeMoreOptionsScreen(
                      servings: _servings,
                      difficulty: _selectedDifficulty,
                      region: _region,
                      source: _source,
                      tags: _tags,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _servings = result.servings;
                    _selectedDifficulty = result.difficulty;
                    _region = result.region;
                    _source = result.source;
                    _tags = result.tags;
                  });
                }
              },
            ),

            const SizedBox(height: 32),

            // Submit Button
            PrimaryButton(
              label: 'Publish Recipe',
              isLoading: _isSaving,
              onPressed: _submitRecipe,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // Reusable custom themed InputDecoration builder
  InputDecoration _buildInputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.caption(color: AppColors.textSecondary.withValues(alpha: 0.7)),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 20) : null,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

/// Custom TikTok-style Option list row
class _TikTokOptionTile extends StatelessWidget {
  const _TikTokOptionTile({
    required this.icon,
    required this.title,
    required this.valueText,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                ),
              ),
              Text(
                valueText,
                style: AppTypography.caption(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
