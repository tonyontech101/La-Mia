import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Greeting section matching the wireframe:
/// "Mabuhay, {Username}!"
/// "Ma, anong ulam?"
class GreetingSection extends StatelessWidget {
  const GreetingSection({
    super.key,
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mabuhay, $username!',
          style: AppTypography.display(color: AppColors.textPrimary).copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '"Ma, anong ulam?"',
          style: AppTypography.body(color: AppColors.primary).copyWith(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
