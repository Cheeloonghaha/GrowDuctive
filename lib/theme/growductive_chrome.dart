import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand “chrome” colors (headers, bottom nav, segment pills) that are not covered
/// by [ColorScheme] alone. Registered on both light and dark [ThemeData].
@immutable
class GrowductiveChrome extends ThemeExtension<GrowductiveChrome> {
  const GrowductiveChrome({
    required this.scaffoldBackground,
    required this.headerBar,
    required this.navBlue,
    required this.menuCircleBg,
    required this.headerShadow,
    required this.segmentOuter,
    required this.segmentSelectedFill,
    required this.segmentBorder,
    required this.bottomNavBackground,
    required this.bottomNavActive,
    required this.bottomNavInactiveIcon,
    required this.bottomNavInactiveLabel,
  });

  final Color scaffoldBackground;
  final Color headerBar;
  final Color navBlue;
  final Color menuCircleBg;
  final Color headerShadow;
  final Color segmentOuter;
  final Color segmentSelectedFill;
  final Color segmentBorder;
  final Color bottomNavBackground;
  final Color bottomNavActive;
  final Color bottomNavInactiveIcon;
  final Color bottomNavInactiveLabel;

  static const light = GrowductiveChrome(
    scaffoldBackground: AppColors.base,
    headerBar: Color(0xFFEAF3FF),
    navBlue: Color(0xFF103A8A),
    menuCircleBg: Color(0xFF0F2E5C),
    headerShadow: Color(0xFF132A5D),
    segmentOuter: Color(0xFFD6E6FF),
    segmentSelectedFill: Color(0xFFEAF3FF),
    segmentBorder: Color(0xFFB6D3FF),
    bottomNavBackground: Color(0xFFEAF3FF),
    bottomNavActive: Color(0xFF103A8A),
    bottomNavInactiveIcon: Color(0xFF7C93B8),
    bottomNavInactiveLabel: Color(0xFF90A7CC),
  );

  static const dark = GrowductiveChrome(
    scaffoldBackground: Color(0xFF0E1117),
    headerBar: Color(0xFF1A2332),
    navBlue: Color(0xFFB8D4FF),
    menuCircleBg: Color(0xFF0F2E5C),
    headerShadow: Color(0xFF000000),
    segmentOuter: Color(0xFF2A3544),
    segmentSelectedFill: Color(0xFF243041),
    segmentBorder: Color(0xFF3D5270),
    bottomNavBackground: Color(0xFF1A2332),
    bottomNavActive: Color(0xFF9EBFFF),
    bottomNavInactiveIcon: Color(0xFF7C8FA8),
    bottomNavInactiveLabel: Color(0xFF8B9CB8),
  );

  @override
  GrowductiveChrome copyWith({
    Color? scaffoldBackground,
    Color? headerBar,
    Color? navBlue,
    Color? menuCircleBg,
    Color? headerShadow,
    Color? segmentOuter,
    Color? segmentSelectedFill,
    Color? segmentBorder,
    Color? bottomNavBackground,
    Color? bottomNavActive,
    Color? bottomNavInactiveIcon,
    Color? bottomNavInactiveLabel,
  }) {
    return GrowductiveChrome(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      headerBar: headerBar ?? this.headerBar,
      navBlue: navBlue ?? this.navBlue,
      menuCircleBg: menuCircleBg ?? this.menuCircleBg,
      headerShadow: headerShadow ?? this.headerShadow,
      segmentOuter: segmentOuter ?? this.segmentOuter,
      segmentSelectedFill: segmentSelectedFill ?? this.segmentSelectedFill,
      segmentBorder: segmentBorder ?? this.segmentBorder,
      bottomNavBackground: bottomNavBackground ?? this.bottomNavBackground,
      bottomNavActive: bottomNavActive ?? this.bottomNavActive,
      bottomNavInactiveIcon: bottomNavInactiveIcon ?? this.bottomNavInactiveIcon,
      bottomNavInactiveLabel: bottomNavInactiveLabel ?? this.bottomNavInactiveLabel,
    );
  }

  @override
  GrowductiveChrome lerp(ThemeExtension<GrowductiveChrome>? other, double t) {
    if (other is! GrowductiveChrome) return this;
    return GrowductiveChrome(
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      headerBar: Color.lerp(headerBar, other.headerBar, t)!,
      navBlue: Color.lerp(navBlue, other.navBlue, t)!,
      menuCircleBg: Color.lerp(menuCircleBg, other.menuCircleBg, t)!,
      headerShadow: Color.lerp(headerShadow, other.headerShadow, t)!,
      segmentOuter: Color.lerp(segmentOuter, other.segmentOuter, t)!,
      segmentSelectedFill:
          Color.lerp(segmentSelectedFill, other.segmentSelectedFill, t)!,
      segmentBorder: Color.lerp(segmentBorder, other.segmentBorder, t)!,
      bottomNavBackground:
          Color.lerp(bottomNavBackground, other.bottomNavBackground, t)!,
      bottomNavActive: Color.lerp(bottomNavActive, other.bottomNavActive, t)!,
      bottomNavInactiveIcon:
          Color.lerp(bottomNavInactiveIcon, other.bottomNavInactiveIcon, t)!,
      bottomNavInactiveLabel:
          Color.lerp(bottomNavInactiveLabel, other.bottomNavInactiveLabel, t)!,
    );
  }
}

extension GrowductiveChromeContext on BuildContext {
  GrowductiveChrome get chrome =>
      Theme.of(this).extension<GrowductiveChrome>() ?? GrowductiveChrome.light;
}
