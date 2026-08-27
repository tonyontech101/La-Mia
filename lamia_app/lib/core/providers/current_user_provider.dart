import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/user_model.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

part 'current_user_provider.g.dart';

/// The currently authenticated Firebase [User] (or null).
@Riverpod(keepAlive: true)
Stream<fb_auth.User?> authStateChanges(AuthStateChangesRef ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
}

/// The current user's Firebase UID, synchronized with the latest auth state.
@Riverpod(keepAlive: true)
String? currentUserId(CurrentUserIdRef ref) {
  return ref.watch(authStateChangesProvider).valueOrNull?.uid;
}

/// The [UserModel] profile for the current user.
///
/// Returns `null` when no user is signed in, or while the Firestore profile
/// document is still loading. Listens reactively so profile edits in another
/// screen are picked up automatically.
@Riverpod(keepAlive: true)
Stream<UserModel?> currentUserProfile(CurrentUserProfileRef ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.getUserStream(userId);
}
