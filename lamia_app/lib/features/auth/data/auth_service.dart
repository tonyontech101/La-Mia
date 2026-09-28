import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_error_messages.dart';
import '../../notifications/services/fcm_service.dart';
import '../../planner/data/meal_plan_repository.dart';

/// Wraps [FirebaseAuth] with app-specific helpers and user-friendly error
/// messages. All auth entry points in the UI go through this service.
///
/// The Firebase singletons are accessed *lazily* (via getters) rather than
/// eagerly in the constructor. This lets the service be instantiated in
/// a widget test environment where Firebase has not yet been initialized —
/// `LoginScreen` simply constructs `AuthService()` for declaration purposes;
/// no Firebase call is made until an auth method is invoked.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _authArg = auth,
       _googleArg = googleSignIn,
       _firestoreArg = firestore,
       _functionsArg = functions;

  final FirebaseAuth? _authArg;
  final GoogleSignIn? _googleArg;
  final FirebaseFirestore? _firestoreArg;
  final FirebaseFunctions? _functionsArg;

  /// Resolves the [FirebaseAuth] instance, preferring an injected one.
  FirebaseAuth get _auth => _authArg ?? FirebaseAuth.instance;

  /// Resolves the [GoogleSignIn] instance, preferring an injected one.
  GoogleSignIn get _googleSignIn => _googleArg ?? GoogleSignIn();

  /// Resolves the [FirebaseFirestore] instance, preferring an injected one.
  FirebaseFirestore get _firestore =>
      _firestoreArg ?? FirebaseFirestore.instance;

  /// Resolves the [FirebaseFunctions] instance, preferring an injected one.
  FirebaseFunctions get _functions =>
      _functionsArg ?? FirebaseFunctions.instance;

  /// The currently signed-in user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// A broadcast stream that emits whenever the auth state changes
  /// (sign in, sign out, token refresh).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email / Password ───────────────────────────────────────────────────

  /// Creates a new account with [email] and [password], then sets the
  /// user's display name to [displayName].
  ///
  /// Firebase Auth automatically signs in the user after creation.
  /// The caller is responsible for any post-creation sign-out or navigation.
  Future<User> createAccountWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Set the profile display name so it's available immediately.
      await credential.user?.updateDisplayName(displayName.trim());
      // Reload so `currentUser.displayName` reflects the update.
      await credential.user?.reload();
      final user = _auth.currentUser;
      if (user == null) throw Exception('Account created but user is null.');
      await _ensureUserDocument(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  /// Signs in with an existing [email] and [password].
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Sign-in succeeded but user is null.');
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────

  /// Initiates the Google Sign-In flow and links the resulting credential
  /// to Firebase Auth.
  Future<User> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Google sign-in succeeded but user is null.');
      }
      await _ensureUserDocument(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' && (e.message?.contains('10') ?? false)) {
        throw Exception(
          'Google Sign-In configuration error (Code 10). Missing SHA-1 fingerprint in Firebase Console.',
        );
      }
      if (e.code == 'sign_in_canceled') {
        throw Exception('Google sign-in was cancelled.');
      }
      throw Exception(e.message ?? 'Google sign-in failed. Please try again.');
    }
  }

  // ── User Document ─────────────────────────────────────────────────────

  /// Creates a Firestore document in the `users` collection for [user] if
  /// one doesn't already exist. Called automatically after sign-up and
  /// first Google sign-in.
  ///
  /// Uses `merge: true` so existing users who re-authenticate don't lose
  /// their accumulated stats (followerCount, recipeCount, etc.).
  Future<void> _ensureUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'displayName': user.displayName ?? 'User',
        'bio': null,
        'photoUrl': user.photoURL,
        'recipeCount': 0,
        'totalLikesReceived': 0,
        'followerCount': 0,
        'followingCount': 0,
        'savedCount': 0,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────

  /// Signs out of both Firebase Auth and Google Sign-In.
  Future<void> signOut() async {
    MealPlanRepository.clearCache();
    try {
      await FCMService.instance.clearTokenOnLogout();
    } catch (_) {}
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // ── Email Verification ────────────────────────────────────────────────

  /// Sends a verification email to the currently signed-in user.
  ///
  /// Uses explicit [ActionCodeSettings] so the verification link always
  /// points to a working Firebase-hosted page, regardless of the
  /// "Email template action URL" configured in the Firebase Console.
  /// Returns the [User] so callers can inspect `emailVerified` immediately.
  Future<User?> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }
    try {
      await user.sendEmailVerification(
        ActionCodeSettings(
          // Point to the Firebase-hosted project page so the link always
          // resolves, even if the Console "Action URL" is left blank.
          url: Uri.https('${_auth.app.options.projectId}.web.app').toString(),
          handleCodeInApp: false,
          iOSBundleId: 'com.lamia.lamiaApp',
          androidPackageName: 'com.lamia.lamia_app',
        ),
      );
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  /// Sends a 6-digit verification code to [targetEmail] (or current user's email)
  /// for the specified [purpose] ('signup', 'change_password', 'change_email').
  Future<void> sendEmailOtp({
    required String purpose,
    String? targetEmail,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendEmailOtp');
      await callable.call({
        'purpose': purpose,
        if (targetEmail != null && targetEmail.isNotEmpty)
          'targetEmail': targetEmail.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to send verification code.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to send verification code: $e');
    }
  }

  /// Verifies the 6-digit [code] for [purpose] ('signup', 'change_password', 'change_email').
  ///
  /// On successful signup/change_email verification, reloads the user so
  /// [isEmailVerified] and [User.email] reflect the updated Firebase state.
  Future<bool> verifyEmailOtp({
    required String code,
    required String purpose,
    String? newEmail,
    String? targetEmail,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final result = await callable.call({
        'code': code.trim(),
        'purpose': purpose,
        if (newEmail != null && newEmail.isNotEmpty)
          'newEmail': newEmail.trim(),
        if (targetEmail != null && targetEmail.isNotEmpty)
          'targetEmail': targetEmail.trim(),
      });

      // Reload user to sync updated Firebase Auth state (e.g. emailVerified = true)
      await reloadUser();

      final data = result.data;
      if (data is Map) {
        return data['success'] == true;
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Invalid verification code.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Verification failed: $e');
    }
  }

  /// Verifies the OTP code for a new signup, creates the account in Firebase Auth
  /// with emailVerified: true on the backend, signs in locally, and ensures the
  /// Firestore user document is created.
  Future<User> verifyOtpAndCreateAccount({
    required String code,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final result = await callable.call({
        'code': code.trim(),
        'purpose': 'signup',
        'email': email.trim(),
        'password': password,
        'displayName': displayName.trim(),
      });

      final data = result.data;
      if (data is! Map || data['success'] != true) {
        throw Exception('Verification failed.');
      }

      // Account was created on server with emailVerified = true.
      // Sign in locally with the credentials.
      final user = await signInWithEmail(
        email: email.trim(),
        password: password,
      );

      // Ensure Firestore user document exists
      await _ensureUserDocument(user);
      return user;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Invalid verification code.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Verification failed: $e');
    }
  }

  /// Reloads the current user from Firebase to refresh cached properties
  /// such as [User.emailVerified].
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Whether the current user has verified their email address.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ── Sensitive Operations (Reauthentication) ─────────────────────────────

  /// Reauthenticates the current user with [email] and [password].
  ///
  /// Firebase requires a recent login for sensitive operations like
  /// changing a password or email. This method reauthenticates the user
  /// so the subsequent sensitive operation can proceed.
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  /// Changes the current user's password to [newPassword].
  ///
  /// The user must have been recently authenticated (via [reauthenticateWithEmail])
  /// before calling this method, otherwise Firebase will throw
  /// `requires-recent-login`.
  Future<void> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');
      await user.updatePassword(newPassword);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  /// Sends a verification email to the current user, then updates their
  /// email to [newEmail] once verified.
  ///
  /// Uses Firebase's `verifyBeforeUpdateEmail` which sends a verification
  /// link to [newEmail]. The email is only changed after the user clicks
  /// the link. The user must be recently authenticated.
  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user is currently signed in.');
      // Reauthenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      // Send verification to new email
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }

  // ── Password Reset ─────────────────────────────────────────────────────

  /// Sends a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(AuthErrorMessages.fromCode(e.code));
    }
  }
}
