import 'package:flutter/material.dart';

/// GrowDuctive design tokens — calm base, cool interactive, warm accents.
abstract final class AppColors {
  /// Base (60%) — warm stone background
  static const Color base = Color(0xFFF5F5F7);

  /// Card surface — slightly lifted from base
  static const Color surface = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE8E8ED);

  /// Secondary (30%) — cool blue interactive
  static const Color interactive = Color(0xFF4A90E2);
  static const Color interactiveDark = Color(0xFF3A7BC8);

  /// Jade alternative for success / focus accents
  static const Color jade = Color(0xFF00A86B);

  /// Accent (10%) — urgent / highlights
  static const Color softGold = Color(0xFFF5A623);
  static const Color coral = Color(0xFFFF6B6B);

  /// Floating bottom nav pill background
  static const Color navBarFloating = Color(0xFFF0F0F3);

  /// Glass overlay tints
  static Color glassFill = Colors.white.withValues(alpha: 0.78);
  static Color glassBorder = Colors.white.withValues(alpha: 0.55);

  /// Pastel category chip backgrounds (rotate by hash)
  static const List<Color> categoryPastels = [
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFFF3E0),
    Color(0xFFF3E5F5),
    Color(0xFFE0F7FA),
    Color(0xFFFCE4EC),
    Color(0xFFF1F8E9),
    Color(0xFFE8EAF6),
  ];

  static Color categoryPastelFor(String categoryId) {
    if (categoryId.isEmpty) return categoryPastels[0];
    var h = 0;
    for (final u in categoryId.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return categoryPastels[h % categoryPastels.length];
  }

  static Color categoryOnPastel(String categoryId) {
    return Colors.black87;
  }
}
