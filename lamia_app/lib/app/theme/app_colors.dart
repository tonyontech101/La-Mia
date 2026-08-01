import 'package:flutter/material.dart';

/// La Mia color tokens.
///
/// Palette blends warm "appetite" tones (terracotta, amber, toasted browns)
/// with a single royal-blue accent borrowed from the Philippine flag for
/// trust/actions. Values come directly from the approved UI/UX design system.
abstract final class AppColors {
  // Brand / action
  static const Color primary = Color(0xFFC4462B); // Terracotta
  static const Color primaryDark = Color(0xFF9E3220); // Pressed
  static const Color primaryDisabled = Color(0xFFE3B8AE);
  static const Color secondary = Color(0xFF1B3B8B); // Royal blue (flag)
  static const Color accent = Color(0xFFF2A03D); // Warm amber (sun)
  static const Color accentSoft = Color(0xFFFBE7C9); // Amber tint

  // Surfaces
  static const Color background = Color(0xFFFBF6EF); // Warm cream
  static const Color surface = Color(0xFFFFFDFA); // Card white (warm)
  static const Color surfaceAlt = Color(0xFFF3ECE1); // Input fill

  // Feedback
  static const Color error = Color(0xFFC0392B);
  static const Color success = Color(0xFF3E8E5A); // Calamansi green

  // Text
  static const Color textPrimary = Color(0xFF2B211B); // Toasted brown-black
  static const Color textSecondary = Color(0xFF6E6259); // Warm taupe
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Lines
  static const Color border = Color(0xFFE4D9C9);
  static const Color borderFocus = primary;

  /// Vertical scrim painted over the hero photo so white text stays legible.
  /// Transparent at top, melting into a strong dark base at the bottom.
  static const List<Color> heroScrim = <Color>[
    Color(0x00120800), // transparent
    Color(0x47130800), // ~0.28 alpha
    Color(0xDB0F0703), // ~0.86 alpha
  ];
  static const List<double> heroScrimStops = <double>[0.0, 0.55, 1.0];

  /// Subtle warm multiply overlay that unifies the photo with the palette.
  static const Color heroWarmOverlay = Color(0x1AC4462B); // ~0.10 alpha

  // Card Gradients & Overlays
  static const LinearGradient cookCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC4462B),
      Color(0xFF8C2C19),
    ],
  );

  static const LinearGradient ulamCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B3B8B),
      Color(0xFF0F2356),
    ],
  );

  static const Color glassOverlay = Color(0x26FFFFFF);
  static const Color cardShadow = Color(0x122B211B);
}
