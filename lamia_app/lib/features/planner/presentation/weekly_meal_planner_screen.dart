import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../recipes/data/recipe_model.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/presentation/recipe_detail_screen.dart';
import '../data/meal_plan_model.dart';
import '../data/meal_plan_repository.dart';

// ── Banig Weave Divider ─────────────────────────────────────────────────────

class BanigDivider extends StatelessWidget {
  const BanigDivider({super.key, this.height = 14, this.opacity = 0.45});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _BanigWeavePainter(opacity: opacity),
      ),
    );
  }
}

class _BanigWeavePainter extends CustomPainter {
  const _BanigWeavePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppColors.border.withValues(alpha: opacity)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final knotPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.fill;

    const cellW = 6.0;
    const cellH = 5.0;
    final cols = (size.width / cellW).ceil();

    for (var row = 0; row < 2; row++) {
      final y = row * cellH;
      for (var col = 0; col < cols; col++) {
        final x = col * cellW;
        final rect = Rect.fromLTWH(x, y, cellW, cellH);
        canvas.drawRect(rect, strokePaint);

        if (col % 4 == 0 && row == (col ~/ 4) % 2) {
          canvas.drawCircle(
            Offset(x + cellW / 2, y + cellH / 2),
            1.2,
            knotPaint,
          );
        }
      }
    }

