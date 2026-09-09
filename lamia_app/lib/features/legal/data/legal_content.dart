class LegalSection {
  final String heading;
  final String body;
  final List<String>? bulletPoints;

  const LegalSection({
    required this.heading,
    required this.body,
    this.bulletPoints,
  });
}

class LegalDocument {
  final String title;
  final String effectiveDate;
  final String summary;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.title,
    required this.effectiveDate,
    required this.summary,
    required this.sections,
  });
}

class LegalContent {
  const LegalContent._();

  static const LegalDocument termsOfService = LegalDocument(
    title: 'Terms of Service',
    effectiveDate: 'September 10, 2026',
    summary:
        'Please review these Terms of Service carefully before using La Mia. '
        'By accessing or using our platform, you agree to comply with and be bound by these terms.',
    sections: [
      LegalSection(
        heading: '1. Acceptance of Terms',
        body:
            'Welcome to La Mia ("Discover, Cook, and Share Delicious Recipes"). By accessing or using our mobile application, website, or services, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree, you must cease using the app immediately.',
      ),
      LegalSection(
        heading: '2. Eligibility & Account Security',
        body:
            'You must be at least 13 years of age to register an account or contribute recipes. If under 18, a parent or legal guardian must review and agree to these terms.',
        bulletPoints: [
          'Guest users may browse recipes, search ingredients, and view recommendations without signing up.',
          'Sharing recipes, rating, commenting, and saving favorites requires an account.',
          'You are responsible for safeguarding your login credentials and for all activities under your account.',
        ],
      ),
      LegalSection(
        heading: '3. User-Generated Content & Licensing',
        body:
            'You retain ownership of the culinary content, recipe instructions, and photos you publish on La Mia.',
        bulletPoints: [
          'By uploading content, you grant La Mia a perpetual, worldwide, royalty-free license to display, distribute, index, and promote your recipe within the platform.',
          'You warrant that you hold all rights to your submissions and that they do not infringe any third-party intellectual property or privacy.',
        ],
      ),
      LegalSection(
        heading: '4. Content Moderation & Community Guidelines',
        body:
            'To maintain high culinary standards and community safety, submitted recipes may enter a moderation queue before public display.',
        bulletPoints: [
          'Prohibited: Defamatory, obscene, harassing, or hate speech content.',
          'Prohibited: Commercial spam, duplicate submissions, or fraudulent engagement manipulation.',
          'Users may report objectionable content; recipes exceeding threshold complaints may be temporarily hidden pending review.',
        ],
      ),
      LegalSection(
        heading: '5. Food Safety, Allergen, & Cooking Disclaimers',
        body:
            'All recipes, nutritional advice, cooking durations, and ingredient substitutions on La Mia are provided for informational and culinary entertainment purposes only.',
        bulletPoints: [
          'You are solely responsible for inspecting ingredients for potential food allergens (peanuts, seafood, gluten, dairy, etc.) and personal dietary suitability.',
          'You are responsible for adhering to safe food handling practices, proper kitchen hygiene, and verified internal cooking temperatures.',
          'La Mia disclaims any liability for foodborne illness, adverse allergic reactions, kitchen mishaps, or property damage resulting from recipe preparation.',
          'Suggestions in "Ano Pong Ulam?" and "Cook by Ingredients" are algorithmic guides and do not guarantee taste compatibility or safety.',
        ],
      ),
      LegalSection(
        heading: '6. Intellectual Property',
        body:
            'The La Mia brand, application code, logos, visual designs, icons, and curated collections (excluding user recipes) are the exclusive property of La Mia and protected by Philippine and international copyright laws.',
      ),
      LegalSection(
        heading: '7. Termination of Account',
        body:
            'La Mia reserves the right to suspend or terminate accounts that breach these Terms or disrupt platform safety. You may delete your account at any time via Account Settings.',
      ),
      LegalSection(
        heading: '8. Disclaimer of Warranties & Limitation of Liability',
        body:
            'La Mia is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind. Under no circumstances shall La Mia or its developers be liable for direct, indirect, incidental, or consequential damages resulting from your use of the service.',
      ),
      LegalSection(
        heading: '9. Governing Law',
        body:
            'These Terms shall be governed by and interpreted under the laws of the Republic of the Philippines. Any disputes shall be subject to the jurisdiction of Philippine courts.',
      ),
      LegalSection(
        heading: '10. Contact Us',
        body:
            'For questions regarding these Terms, contact our legal and support team at support@lamia-app.com or visit our team in Nabunturan, Davao de Oro, Philippines.',
      ),
    ],
  );

