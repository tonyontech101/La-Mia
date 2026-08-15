import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';

/// Structured result object passed back from [RecipeMoreOptionsScreen].
class MoreOptionsResult {
  const MoreOptionsResult({
    required this.servings,
    required this.difficulty,
    required this.region,
    required this.source,
    required this.tags,
  });

  final int servings;
  final String difficulty;
  final String region;
  final String source;
  final List<String> tags;
}

/// Full-screen editing page for additional recipe options, inspired by TikTok's flow.
class RecipeMoreOptionsScreen extends StatefulWidget {
  const RecipeMoreOptionsScreen({
    super.key,
    required this.servings,
    required this.difficulty,
    required this.region,
    required this.source,
    required this.tags,
  });

  final int servings;
  final String difficulty;
  final String region;
  final String source;
  final List<String> tags;

  @override
  State<RecipeMoreOptionsScreen> createState() => _RecipeMoreOptionsScreenState();
}

class _RecipeMoreOptionsScreenState extends State<RecipeMoreOptionsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _servingsController;
  late final TextEditingController _regionController;
  late final TextEditingController _sourceController;
  late final TextEditingController _tagsController;
  late String _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _servingsController = TextEditingController(text: widget.servings.toString());
    _regionController = TextEditingController(text: widget.region);
    _sourceController = TextEditingController(text: widget.source);
    _tagsController = TextEditingController(text: widget.tags.join(', '));
    _selectedDifficulty = widget.difficulty;
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _regionController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final parsedServings = int.tryParse(_servingsController.text.trim()) ?? 4;
    final cleanRegion = _regionController.text.trim();
    final cleanSource = _sourceController.text.trim();
    
    final cleanTags = _tagsController.text.isNotEmpty
        ? _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : <String>[];

    final result = MoreOptionsResult(
      servings: parsedServings,
      difficulty: _selectedDifficulty,
      region: cleanRegion,
      source: cleanSource,
      tags: cleanTags,
    );

    Navigator.pop(context, result);
  }

  InputDecoration _buildInputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.caption(
        color: AppColors.textSecondary.withValues(alpha: 0.6),
      ),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textSecondary, size: 20) : null,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          'More Options',
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Help Box
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Refine your dish listing',
                            style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Adding servings, difficulty level, geographic origin, and tags helps users filter and find your recipe on the main search feeds.',
                        style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                // Servings Input
                Text(
                  'Servings',
                  style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _servingsController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('e.g. 4', Icons.group_outlined),
                  style: AppTypography.body(),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final n = int.tryParse(val.trim());
                      if (n == null || n <= 0) {
                        return 'Please enter a valid positive number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Difficulty Dropdown
                Text(
                  'Difficulty Level',
                  style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDifficulty,
                  decoration: _buildInputDecoration('Select difficulty', Icons.star_border_rounded),
                  items: ['Easy', 'Medium', 'Hard'].map((diff) {
                    return DropdownMenuItem(value: diff, child: Text(diff));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDifficulty = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Region Input
                Text(
                  'Origin/Region',
                  style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _regionController,
                  decoration: _buildInputDecoration('e.g. Pampanga, Bicol', Icons.map_outlined),
                  style: AppTypography.body(),
                ),
                const SizedBox(height: 20),

                // Source Input
                Text(
                  'Recipe Source or Link',
                  style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _sourceController,
                  decoration: _buildInputDecoration('e.g. Grandma, website name', Icons.link_rounded),
                  style: AppTypography.body(),
                ),
                const SizedBox(height: 20),

                // Tags Input
                Text(
                  'Tags',
                  style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tagsController,
                  decoration: _buildInputDecoration('Comma-separated (e.g. spicy, soup, dinner)', Icons.tag_rounded),
                  style: AppTypography.body(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
