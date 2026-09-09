import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/app/theme/app_colors.dart';
import 'package:lamia_app/features/profile/presentation/achievements_screen.dart';
import 'package:lamia_app/features/profile/presentation/edit_profile_screen.dart';
import 'package:lamia_app/features/profile/presentation/notifiers/edit_profile_notifier.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final unlockedBadge1 = AchievementItem(
    id: 'first_recipe',
    title: 'First Sizzle',
    description: 'Share your first recipe.',
    icon: Icons.soup_kitchen_rounded,
    category: 'Culinary',
    xpReward: 50,
    currentProgress: 1,
    maxProgress: 1,
    isUnlocked: true,
    badgeColor: AppColors.primary,
  );

  final unlockedBadge2 = AchievementItem(
    id: 'home_cook',
    title: 'Home Cook',
    description: 'Share 5 recipes with the community.',
    icon: Icons.menu_book_rounded,
    category: 'Culinary',
    xpReward: 120,
    currentProgress: 5,
    maxProgress: 5,
    isUnlocked: true,
    badgeColor: const Color(0xFF8B5CF6),
  );

  final lockedBadge = AchievementItem(
    id: 'legacy_cook',
    title: 'Legacy Cook',
    description: 'Share 100 recipes with the community.',
    icon: Icons.auto_stories_rounded,
    category: 'Culinary',
    xpReward: 1500,
    currentProgress: 5,
    maxProgress: 100,
    isUnlocked: false,
    badgeColor: AppColors.accent,
  );

  group('ShowcaseBadgeSection Widget Tests', () {
    testWidgets('Displays only acquired (unlocked) badges and hides locked badges', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcaseBadgeSection(
                achievements: [unlockedBadge1, unlockedBadge2, lockedBadge],
                selectedId: null,
                onSelected: (_) {},
                currentUserModel: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should display unlocked badges
      expect(find.text('First Sizzle'), findsOneWidget);
      expect(find.text('Home Cook'), findsOneWidget);

      // Should NOT display locked badges
      expect(find.text('Legacy Cook'), findsNothing);

      // Filter chips like "All (3)" or "Locked (1)" should not exist
      expect(find.textContaining('Locked'), findsNothing);
    });

    testWidgets('Equips an unequipped badge when tapping card or Equip button', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcaseBadgeSection(
                achievements: [unlockedBadge1, unlockedBadge2],
                selectedId: null,
                onSelected: (id) => selected = id,
                currentUserModel: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on the First Sizzle badge to equip
      await tester.tap(find.text('First Sizzle'));
      expect(selected, 'first_recipe');
    });

    testWidgets('Unequips an equipped badge when tapping the equipped card or Unequip button', (tester) async {
      String? selected = 'first_recipe';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShowcaseBadgeSection(
                achievements: [unlockedBadge1, unlockedBadge2],
                selectedId: 'first_recipe',
                onSelected: (id) => selected = id,
                currentUserModel: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should show Unequip button on the equipped badge card
      expect(find.text('Unequip'), findsWidgets);

      // Tapping the equipped badge card in the list should unequip
      await tester.tap(find.text('First Sizzle').last);
      expect(selected, isNull);

      // Tapping the Unequip button should also unequip
      selected = 'first_recipe';
      await tester.tap(find.text('Unequip').first);
      expect(selected, isNull);
    });
  });

  group('EditProfileNotifier toggle/unequip tests', () {
    test('selectAchievement with current id deselects / unequips', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(editProfileNotifierProvider.notifier);
      notifier.selectAchievement('first_recipe');
      expect(container.read(editProfileNotifierProvider).selectedAchievementId, 'first_recipe');

      // Selecting the same id again toggles it off (unequips)
      notifier.selectAchievement('first_recipe');
      expect(container.read(editProfileNotifierProvider).selectedAchievementId, isNull);
    });
  });
}
