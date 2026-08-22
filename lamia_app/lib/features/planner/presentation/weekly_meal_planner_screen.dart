import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../data/meal_plan_model.dart';
import '../data/meal_plan_repository.dart';

/// Full-featured Weekly Meal Planner Screen for home cooks and meal preppers.
///
/// Features:
/// - 7-day calendar strip (Mon - Sun)
/// - 4 meal slots per day: Almusal, Tanghalian, Hapunan, Meryenda
/// - Recipe picker modal with favorites and category filter
/// - Smart Auto-Fill Week action
/// - Grocery Checklist modal with copy-to-clipboard
class WeeklyMealPlannerScreen extends StatefulWidget {
  const WeeklyMealPlannerScreen({
    super.key,
    this.isGuest = false,
    this.onNavigateHome,
  });

  final bool isGuest;
  final VoidCallback? onNavigateHome;

  @override
  State<WeeklyMealPlannerScreen> createState() =>
      _WeeklyMealPlannerScreenState();
}

class _WeeklyMealPlannerScreenState extends State<WeeklyMealPlannerScreen> {
  final _plannerRepo = MealPlanRepository();
  final _recipeRepo = RecipeRepository();

  late DateTime _currentMonday;
  late DateTime _selectedDayDate;
  WeeklyMealPlanModel? _currentPlan;
  bool _isLoading = true;
  List<RecipeModel> _cachedRecipes = [];

