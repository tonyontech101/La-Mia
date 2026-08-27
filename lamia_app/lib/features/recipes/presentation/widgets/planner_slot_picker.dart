import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../planner/data/meal_plan_model.dart';
import '../../../planner/data/meal_plan_repository.dart';
import '../../../recipes/data/recipe_model.dart';

/// Add-to-Planner Day + Slot Picker bottom sheet widget.
class PlannerSlotPicker extends StatefulWidget {
  const PlannerSlotPicker({
    super.key,
    required this.recipe,
    required this.plannerRepo,
  });

  final RecipeModel recipe;
  final MealPlanRepository plannerRepo;

  @override
  State<PlannerSlotPicker> createState() => _PlannerSlotPickerState();
}

class _PlannerSlotPickerState extends State<PlannerSlotPicker> {
  late DateTime _selectedDay;
  WeeklyMealPlanModel? _plan;
  bool _isLoading = true;

  static String _shortDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return 'Day';
    }
  }

  static String _dayLabel(String slotKey) {
    switch (slotKey) {
      case 'breakfast':
        return 'Almusal';
      case 'lunch':
        return 'Tanghalian';
      case 'dinner':
        return 'Hapunan';
      case 'snack':
        return 'Meryenda';
      default:
        return slotKey;
    }
  }

  static String _glossLabel(String slotKey) {
    switch (slotKey) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return slotKey;
    }
  }

  static IconData _slotIcon(String slotKey) {
    switch (slotKey) {
      case 'breakfast':
        return Icons.wb_twilight_rounded;
      case 'lunch':
        return Icons.wb_sunny_rounded;
      case 'dinner':
        return Icons.nightlight_round;
      case 'snack':
        return Icons.bakery_dining_rounded;
      default:
        return Icons.restaurant;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    setState(() => _isLoading = true);
    final monday = MealPlanRepository.getMondayOf(_selectedDay);
    final plan = await widget.plannerRepo.getWeeklyPlan(monday);
    if (mounted) {
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
    }
  }

  String get _dateKey => MealPlanRepository.formatDateKey(_selectedDay);

  MealPlanDay get _selectedDayData =>
      _plan?.days[_dateKey] ?? MealPlanDay(dateKey: _dateKey, dayOfWeek: '');

  MealPlanItem? _slotItem(String slot) {
    switch (slot) {
      case 'breakfast':
        return _selectedDayData.breakfast;
      case 'lunch':
        return _selectedDayData.lunch;
      case 'dinner':
        return _selectedDayData.dinner;
      case 'snack':
        return _selectedDayData.snack;
      default:
        return null;
    }
  }

  Future<void> _assignToSlot(String slot) async {
    if (_plan == null) return;
    final updated = await widget.plannerRepo.assignMealSlot(
      currentPlan: _plan!,
      dateKey: _dateKey,
      slot: slot,
      recipe: widget.recipe,
    );
    if (mounted) {
      setState(() => _plan = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.recipe.name} added to ${_dayLabel(slot)}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monday = MealPlanRepository.getMondayOf(_selectedDay);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 0, AppSpacing.screenH, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to planner',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.recipe.name,
                  style: AppTypography.caption(
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Day strip
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              itemCount: 7,
              itemBuilder: (_, i) {
                final dayDate = monday.add(Duration(days: i));
                final isSelected = dayDate.year == _selectedDay.year &&
                    dayDate.month == _selectedDay.month &&
                    dayDate.day == _selectedDay.day;
                final isToday = DateTime.now().year == dayDate.year &&
                    DateTime.now().month == dayDate.month &&
                    DateTime.now().day == dayDate.day;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedDay = dayDate);
                      _loadWeek();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 54,
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(
                            AppRadii.field),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isToday
                                  ? AppColors.primary
                                      .withValues(alpha: 0.4)
                                  : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _shortDay(dayDate.weekday).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${dayDate.day}',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Slots
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm),
                    itemCount: 4,
                    separatorBuilder: (_, _) => const Divider(
                        height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final slotKey = [
                        'breakfast',
                        'lunch',
                        'dinner',
                        'snack'
                      ][i];
                      final item = _slotItem(slotKey);
                      final isFilled =
                          item != null && item.recipeName.isNotEmpty;
                      return InkWell(
                        onTap: () => _assignToSlot(slotKey),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          child: Row(
                            children: [
                              Icon(_slotIcon(slotKey),
                                  color: AppColors.textSecondary,
                                  size: 18),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _dayLabel(slotKey),
                                      style: GoogleFonts.fraunces(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(
                                        height: AppSpacing.xxs),
                                    Text(
                                      _glossLabel(slotKey),
                                      style:
                                          AppTypography.caption(
                                              color: AppColors
                                                  .textSecondary),
                                    ),
                                    if (isFilled) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.recipeName,
                                        style: AppTypography.caption(
                                            color: AppColors
                                                .textDisabled),
                                        overflow:
                                            TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!isFilled)
                                const Icon(Icons.add_rounded,
                                    color: AppColors.primary,
                                    size: 22)
                              else
                                Text(
                                  'Replace',
                                  style: AppTypography.caption(
                                      color: AppColors.primary),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
