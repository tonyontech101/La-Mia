// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_plan_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$weeklyPlanNotifierHash() =>
    r'366adc8de5ff4df34b1d3e271a48feac094d67db';

/// Manages the weekly meal plan lifecycle: loading, stream subscription,
/// week navigation, slot CRUD, auto-fill, and grocery list generation.
///
/// The screen owns only UI concerns (dialogs, snackbars, navigation).
///
/// Copied from [WeeklyPlanNotifier].
@ProviderFor(WeeklyPlanNotifier)
final weeklyPlanNotifierProvider =
    AutoDisposeNotifierProvider<WeeklyPlanNotifier, WeeklyPlanState>.internal(
      WeeklyPlanNotifier.new,
      name: r'weeklyPlanNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$weeklyPlanNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WeeklyPlanNotifier = AutoDisposeNotifier<WeeklyPlanState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
