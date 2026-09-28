import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/auth/presentation/widgets/otp_pin_input.dart';

void main() {
  group('OtpPinInput Widget Tests', () {
    testWidgets('renders 6 boxes by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpPinInput(
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      // Verify 6 cells
      expect(find.byType(AnimatedContainer), findsNWidgets(6));
    });

    testWidgets('entering 6 digits triggers onCompleted', (tester) async {
      String completedCode = '';
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpPinInput(
              controller: controller,
              onCompleted: (code) {
                completedCode = code;
              },
            ),
          ),
        ),
      );

      // Enter digits
      controller.text = '654321';
      await tester.pumpAndSettle();

      expect(completedCode, '654321');
      expect(find.text('6'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
