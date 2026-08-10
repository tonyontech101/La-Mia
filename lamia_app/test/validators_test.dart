// Unit tests for the pure validation helpers in `core/utils/validators.dart`.
//
// No widget tree or Firebase is required — every input is a string and every
// output is either `null` (valid) or an error string. This is the cheapest
// coverage to add and protects the most user-visible logic (form feedback).

import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/core/utils/validators.dart';

void main() {
  group('Validators.name', () {
    test('rejects null and empty', () {
      expect(Validators.name(null), 'Please enter your name.');
      expect(Validators.name(''), 'Please enter your name.');
    });

    test('rejects whitespace-only as empty after trim', () {
      expect(Validators.name('   '), 'Please enter your name.');
    });

    test('rejects a single character', () {
      expect(Validators.name('A'), 'Please enter your name.');
    });

    test('accepts two characters', () {
      expect(Validators.name('Al'), isNull);
    });

    test('trims surrounding whitespace before length check', () {
      expect(Validators.name('  Al  '), isNull);
    });

    test('accepts unicode names', () {
      expect(Validators.name('José Rizal'), isNull);
      expect(Validators.name('Juan Dela Cruz'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects null and empty', () {
      expect(Validators.email(null), 'Enter a valid email address.');
      expect(Validators.email(''), 'Enter a valid email address.');
      expect(Validators.email('   '), 'Enter a valid email address.');
    });

    test('rejects malformed addresses', () {
      const invalid = <String>[
        'plainaddress',
        '@no-local.com',
        'missing@domain',
        'spaces in@example.com',
        ' doubles@dot..com',
      ];
      for (final addr in invalid) {
        expect(
          Validators.email(addr),
          'Enter a valid email address.',
          reason: '$addr should be rejected',
        );
      }
    });

    test('accepts well-formed addresses incl. plus-addressing', () {
      const valid = <String>[
        'you@example.com',
        'first.last@sub.example.co.uk',
        'user+tag@gmail.com',
        'user_name@example.com',
        'def!xyz@example.com',
      ];
      for (final addr in valid) {
        expect(Validators.email(addr), isNull, reason: '$addr should be valid');
      }
    });
  });

  group('Validators.loginPassword', () {
    test('rejects null and empty only — content rules deferred to sign-up', () {
      expect(Validators.loginPassword(null), 'Password is required.');
      expect(Validators.loginPassword(''), 'Password is required.');
      // Any non-empty value passes (even weak passwords are accepted at login
      // so the user gets a server-side "wrong-password" instead of a
      // client-side validation block).
      expect(Validators.loginPassword('1'), isNull);
      expect(Validators.loginPassword('weak'), isNull);
    });
  });

  group('Validators.signUpPassword', () {
    test('rejects null and empty', () {
      expect(
        Validators.signUpPassword(null),
        'Password must be at least 8 characters.',
      );
      expect(
        Validators.signUpPassword(''),
        'Password must be at least 8 characters.',
      );
    });

    test('rejects fewer than 8 characters', () {
      expect(
        Validators.signUpPassword('aaa1234'),
        'Password must be at least 8 characters.',
      );
      expect(
        Validators.signUpPassword('abcde6'),
        'Password must be at least 8 characters.',
      );
    });

    test('rejects 8+ chars without a number', () {
      expect(
        Validators.signUpPassword('abcdefgh'),
        'Include at least one letter and one number.',
      );
    });

    test('rejects 8+ chars without a letter', () {
      expect(
        Validators.signUpPassword('12345678'),
        'Include at least one letter and one number.',
      );
    });

    test('accepts 8+ chars with a letter and a number', () {
      expect(Validators.signUpPassword('abcdef12'), isNull);
      expect(Validators.signUpPassword('Password1'), isNull);
      expect(Validators.signUpPassword('aaaaaa1!'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('matches identical strings', () {
      expect(Validators.confirmPassword('abc', 'abc'), isNull);
      expect(Validators.confirmPassword('', ''), isNull);
    });

    test('rejects mismatch', () {
      expect(
        Validators.confirmPassword('abc', 'abd'),
        "Passwords don't match.",
      );
      expect(
        Validators.confirmPassword('abc', ''),
        "Passwords don't match.",
      );
      expect(
        Validators.confirmPassword(null, 'abc'),
        "Passwords don't match.",
      );
    });
  });

  group('estimatePasswordStrength', () {
    test('empty string is empty', () {
      expect(estimatePasswordStrength(''), PasswordStrength.empty);
    });

    test('<8 chars is weak even with letters+numbers', () {
      expect(estimatePasswordStrength('a1'), PasswordStrength.weak);
      expect(estimatePasswordStrength('abc123'), PasswordStrength.weak);
      expect(estimatePasswordStrength('Abc12'), PasswordStrength.weak);
    });

    test('>=8 letters+numbers without symbol/uppercase is okay', () {
      expect(
        estimatePasswordStrength('abcdef12'),
        PasswordStrength.okay,
      );
      expect(
        estimatePasswordStrength('password1'),
        PasswordStrength.okay,
      );
    });

    test('>=10 chars with symbol OR uppercase is strong', () {
      expect(
        estimatePasswordStrength('Password12!'),
        PasswordStrength.strong,
      );
      expect(
        estimatePasswordStrength('aaaabbbb123!'),
        PasswordStrength.strong,
      );
    });

    test('exactly 8 chars with symbol still okay (needs >=10)', () {
      // 8 chars < 10, so even with a symbol this lands at "okay".
      expect(
        estimatePasswordStrength('aabbcc12!'),
        PasswordStrength.okay,
      );
    });
  });

  group('PasswordStrengthX', () {
    test('.label returns expected human strings', () {
      expect(PasswordStrength.empty.label, '');
      expect(PasswordStrength.weak.label, 'Weak');
      expect(PasswordStrength.okay.label, 'Okay');
      expect(PasswordStrength.strong.label, 'Strong');
    });

    test('.segments returns 0..3 as documented', () {
      expect(PasswordStrength.empty.segments, 0);
      expect(PasswordStrength.weak.segments, 1);
      expect(PasswordStrength.okay.segments, 2);
      expect(PasswordStrength.strong.segments, 3);
    });
  });
}