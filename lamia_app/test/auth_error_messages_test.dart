// Unit tests for `AuthErrorMessages.fromCode`.
//
// Validates all 11 mapped codes return the expected human copy and that
// unrecognized codes fall through to a non-crashing default that contains
// the raw code (so support can diagnose without leaking it to users as a
// bare stack trace).

import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/auth/data/auth_error_messages.dart';

void main() {
  group('AuthErrorMessages.fromCode', () {
    const mapped = <String, String>{
      'email-already-in-use':
          'An account with this email already exists. Try logging in instead.',
      'invalid-email': 'The email address is not valid.',
      'user-disabled':
          'This account has been disabled. Contact support for help.',
      'user-not-found':
          'No account found with this email. Check your spelling or sign up.',
      'wrong-password':
          'Incorrect password. Please try again or reset your password.',
      'invalid-credential': 'Incorrect email or password. Please try again.',
      'weak-password':
          'Password is too weak. Please choose a stronger password.',
      'operation-not-allowed':
          'This sign-in method is not enabled. Contact support.',
      'too-many-requests':
          'Too many attempts. Please wait a moment and try again.',
      'network-request-failed':
          'Network error. Check your connection and try again.',
      'account-exists-with-different-credential':
          'An account already exists with a different sign-in method.',
    };

    test(
      'maps every documented Firebase Auth code to its expected message',
      () {
        for (final entry in mapped.entries) {
          expect(
            AuthErrorMessages.fromCode(entry.key),
            entry.value,
            reason: '${entry.key} should map to the documented message',
          );
        }
      },
    );

    test('includes the raw code in the default branch for diagnostics', () {
      final result = AuthErrorMessages.fromCode('some-unmapped-firebase-code');
      expect(result, contains('Something went wrong.'));
      expect(result, contains('(some-unmapped-firebase-code)'));
    });

    test('falls back gracefully for an empty code string', () {
      final result = AuthErrorMessages.fromCode('');
      // Still some default message and still includes the (empty) code;
      // the function must not throw or return null.
      expect(result, isNotNull);
      expect(result, contains('Something went wrong.'));
    });

    test('is deterministic — same code yields identical output', () {
      const code = 'wrong-password';
      expect(
        AuthErrorMessages.fromCode(code),
        AuthErrorMessages.fromCode(code),
      );
    });
  });
}
