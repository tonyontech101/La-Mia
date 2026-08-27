import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_service.dart';
import 'firebase_providers.dart';

part 'auth_service_provider.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(AuthServiceRef ref) => AuthService(
      auth: ref.watch(firebaseAuthProvider),
      googleSignIn: ref.watch(googleSignInProvider),
      firestore: ref.watch(firebaseFirestoreProvider),
    );
