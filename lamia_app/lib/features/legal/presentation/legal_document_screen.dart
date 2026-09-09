import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../data/legal_content.dart';

/// A reader screen displaying legal policies such as Terms of Service or Privacy Policy.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.document,
  });

  factory LegalDocumentScreen.termsOfService({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      document: LegalContent.termsOfService,
    );
  }

  factory LegalDocumentScreen.privacyPolicy({Key? key}) {
    return LegalDocumentScreen(
      key: key,
      document: LegalContent.privacyPolicy,
    );
  }

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.contentMaxWidth,
            ),
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH - 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document.title,
                          style: AppTypography.headline(
                            color: AppColors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Document Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                      vertical: 12,
                    ),
                    children: [
                      // Header Card with effective date badge and summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Effective: ${document.effectiveDate}',
                                style: AppTypography.caption(
                                  color: AppColors.textPrimary,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              document.summary,
                              style: AppTypography.body(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sections
                      ...document.sections.map((section) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.heading,
                                style: AppTypography.body(
                                  color: AppColors.primary,
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                section.body,
                                style: AppTypography.body(
                                  color: AppColors.textPrimary,
                                ).copyWith(fontSize: 13.5, height: 1.5),
                              ),
                              if (section.bulletPoints != null &&
                                  section.bulletPoints!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ...section.bulletPoints!.map((bullet) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            bullet,
                                            style: AppTypography.body(
                                              color: AppColors.textPrimary,
                                            ).copyWith(
                                              fontSize: 13,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          '© 2026 La Mia App. All rights reserved.',
                          style: AppTypography.caption(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
