/// Public, testable mapping from Firebase Auth error codes to user-facing
/// messages.
///
/// Extracted out of `AuthService._friendlyMessage` so the error-mapping
/// logic can be unit-tested in isolation without instantiating
/// `AuthService` (which requires a `FirebaseAuth` instance).
abstract final class AuthErrorMessages {
  /// Converts a Firebase Auth error code into a user-friendly message.
  ///
  /// Returns a generic fallback (including the raw code) for any code the
  /// La Mia auth flow doesn't explicitly handle.
  static String fromCode(String code) {
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
      'invalid-credential' => 'Incorrect email or password. Please try again.',
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
      'requires-recent-login' =>
        'This action requires a recent login. Please sign out and sign back in.',
      'user-mismatch' =>
        'The credentials do not match the currently signed-in user.',
      'user-not-found' =>
        'No user found with these credentials.',
      'invalid-password' =>
        'The password is incorrect. Please try again.',
      _ => 'Something went wrong. Please try again. ($code)',
    };
  }
}
