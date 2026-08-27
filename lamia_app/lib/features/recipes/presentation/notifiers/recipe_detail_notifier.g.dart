// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_detail_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recipeDetailNotifierHash() =>
    r'27c2a790731c5f1da252f098a85bb6b135319c02';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$RecipeDetailNotifier
    extends BuildlessAutoDisposeNotifier<RecipeDetailState> {
  late final RecipeModel recipe;

  RecipeDetailState build(RecipeModel recipe);
}

/// Notifier managing social + planner state for the recipe detail screen.
///
/// Accepts the initial [RecipeModel] via the [build] parameter and
/// exposes imperative methods for like / bookmark / follow / rate.
/// All UI feedback (snackbars, context) is the caller's responsibility.
///
/// Copied from [RecipeDetailNotifier].
@ProviderFor(RecipeDetailNotifier)
const recipeDetailNotifierProvider = RecipeDetailNotifierFamily();

/// Notifier managing social + planner state for the recipe detail screen.
///
/// Accepts the initial [RecipeModel] via the [build] parameter and
/// exposes imperative methods for like / bookmark / follow / rate.
/// All UI feedback (snackbars, context) is the caller's responsibility.
///
/// Copied from [RecipeDetailNotifier].
class RecipeDetailNotifierFamily extends Family<RecipeDetailState> {
  /// Notifier managing social + planner state for the recipe detail screen.
  ///
  /// Accepts the initial [RecipeModel] via the [build] parameter and
  /// exposes imperative methods for like / bookmark / follow / rate.
  /// All UI feedback (snackbars, context) is the caller's responsibility.
  ///
  /// Copied from [RecipeDetailNotifier].
  const RecipeDetailNotifierFamily();

  /// Notifier managing social + planner state for the recipe detail screen.
  ///
  /// Accepts the initial [RecipeModel] via the [build] parameter and
  /// exposes imperative methods for like / bookmark / follow / rate.
  /// All UI feedback (snackbars, context) is the caller's responsibility.
  ///
  /// Copied from [RecipeDetailNotifier].
  RecipeDetailNotifierProvider call(RecipeModel recipe) {
    return RecipeDetailNotifierProvider(recipe);
  }

  @override
  RecipeDetailNotifierProvider getProviderOverride(
    covariant RecipeDetailNotifierProvider provider,
  ) {
    return call(provider.recipe);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'recipeDetailNotifierProvider';
}

/// Notifier managing social + planner state for the recipe detail screen.
///
/// Accepts the initial [RecipeModel] via the [build] parameter and
/// exposes imperative methods for like / bookmark / follow / rate.
/// All UI feedback (snackbars, context) is the caller's responsibility.
///
/// Copied from [RecipeDetailNotifier].
class RecipeDetailNotifierProvider
    extends
        AutoDisposeNotifierProviderImpl<
          RecipeDetailNotifier,
          RecipeDetailState
        > {
  /// Notifier managing social + planner state for the recipe detail screen.
  ///
  /// Accepts the initial [RecipeModel] via the [build] parameter and
  /// exposes imperative methods for like / bookmark / follow / rate.
  /// All UI feedback (snackbars, context) is the caller's responsibility.
  ///
  /// Copied from [RecipeDetailNotifier].
  RecipeDetailNotifierProvider(RecipeModel recipe)
    : this._internal(
        () => RecipeDetailNotifier()..recipe = recipe,
        from: recipeDetailNotifierProvider,
        name: r'recipeDetailNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$recipeDetailNotifierHash,
        dependencies: RecipeDetailNotifierFamily._dependencies,
        allTransitiveDependencies:
            RecipeDetailNotifierFamily._allTransitiveDependencies,
        recipe: recipe,
      );

  RecipeDetailNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.recipe,
  }) : super.internal();

  final RecipeModel recipe;

  @override
  RecipeDetailState runNotifierBuild(covariant RecipeDetailNotifier notifier) {
    return notifier.build(recipe);
  }

  @override
  Override overrideWith(RecipeDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: RecipeDetailNotifierProvider._internal(
        () => create()..recipe = recipe,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        recipe: recipe,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<RecipeDetailNotifier, RecipeDetailState>
  createElement() {
    return _RecipeDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecipeDetailNotifierProvider && other.recipe == recipe;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, recipe.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RecipeDetailNotifierRef
    on AutoDisposeNotifierProviderRef<RecipeDetailState> {
  /// The parameter `recipe` of this provider.
  RecipeModel get recipe;
}

class _RecipeDetailNotifierProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          RecipeDetailNotifier,
          RecipeDetailState
        >
    with RecipeDetailNotifierRef {
  _RecipeDetailNotifierProviderElement(super.provider);

  @override
  RecipeModel get recipe => (origin as RecipeDetailNotifierProvider).recipe;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
