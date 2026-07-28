/// Spacing scale (4pt base) and corner radii from the design system.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Horizontal screen padding.
  static const double screenH = 24;

  /// Max content width on tablets / large screens (single column, centered).
  static const double contentMaxWidth = 440;
}

/// Corner radii tokens.
abstract final class AppRadii {
  static const double field = 14;
  static const double button = 14;
  static const double card = 24; // top corners of the floating card
  static const double snackbar = 12;
  static const double checkbox = 6;
  static const double pill = 999;
}
