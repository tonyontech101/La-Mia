import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_model.dart';
import 'repository_providers.dart';

/// Real-time stream provider for any user's profile by their [uid].
///
/// Ensures user profile data (e.g. displayName, photoUrl) is streamed,
/// reactive, and cached across the app (Feed cards, Recipe details, Profile).
final userProfileProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  final userRepo = ref.watch(userRepositoryProvider);
  try {
    return userRepo.getUserStream(uid);
  } catch (_) {
    return Stream.fromFuture(userRepo.getUser(uid));
  }
});
