import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../recipes/data/recipe_category_model.dart';

/// Categories section matching image.png wireframe:
/// Header ("Categories")
/// Horizontal scrollable category pill cards.
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    this.onCategoryTap,
  });

  final List<RecipeCategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<RecipeCategoryModel>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat.id == selectedCategoryId;
              return _CategoryItem(
                category: cat,
                isSelected: isSelected,
                onTap: () => onCategoryTap?.call(cat),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.isSelected,
    this.onTap,
  });

  final RecipeCategoryModel category;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.92,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            // Tile fades between idle and selected with a springy icon pop.
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.field),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.cardShadow,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    category.icon,
                    color: isSelected ? Colors.white : AppColors.primary,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              style:
                  AppTypography.caption(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ).copyWith(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
              child: Text(category.name.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