    canvas.drawLine(
      Offset(0, cellH),
      Offset(size.width, cellH),
      Paint()
        ..color = AppColors.border.withValues(alpha: opacity * 0.7)
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BanigWeavePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

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
                content: Text('"${recipe.name}" added to $slotTitle.'),
                duration: const Duration(seconds: 2),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        title: Text(
          'Auto-Fill Week?',
          style: AppTypography.title(color: AppColors.textPrimary),
        ),
        content: Text(
          'We\'ll suggest a Filipino week \u2014 Almusal, Tanghalian, Hapunan, and Meryenda for all 7 days. Swap any dish after.',
          style: AppTypography.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTypography.label(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Suggest week',
              style: AppTypography.button(color: AppColors.onPrimary),
            ),
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
            content: Text('Week filled in.'),
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
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: widget.onNavigateHome != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: widget.onNavigateHome,
              )
            : null,
        title: Text(
          'Weekly Planner',
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.textPrimary),
              tooltip: 'Grocery List',
              onPressed: _openGroceryList,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadWeekPlan,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeekNavigator(),
                    const BanigDivider(),
                    _buildDayStrip(),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                      child: _buildDaySubHeader(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                      child: Column(
                        children: [
                          _buildMealSlotCard(
                            slotTitle: 'Almusal',
                            slotSubtitle: 'Breakfast',
                            slotKey: 'breakfast',
                            icon: Icons.wb_twilight_rounded,
                            item: _currentSelectedDay.breakfast,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildMealSlotCard(
                            slotTitle: 'Tanghalian',
                            slotSubtitle: 'Lunch',
                            slotKey: 'lunch',
                            icon: Icons.wb_sunny_rounded,
                            item: _currentSelectedDay.lunch,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildMealSlotCard(
                            slotTitle: 'Hapunan',
                            slotSubtitle: 'Dinner',
                            slotKey: 'dinner',
                            icon: Icons.nightlight_round,
                            item: _currentSelectedDay.dinner,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildMealSlotCard(
                            slotTitle: 'Meryenda',
                            slotSubtitle: 'Snack',
                            slotKey: 'snack',
                            icon: Icons.bakery_dining_rounded,
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
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.textPrimary),
            onPressed: () => _changeWeek(-1),
            tooltip: 'Previous Week',
          ),
          GestureDetector(
            onTap: _resetToThisWeek,
            child: Column(
              children: [
                Text(
                  _formatWeekRangeHeader(),
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: isThisWeek ? AppColors.accentSoft : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    isThisWeek ? 'This week' : 'Back to this week',
                    style: AppTypography.caption(
                      color: isThisWeek ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28, color: AppColors.textPrimary),
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
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _shortDayOfWeek(dayDate.weekday).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: isSelected ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${dayDate.day}',
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
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
                                    ? (isSelected ? Colors.white : AppColors.primary)
                                    : (isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : AppColors.border),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayName,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '$count of 4 meals planned',
                style: AppTypography.label(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _handleAutoFillWeek,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs + 1),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Suggest week',
                  style: AppTypography.label(color: AppColors.primary),
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
    required MealPlanItem? item,
  }) {
    final hasMeal = item != null && item.recipeName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  slotTitle,
                  style: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  slotSubtitle,
                  style: AppTypography.caption(color: AppColors.textSecondary),
                ),
                const Spacer(),
                if (hasMeal)
                  GestureDetector(
                    onTap: () => _openRecipeSelector('$slotTitle ($slotSubtitle)', slotKey),
                    child: Text(
                      'Change',
                      style: AppTypography.caption(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: hasMeal
                ? _buildAssignedMealView(item, slotKey)
                : _buildEmptySlotButton('$slotTitle ($slotSubtitle)', slotKey),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedMealView(MealPlanItem item, String slotKey) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.field),
          child: item.coverPhotoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.coverPhotoUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.surfaceAlt,
                    child: const Icon(Icons.restaurant, color: AppColors.textDisabled),
                  ),
                )
              : Container(
                  width: 64,
                  height: 64,
                  color: AppColors.surfaceAlt,
                  child: const Icon(Icons.restaurant, color: AppColors.textDisabled),
                ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.recipeName,
                style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Text(
                    item.category,
                    style: AppTypography.caption(color: AppColors.textSecondary),
                  ),
                  if (item.cookTime.isNotEmpty)
                    Text(
                      ' \u00B7 ${item.cookTime}',
                      style: AppTypography.caption(color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
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
                child: Text(
                  'View recipe \u2192',
                  style: AppTypography.label(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _removeMeal(slotKey),
          child: Text(
            'Remove',
            style: AppTypography.caption(color: AppColors.textDisabled),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySlotButton(String slotTitle, String slotKey) {
    return InkWell(
      onTap: () => _openRecipeSelector(slotTitle, slotKey),
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Add dish',
              style: AppTypography.label(color: AppColors.textSecondary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Recipe for ${widget.slotTitle}',
                        style: GoogleFonts.fraunces(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Pick from classic and community Filipino dishes',
                        style: AppTypography.caption(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: AppTypography.body(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search recipe or category...',
                hintStyle: AppTypography.body(color: AppColors.textDisabled),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xxs),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: AppTypography.caption(
                      color: isSelected ? AppColors.onPrimary : AppColors.textPrimary,
                    ),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 16, color: AppColors.border),

          Expanded(
            child: _filteredRecipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: AppColors.textDisabled),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'No recipes match',
                          style: AppTypography.label(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    itemCount: _filteredRecipes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final recipe = _filteredRecipes[index];
                      return InkWell(
                        onTap: () => widget.onRecipeSelected(recipe),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadii.field),
                                child: recipe.coverPhotoUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: recipe.coverPhotoUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => Container(
                                          width: 52,
                                          height: 52,
                                          color: AppColors.surfaceAlt,
                                          child: const Icon(Icons.restaurant, color: AppColors.textDisabled),
                                        ),
                                      )
                                    : Container(
                                        width: 52,
                                        height: 52,
                                        color: AppColors.surfaceAlt,
                                        child: const Icon(Icons.restaurant, color: AppColors.textDisabled),
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.name,
                                      style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      '${recipe.category} \u00B7 ${recipe.approximateCookTime}',
                                      style: AppTypography.caption(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.add_circle_rounded,
                                color: AppColors.primary,
                                size: 26,
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
    buffer.writeln('La Mia grocery list \u2014 ${widget.weekDateRange}:');
    for (final item in widget.items) {
      final check = _checkedItems.contains(item) ? '[x]' : '[ ]';
      buffer.writeln('$check $item');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grocery list copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Grocery List',
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Everything you need for ${widget.weekDateRange}',
                        style: AppTypography.caption(color: AppColors.textSecondary),
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
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 16, color: AppColors.border),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.items.length} ingredients',
                  style: AppTypography.label(color: AppColors.textPrimary),
                ),
                Text(
                  '${_checkedItems.length} in the cart',
                  style: AppTypography.caption(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          Expanded(
            child: widget.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.kitchen_outlined, size: 48, color: AppColors.textDisabled),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No meals this week yet.',
                          style: AppTypography.label(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Add dishes to see the ingredients here.',
                          style: AppTypography.caption(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isChecked = _checkedItems.contains(item);
                      return CheckboxListTile(
                        value: isChecked,
                        activeColor: AppColors.success,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          item,
                          style: AppTypography.body(
                            color: isChecked ? AppColors.textDisabled : AppColors.textPrimary,
                          ).copyWith(
                            decoration: isChecked ? TextDecoration.lineThrough : null,
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
