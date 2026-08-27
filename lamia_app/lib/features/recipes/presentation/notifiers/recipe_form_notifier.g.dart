// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_form_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recipeFormNotifierHash() =>
    r'a39341023af39943064688ce38905e9d6e7d9fae';

/// Manages the recipe creation / edit form state.
///
/// Holds every form field value, the selected cover image, and step
/// navigation. Provides validation and submission logic so the widget
/// layer only renders UI and reacts to results.
///
/// The notifier intentionally has **no** `BuildContext` or UI imports.
///
/// Copied from [RecipeFormNotifier].
@ProviderFor(RecipeFormNotifier)
final recipeFormNotifierProvider =
    AutoDisposeNotifierProvider<RecipeFormNotifier, RecipeFormState>.internal(
      RecipeFormNotifier.new,
      name: r'recipeFormNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recipeFormNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecipeFormNotifier = AutoDisposeNotifier<RecipeFormState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
