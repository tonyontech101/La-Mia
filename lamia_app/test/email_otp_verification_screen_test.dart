// ignore_for_file: subtype_of_sealed_class, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/core/providers/auth_service_provider.dart';
import 'package:lamia_app/features/auth/data/auth_service.dart';
import 'package:lamia_app/features/auth/presentation/email_otp_verification_screen.dart';
import 'package:lamia_app/features/auth/presentation/widgets/otp_pin_input.dart';

class MockAuthService extends AuthService {
  MockAuthService({this.onSendOtp, this.onVerifyOtp});

  final Future<void> Function(String purpose, String? targetEmail)? onSendOtp;
  final Future<bool> Function(String code, String purpose, String? newEmail)? onVerifyOtp;

  @override
  Future<void> sendEmailOtp({required String purpose, String? targetEmail}) async {
    if (onSendOtp != null) {
      await onSendOtp!(purpose, targetEmail);
    }
  }

  @override
  Future<bool> verifyEmailOtp({
    required String code,
    required String purpose,
    String? newEmail,
  }) async {
    if (onVerifyOtp != null) {
      return await onVerifyOtp!(code, purpose, newEmail);
    }
    return true;
  }
}

void main() {
  group('EmailOtpVerificationScreen Widget Tests', () {
    testWidgets('renders title, email, and OtpPinInput', (tester) async {
      final mockAuth = MockAuthService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuth),
          ],
          child: const MaterialApp(
            home: EmailOtpVerificationScreen(
              purpose: 'signup',
              targetEmail: 'chefanita@example.com',
            ),
          ),
        ),
      );

      // Verify headline & target email
      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('chefanita@example.com'), findsOneWidget);

      // Verify OtpPinInput exists
      expect(find.byType(OtpPinInput), findsOneWidget);

      // Verify resend cooldown message
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('entering code automatically triggers verifyEmailOtp', (tester) async {
      String verifiedCode = '';
      final mockAuth = MockAuthService(
        onVerifyOtp: (code, purpose, newEmail) async {
          verifiedCode = code;
          return true;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuth),
          ],
          child: const MaterialApp(
            home: EmailOtpVerificationScreen(
              purpose: 'signup',
              targetEmail: 'chefanita@example.com',
            ),
          ),
        ),
      );

      // Enter 6 digits directly in the TextField
      await tester.enterText(find.byType(TextField), '987654');
      await tester.pump();

      expect(verifiedCode, '987654');
    });
  });
}
