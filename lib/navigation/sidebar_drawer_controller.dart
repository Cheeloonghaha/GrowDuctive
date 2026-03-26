import 'package:flutter/material.dart';

/// Global controller for opening the app sidebar drawer.
///
/// Pages like `TaskScreen` and `CalendarView` each create their own `Scaffold`,
/// so calling `Scaffold.of(context).openDrawer()` would open the *wrong*
/// scaffold. Instead we open the drawer that lives in `MainShell` via this key.
class SidebarDrawerController {
  SidebarDrawerController._();

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();
}

