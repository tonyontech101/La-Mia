import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Full-screen editing page for recipe instructions, inspired by TikTok's flow.
class RecipeInstructionsScreen extends StatefulWidget {
  const RecipeInstructionsScreen({
    super.key,
    required this.initialInstructions,
  });

  final List<String> initialInstructions;

  @override
  State<RecipeInstructionsScreen> createState() => _RecipeInstructionsScreenState();
}

class _RecipeInstructionsScreenState extends State<RecipeInstructionsScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialInstructions.isEmpty) {
      _addStep();
    } else {
      for (var step in widget.initialInstructions) {
        _controllers.add(TextEditingController(text: step));
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

  void _addStep() {
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

  void _removeStep(int index) {
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
          'Instructions',
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
                      'Explain the steps clearly to guide others in cooking your recipe (e.g. "Heat oil in a pan", "Simmer for 15 mins").',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step number indicator
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            radius: 14,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Step Input Field
                        Expanded(
                          child: TextFormField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 3,
                            minLines: 1,
                            style: AppTypography.body(),
                            decoration: InputDecoration(
                              hintText: 'Describe this step...',
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
                                _addStep();
                              } else {
                                _focusNodes[index + 1].requestFocus();
                              }
                            },
                          ),
                        ),
                        
                        // Delete Button
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _removeStep(index),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Add Step Sticky Footer
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
                    onPressed: _addStep,
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    label: Text(
                      'Add Step',
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