  static String _shortMonth(int month) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? m[month] : '';
  }

  static String _fullMonth(int month) {
    const m = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return (month >= 1 && month <= 12) ? m[month] : '';
  }

  static String _dayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Monday';
      case DateTime.tuesday: return 'Tuesday';
      case DateTime.wednesday: return 'Wednesday';
      case DateTime.thursday: return 'Thursday';
      case DateTime.friday: return 'Friday';
      case DateTime.saturday: return 'Saturday';
      case DateTime.sunday: return 'Sunday';
      default: return 'Day';
    }
  }

  static String _shortDayOfWeek(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Mon';
      case DateTime.tuesday: return 'Tue';
      case DateTime.wednesday: return 'Wed';
      case DateTime.thursday: return 'Thu';
      case DateTime.friday: return 'Fri';
      case DateTime.saturday: return 'Sat';
      case DateTime.sunday: return 'Sun';
      default: return 'Day';
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonday = MealPlanRepository.getMondayOf(now);
    _selectedDayDate = DateTime(now.year, now.month, now.day);
    _loadWeekPlan();
  }

  Future<void> _loadWeekPlan() async {
    setState(() => _isLoading = true);
    try {
      final plan = await _plannerRepo.getWeeklyPlan(_currentMonday);
      if (_cachedRecipes.isEmpty) {
        _cachedRecipes = await _recipeRepo.allRecipes(limit: 200);
      }
      if (mounted) {
        setState(() {
          _currentPlan = plan;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _currentMonday = _currentMonday.add(Duration(days: 7 * deltaWeeks));
      _selectedDayDate = _currentMonday;
    });
    _loadWeekPlan();
  }

  void _resetToThisWeek() {
    final now = DateTime.now();
    final thisMonday = MealPlanRepository.getMondayOf(now);
    if (_currentMonday != thisMonday) {
      setState(() {
        _currentMonday = thisMonday;
        _selectedDayDate = DateTime(now.year, now.month, now.day);
      });
      _loadWeekPlan();
    } else {
      setState(() {
        _selectedDayDate = DateTime(now.year, now.month, now.day);
      });
    }
  }

  String get _selectedDateKey => MealPlanRepository.formatDateKey(_selectedDayDate);

  MealPlanDay get _currentSelectedDay {
    if (_currentPlan == null) {
      return MealPlanDay(
        dateKey: _selectedDateKey,
        dayOfWeek: _dayOfWeek(_selectedDayDate.weekday),
      );
    }
    return _currentPlan!.days[_selectedDateKey] ??
        MealPlanDay(
          dateKey: _selectedDateKey,
          dayOfWeek: _dayOfWeek(_selectedDayDate.weekday),
        );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _openRecipeSelector(String slotTitle, String slotKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipePickerSheet(
        slotTitle: slotTitle,
        allRecipes: _cachedRecipes,
        onRecipeSelected: (recipe) async {
          Navigator.pop(ctx);
          if (_currentPlan == null) return;
          final updated = await _plannerRepo.assignMealSlot(
            currentPlan: _currentPlan!,
            dateKey: _selectedDateKey,
            slot: slotKey,
            recipe: recipe,
          );
          if (mounted) {
            setState(() => _currentPlan = updated);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added "${recipe.name}" to $slotTitle!'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _removeMeal(String slotKey) async {
    if (_currentPlan == null) return;
    final updated = await _plannerRepo.removeMealSlot(
      currentPlan: _currentPlan!,
      dateKey: _selectedDateKey,
      slot: slotKey,
    );
    if (mounted) {
      setState(() => _currentPlan = updated);
    }
  }

  Future<void> _handleAutoFillWeek() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Auto-Fill Week?'),
          ],
        ),
        content: const Text(
          'This will generate a balanced 7-day Filipino meal plan with Breakfast, Lunch, Dinner, and Meryenda.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Generate Plan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final generated = await _plannerRepo.autoFillWeek(_currentMonday);
      if (mounted) {
        setState(() {
          _currentPlan = generated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ 7-Day Meal Plan generated successfully!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openGroceryList() {
    if (_currentPlan == null) return;
    final items = _plannerRepo.generateGroceryList(_currentPlan!);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GroceryListModal(
        items: items,
        weekDateRange: _formatWeekRangeHeader(),
      ),
    );
  }

  String _formatWeekRangeHeader() {
    final sunday = _currentMonday.add(const Duration(days: 6));
    final startFormat = '${_shortMonth(_currentMonday.month)} ${_currentMonday.day}';
    final endFormat = '${_shortMonth(sunday.month)} ${sunday.day}, ${sunday.year}';
    return '$startFormat – $endFormat';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: widget.onNavigateHome != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: widget.onNavigateHome,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Weekly Planner',
              style: AppTypography.title(color: AppColors.textPrimary).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // Grocery list button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
              tooltip: 'Grocery List',
              onPressed: _openGroceryList,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : RefreshIndicator(
              onRefresh: _loadWeekPlan,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Week Selector Banner
                    _buildWeekNavigator(),

                    // 2. 7-Day Horizontal Strip
                    _buildDayStrip(),

                    const SizedBox(height: 16),

                    // 3. Active Day Header & Quick Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildDaySubHeader(),
                    ),

                    const SizedBox(height: 12),

                    // 4. The 4 Meal Slots
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Almusal (Breakfast)
                          _buildMealSlotCard(
                            slotTitle: 'Almusal (Breakfast)',
                            slotSubtitle: 'Morning comfort & energy',
                            slotKey: 'breakfast',
                            icon: Icons.wb_twilight_rounded,
                            accentColor: const Color(0xFFEA580C), // Vivid Orange
                            bgGradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            item: _currentSelectedDay.breakfast,
                          ),

                          const SizedBox(height: 12),

                          // Tanghalian (Lunch)
                          _buildMealSlotCard(
                            slotTitle: 'Tanghalian (Lunch)',
                            slotSubtitle: 'Hearty midday signature ulam',
                            slotKey: 'lunch',
                            icon: Icons.wb_sunny_rounded,
                            accentColor: const Color(0xFFD97706), // Warm Gold
                            bgGradient: const LinearGradient(
                              colors: [Color(0xFFFEFCE8), Color(0xFFFFF7ED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            item: _currentSelectedDay.lunch,
                          ),

                          const SizedBox(height: 12),

                          // Hapunan (Dinner)
                          _buildMealSlotCard(
                            slotTitle: 'Hapunan (Dinner)',
                            slotSubtitle: 'Warm soups & family favorites',
                            slotKey: 'dinner',
                            icon: Icons.nightlight_round,
                            accentColor: const Color(0xFF9333EA), // Purple / Evening
                            bgGradient: const LinearGradient(
                              colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            item: _currentSelectedDay.dinner,
                          ),

                          const SizedBox(height: 12),

                          // Meryenda (Snacks)
                          _buildMealSlotCard(
                            slotTitle: 'Meryenda (Snacks / Dessert)',
                            slotSubtitle: 'Afternoon delight & sweets',
                            slotKey: 'snack',
                            icon: Icons.bakery_dining_rounded,
                            accentColor: const Color(0xFF059669), // Emerald
                            bgGradient: const LinearGradient(
                              colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            item: _currentSelectedDay.snack,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Week Navigator Header ───────────────────────────────────────────────────

  Widget _buildWeekNavigator() {
    final now = DateTime.now();
    final isThisWeek = _currentMonday == MealPlanRepository.getMondayOf(now);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Prev Week
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: () => _changeWeek(-1),
            tooltip: 'Previous Week',
          ),

          // Week Range Display
          GestureDetector(
            onTap: _resetToThisWeek,
            child: Column(
              children: [
                Text(
                  _formatWeekRangeHeader(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isThisWeek
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isThisWeek ? 'Current Week' : 'Tap to jump to This Week',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isThisWeek ? AppColors.primary : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Next Week
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: () => _changeWeek(1),
            tooltip: 'Next Week',
          ),
        ],
      ),
    );
  }

  // ── 7-Day Strip ─────────────────────────────────────────────────────────────

  Widget _buildDayStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(7, (i) {
            final dayDate = _currentMonday.add(Duration(days: i));
            final dateKey = MealPlanRepository.formatDateKey(dayDate);
            final isSelected = dayDate.year == _selectedDayDate.year &&
                dayDate.month == _selectedDayDate.month &&
                dayDate.day == _selectedDayDate.day;

            final dayData = _currentPlan?.days[dateKey];
            final mealsCount = dayData?.totalMealsCount ?? 0;
            final isToday = DateTime.now().year == dayDate.year &&
                DateTime.now().month == dayDate.month &&
                DateTime.now().day == dayDate.day;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: PressableScale(
                onTap: () {
                  setState(() => _selectedDayDate = dayDate);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : const Color(0xFFE5E7EB),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _shortDayOfWeek(dayDate.weekday).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white70 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Meal dots / counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int d = 0; d < 4; d++)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: d < mealsCount
                                    ? (isSelected ? Colors.white : const Color(0xFF16A34A))
                                    : (isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.grey.shade300),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Active Day Subheader & Auto-Fill ────────────────────────────────────────

  Widget _buildDaySubHeader() {
    final dayName = '${_dayOfWeek(_selectedDayDate.weekday)}, ${_fullMonth(_selectedDayDate.month)} ${_selectedDayDate.day}';
    final count = _currentSelectedDay.totalMealsCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count of 4 meals planned',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Smart auto-fill button
        PressableScale(
          onTap: _handleAutoFillWeek,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                SizedBox(width: 5),
                Text(
                  'Auto-Fill Week',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Meal Slot Card ──────────────────────────────────────────────────────────

  Widget _buildMealSlotCard({
    required String slotTitle,
    required String slotSubtitle,
    required String slotKey,
    required IconData icon,
    required Color accentColor,
    required Gradient bgGradient,
    required MealPlanItem? item,
  }) {
    final hasMeal = item != null && item.recipeName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasMeal
              ? accentColor.withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header Slot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  slotTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                if (hasMeal)
                  GestureDetector(
                    onTap: () => _openRecipeSelector(slotTitle, slotKey),
                    child: Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Card Body (Assigned meal OR Add Button)
          Padding(
            padding: const EdgeInsets.all(12),
            child: hasMeal
                ? _buildAssignedMealView(item, slotKey)
                : _buildEmptySlotButton(slotTitle, slotKey, accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedMealView(MealPlanItem item, String slotKey) {
    return Row(
      children: [
        // Recipe image thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.coverPhotoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.coverPhotoUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  ),
                )
              : Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.restaurant, color: Colors.grey),
                ),
        ),

        const SizedBox(width: 12),

        // Info & Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.recipeName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (item.cookTime.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 2),
                    Text(
                      item.cookTime,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  final matched = _cachedRecipes.firstWhere(
                    (r) => r.id == item.recipeId || r.name == item.recipeName,
                    orElse: () => RecipeModel(
                      name: item.recipeName,
                      category: item.category,
                      region: 'Philippines',
                      prepTime: item.prepTime,
                      cookTime: item.cookTime,
                      servings: item.servings,
                      difficulty: 'Easy',
                      ingredients: item.ingredients,
                      instructions: const [],
                      tags: const [],
                      coverPhotoUrl: item.coverPhotoUrl,
                      source: '',
                    ),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(recipe: matched),
                    ),
                  );
                },
                child: const Text(
                  'View Recipe →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Remove button
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
          onPressed: () => _removeMeal(slotKey),
          tooltip: 'Remove from slot',
        ),
      ],
    );
  }

  Widget _buildEmptySlotButton(String slotTitle, String slotKey, Color accentColor) {
    return InkWell(
      onTap: () => _openRecipeSelector(slotTitle, slotKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '+ Add dish to $slotTitle',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recipe Picker Modal Sheet ─────────────────────────────────────────────────

class _RecipePickerSheet extends StatefulWidget {
  const _RecipePickerSheet({
    required this.slotTitle,
    required this.allRecipes,
    required this.onRecipeSelected,
  });

  final String slotTitle;
  final List<RecipeModel> allRecipes;
  final ValueChanged<RecipeModel> onRecipeSelected;

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecipeModel> get _filteredRecipes {
    final query = _searchController.text.toLowerCase().trim();
    return widget.allRecipes.where((recipe) {
      final matchesQuery = query.isEmpty ||
          recipe.name.toLowerCase().contains(query) ||
          recipe.category.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'All' ||
          recipe.category.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Almusal', 'Ulam', 'Meryenda', 'Inihaw', 'Gulay'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Recipe for ${widget.slotTitle}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pick from classic and community Filipino dishes',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search recipe or category...',
                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF374151),
                    ),
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 16, color: Color(0xFFEEEEEE)),

          // Recipe List
          Expanded(
            child: _filteredRecipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text(
                          'No recipes found',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredRecipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final recipe = _filteredRecipes[index];
                      return InkWell(
                        onTap: () => widget.onRecipeSelected(recipe),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: recipe.coverPhotoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: recipe.coverPhotoUrl,
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          width: 58,
                                          height: 58,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.restaurant, color: Colors.grey),
                                        ),
                                      )
                                    : Container(
                                        width: 58,
                                        height: 58,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.restaurant, color: Colors.grey),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${recipe.category} • ${recipe.approximateCookTime}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_rounded,
                                color: AppColors.primary,
                                size: 28,
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

// ── Grocery List Checklist Modal ──────────────────────────────────────────────

class _GroceryListModal extends StatefulWidget {
  const _GroceryListModal({
    required this.items,
    required this.weekDateRange,
  });

  final List<String> items;
  final String weekDateRange;

  @override
  State<_GroceryListModal> createState() => _GroceryListModalState();
}

class _GroceryListModalState extends State<_GroceryListModal> {
  final Set<String> _checkedItems = {};

  void _copyToClipboard() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 La Mia Grocery List (${widget.weekDateRange}):');
    for (final item in widget.items) {
      final check = _checkedItems.contains(item) ? '[x]' : '[ ]';
      buffer.writeln('$check $item');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grocery list copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Weekly Grocery List',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Consolidated ingredients for ${widget.weekDateRange}',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  tooltip: 'Copy all',
                  onPressed: _copyToClipboard,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 16, color: Color(0xFFEEEEEE)),

          // Items Count Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.items.length} Ingredients needed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                Text(
                  '${_checkedItems.length} checked',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Checklist
          Expanded(
            child: widget.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.kitchen_outlined, size: 54, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No meals planned yet for this week.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add dishes to your meal slots to generate a grocery list.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isChecked = _checkedItems.contains(item);
                      return CheckboxListTile(
                        value: isChecked,
                        activeColor: const Color(0xFF16A34A),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 13.5,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked ? Colors.grey.shade400 : const Color(0xFF1F2937),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _checkedItems.add(item);
                            } else {
                              _checkedItems.remove(item);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
