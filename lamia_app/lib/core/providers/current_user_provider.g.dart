// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_user_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authStateChangesHash() => r'e01a64c0509d6f9cf0416aa0f1bb4441b8ea8616';

/// The currently authenticated Firebase [User] (or null).
///
/// Copied from [authStateChanges].
@ProviderFor(authStateChanges)
final authStateChangesProvider = StreamProvider<fb_auth.User?>.internal(
  authStateChanges,
  name: r'authStateChangesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authStateChangesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateChangesRef = StreamProviderRef<fb_auth.User?>;
String _$currentUserIdHash() => r'0d7853cd5451b3ddf7b793a86108b8ebfbda3e51';

/// The current user's Firebase UID, synchronized with the latest auth state.
///
/// Copied from [currentUserId].
@ProviderFor(currentUserId)
final currentUserIdProvider = Provider<String?>.internal(
  currentUserId,
  name: r'currentUserIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserIdRef = ProviderRef<String?>;
String _$currentUserProfileHash() =>
    r'52dff69abd5d3896e283e3b9e6a6de78a261e04e';

/// The [UserModel] profile for the current user.
///
/// Returns `null` when no user is signed in, or while the Firestore profile
/// document is still loading. Listens reactively so profile edits in another
/// screen are picked up automatically.
///
/// Copied from [currentUserProfile].
@ProviderFor(currentUserProfile)
final currentUserProfileProvider = StreamProvider<UserModel?>.internal(
  currentUserProfile,
  name: r'currentUserProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserProfileRef = StreamProviderRef<UserModel?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