  static const LegalDocument privacyPolicy = LegalDocument(
    title: 'Privacy Policy',
    effectiveDate: 'September 10, 2026',
    summary:
        'La Mia is committed to safeguarding your privacy in compliance with Republic Act No. 10173 '
        '(Data Privacy Act of 2012 of the Philippines). This document outlines how your data is collected, used, and protected.',
    sections: [
      LegalSection(
        heading: '1. Introduction & Scope',
        body:
            'La Mia ("we", "us", or "our") respects your privacy. This policy governs how we collect, process, and protect your personal information when using the La Mia mobile app and services.',
      ),
      LegalSection(
        heading: '2. Information We Collect',
        body:
            'We collect information directly from you, automatically through app activity, and via third-party authentication.',
        bulletPoints: [
          'Account Details: Display name, email address, hashed password, and optional avatar / bio.',
          'Culinary Content: Recipe titles, ingredients, instructions, cooking times, and photos you upload.',
          'Community Engagement: Star ratings, comments, likes, followed creators, and meal plan schedules.',
          'Device & Technical: Device model, OS version, app version, crash diagnostics, and FCM notification tokens.',
        ],
      ),
      LegalSection(
        heading: '3. Permissions Requested',
        body:
            'La Mia requests permissions only to provide core culinary features:',
        bulletPoints: [
          'Photo Library / Gallery: To choose recipe cover images and profile pictures.',
          'Camera (Optional): To take recipe photos directly within the app.',
          'Push Notifications: To receive meal reminders, recipe updates, and social interaction alerts (customizable in Settings).',
        ],
      ),
      LegalSection(
        heading: '4. How We Use Your Information',
        body:
            'We process personal data for specific and legitimate purposes:',
        bulletPoints: [
          'To authenticate and maintain your user account.',
          'To calculate smart ingredient matches and power "Ano Pong Ulam?" suggestions.',
          'To moderate recipes, enforce community safety, and prevent fraudulent activity.',
          'To dispatch critical account notices and opt-in cooking reminders.',
        ],
      ),
      LegalSection(
        heading: '5. Third-Party Data Processors',
        body:
            'We do not sell or monetize your personal data. We utilize industry-standard cloud infrastructure:',
        bulletPoints: [
          'Google Firebase: Authentication, Cloud Firestore (database), Cloud Storage (media), and Crashlytics (diagnostics).',
          'Google Sign-In: Federated third-party authentication.',
        ],
      ),
      LegalSection(
        heading: '6. Your Data Subject Rights (RA 10173)',
        body:
            'Under the Philippine Data Privacy Act of 2012, you hold specific statutory rights:',
        bulletPoints: [
          'Right to be Informed: Transparent notice of data collection and purpose.',
          'Right to Access: Request details on the personal data we hold about you.',
          'Right to Rectification: Correct inaccurate or outdated profile information anytime.',
          'Right to Erasure or Blocking: Request permanent deletion of your account and personal records.',
          'Right to Object: Opt out of non-essential communications and push notifications.',
          'Right to Lodge a Complaint: File a grievance with the National Privacy Commission (NPC) at privacy.gov.ph.',
        ],
      ),
      LegalSection(
        heading: '7. Data Retention & Deletion',
        body:
            'We retain personal data while your account is active. When you delete your account, credentials and private meal plans are purged. Published recipes may remain publicly visible in an anonymized form to maintain recipe catalogue integrity.',
      ),
      LegalSection(
        heading: '8. Data Security',
        body:
            'We apply organizational and technical security measures including HTTPS/TLS encryption in transit, strict Firebase security rules, and password hashing to safeguard your information.',
      ),
      LegalSection(
        heading: '9. Children\'s Privacy',
        body:
            'La Mia is not directed to children under 13 years of age. We do not knowingly collect personal data from minors under 13 without verified parental consent.',
      ),
      LegalSection(
        heading: '10. Contact & Data Protection Officer',
        body:
            'To exercise your privacy rights or submit questions, contact our Data Protection Team at privacy@lamia-app.com or La Mia App Team, Nabunturan, Davao de Oro, Philippines.',
      ),
    ],
  );
}
