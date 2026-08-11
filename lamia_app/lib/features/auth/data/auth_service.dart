import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps [FirebaseAuth] with app-specific helpers and user-friendly error
/// messages. All auth entry points in the UI go through this service.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

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
      throw Exception(_friendlyMessage(e.code));
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
      throw Exception(_friendlyMessage(e.code));
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
      throw Exception(_friendlyMessage(e.code));
    }
  }

  // ── User Document ─────────────────────────────────────────────────────

  /// Creates a Firestore document in the `users` collection for [user] if
  /// one doesn't already exist. Called automatically after sign-up and
  /// first Google sign-in.
  Future<void> _ensureUserDocument(User user) async {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'displayName': user.displayName ?? 'User',
        'bio': null,
        'photoUrl': user.photoURL,
        'recipeCount': 0,
        'totalLikesReceived': 0,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Sign Out ───────────────────────────────────────────────────────────

  /// Signs out of both Firebase Auth and Google Sign-In.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
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
      throw Exception(_friendlyMessage(e.code));
    }
  }

  /// Reloads the current user from Firebase to refresh cached properties
  /// such as [User.emailVerified].
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Whether the current user has verified their email address.
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // ── Password Reset ─────────────────────────────────────────────────────

  /// Sends a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyMessage(e.code));
    }
  }

  // ── Error mapping ──────────────────────────────────────────────────────

  /// Converts Firebase Auth error codes into user-friendly messages.
  static String _friendlyMessage(String code) {
    return switch (code) {
      'email-already-in-use' =>
        'An account with this email already exists. Try logging in instead.',
      'invalid-email' => 'The email address is not valid.',
      'user-disabled' =>
        'This account has been disabled. Contact support for help.',
      'user-not-found' =>
        'No account found with this email. Check your spelling or sign up.',
      'wrong-password' =>
        'Incorrect password. Please try again or reset your password.',
      'invalid-credential' =>
        'Incorrect email or password. Please try again.',
      'weak-password' =>
        'Password is too weak. Please choose a stronger password.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled. Contact support.',
      'too-many-requests' =>
        'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      'account-exists-with-different-credential' =>
        'An account already exists with a different sign-in method.',
      _ => 'Something went wrong. Please try again. ($code)',
    };
  }
}
