/// Layout and motion tokens shared across the app.
/// Dark theme will reuse the same scale later.
abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadii {
  static const double xs = 10;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 25;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 280);
}

/// Insets for `Stack` + `Positioned` FABs (calendar speed dial, task add button).
abstract final class FabLayout {
  static const double edge = 16;
}
