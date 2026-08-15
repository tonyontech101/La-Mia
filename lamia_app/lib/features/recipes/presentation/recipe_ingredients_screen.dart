import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Full-screen editing page for recipe ingredients, inspired by TikTok's flow.
class RecipeIngredientsScreen extends StatefulWidget {
  const RecipeIngredientsScreen({
    super.key,
    required this.initialIngredients,
  });

  final List<String> initialIngredients;

  @override
  State<RecipeIngredientsScreen> createState() => _RecipeIngredientsScreenState();
}

class _RecipeIngredientsScreenState extends State<RecipeIngredientsScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialIngredients.isEmpty) {
      _addIngredient();
    } else {
      for (var ing in widget.initialIngredients) {
        _controllers.add(TextEditingController(text: ing));
        _focusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _controllers.add(TextEditingController());
      final newNode = FocusNode();
      _focusNodes.add(newNode);
      // Auto-focus the newly added item
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) newNode.requestFocus();
      });
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      if (_controllers.length > 1) {
        _controllers[index].dispose();
        _controllers.removeAt(index);
        _focusNodes[index].dispose();
        _focusNodes.removeAt(index);
      } else {
        _controllers[index].clear();
      }
    });
  }

  void _onSave() {
    final cleanList = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    Navigator.pop(context, cleanList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ingredients',
          style: AppTypography.title(color: AppColors.textPrimary).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTypography.bodyStrong().copyWith(fontSize: 16),
            ),
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Informative Help Header
            Container(
              width: double.infinity,
              color: AppColors.surfaceAlt,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'List your ingredients one by one, including measurements (e.g. "1 cup coconut milk", "3 cloves garlic").',
                      style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Editable List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenH,
                  vertical: AppSpacing.md,
                ),
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // Small circular indicator
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Ingredient Input Field
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textCapitalization: TextCapitalization.sentences,
                            style: AppTypography.body(),
                            decoration: InputDecoration(
                              hintText: 'e.g. 500g Chicken breast',
                              hintStyle: AppTypography.caption(
                                color: AppColors.textSecondary.withValues(alpha: 0.6),
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.field),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadii.field),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            textInputAction: index == _controllers.length - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onFieldSubmitted: (_) {
                              if (index == _controllers.length - 1) {
                                _addIngredient();
                              } else {
                                _focusNodes[index + 1].requestFocus();
                              }
                            },
                          ),
                        ),
                        
                        // Delete Button
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _removeIngredient(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Add Ingredient Sticky Footer
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: PressableScale(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    label: Text(
                      'Add Ingredient',
                      style: AppTypography.bodyStrong(color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
