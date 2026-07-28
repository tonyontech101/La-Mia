/// Pure validation helpers for the auth forms.
///
/// Each returns `null` when valid, or a user-facing error string otherwise —
/// matching the copy defined in the UI/UX spec.
abstract final class Validators {
  // A pragmatic email pattern: something@something.tld
  static final RegExp _emailRegExp = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
  );

  static final RegExp _hasLetter = RegExp(r'[A-Za-z]');
  static final RegExp _hasNumber = RegExp(r'\d');

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || v.length < 2) return 'Please enter your name.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a valid email address.';
    if (!_emailRegExp.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Login password: presence only (rules enforced at sign-up).
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required.';
    return null;
  }

  /// Sign-up password: min 8 chars, at least one letter and one number.
  static String? signUpPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty || v.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!_hasLetter.hasMatch(v) || !_hasNumber.hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '') != original) return "Passwords don't match.";
    return null;
  }
}

/// Strength buckets for the sign-up password meter.
enum PasswordStrength { empty, weak, okay, strong }

extension PasswordStrengthX on PasswordStrength {
  String get label => switch (this) {
        PasswordStrength.empty => '',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.okay => 'Okay',
        PasswordStrength.strong => 'Strong',
      };

  /// Number of filled segments in the 3-segment meter.
  int get segments => switch (this) {
        PasswordStrength.empty => 0,
        PasswordStrength.weak => 1,
        PasswordStrength.okay => 2,
        PasswordStrength.strong => 3,
      };
}

/// Estimates password strength using the same thresholds as the spec:
/// weak (<8), okay (>=8 w/ letters+numbers), strong (>=10 w/ +symbol/upper).
PasswordStrength estimatePasswordStrength(String value) {
  if (value.isEmpty) return PasswordStrength.empty;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
  final hasNumber = RegExp(r'\d').hasMatch(value);
  final hasSymbolOrUpper = RegExp(r'[A-Z]|[^\w\s]').hasMatch(value);

  if (value.length < 8 || !hasLetter || !hasNumber) {
    return PasswordStrength.weak;
  }
  if (value.length >= 10 && hasSymbolOrUpper) {
    return PasswordStrength.strong;
  }
  return PasswordStrength.okay;
}
