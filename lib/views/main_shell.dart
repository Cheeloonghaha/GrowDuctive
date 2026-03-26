import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'analytics_view.dart';
import 'calendar_view.dart';
import 'focus_timer_view.dart';
import 'profile_view.dart';
import 'task_view.dart';
import '../widgets/app_sidebar.dart';
import '../navigation/sidebar_drawer_controller.dart';

/// Main shell: bottom nav + body (Calendar, Tasks, Focus, Analytics) + Profile via drawer only.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const Color _navBackground = Color(0xFFEAF3FF); // light blue bar
  static const Color _activeBlue = Color(0xFF103A8A); // selected icon/label
  static const Color _inactiveIcon = Color(0xFF7C93B8);
  static const Color _inactiveLabel = Color(0xFF90A7CC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: SidebarDrawerController.scaffoldKey,
      backgroundColor: AppColors.base,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const CalendarView(),
          const TaskScreen(showBottomNav: false),
          const FocusTimerView(),
          const AnalyticsView(),
          ProfileView(
            onQuit: () => setState(() => _selectedIndex = 0),
          ),
        ],
      ),
      drawer: AppSidebar(
        selectedIndex: _selectedIndex,
        onNavigate: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final showLabels = w >= 340;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: _navBackground,
          borderRadius: BorderRadius.circular(31),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF132A5D).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _navItem(
                Icons.calendar_month_rounded,
                Icons.calendar_month_outlined,
                'Calendar',
                0,
                semanticHint: 'Open calendar',
                showLabels: showLabels,
              ),
            ),
            Expanded(
              child: _navItem(
                Icons.task_alt_rounded,
                Icons.task_alt_outlined,
                'Tasks',
                1,
                semanticHint: 'Open tasks',
                showLabels: showLabels,
              ),
            ),
            Expanded(
              child: _navItem(
                Icons.timer_rounded,
                Icons.timer_outlined,
                'Focus',
                2,
                semanticHint: 'Open focus timer',
                showLabels: showLabels,
              ),
            ),
            Expanded(
              child: _navItem(
                Icons.bar_chart_rounded,
                Icons.bar_chart_outlined,
                'Analytics',
                3,
                semanticHint: 'Open analytics',
                showLabels: showLabels,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData iconSelected,
    IconData iconUnselected,
    String label,
    int index, {
    required bool showLabels,
    String? semanticHint,
  }) {
    final selected = _selectedIndex == index;
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: semanticHint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_selectedIndex != index) {
              HapticFeedback.selectionClick();
            }
            setState(() => _selectedIndex = index);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? iconSelected : iconUnselected,
                  color: selected ? _activeBlue : _inactiveIcon,
                  size: 24,
                ),
                if (selected) ...[
                  const SizedBox(height: 6),
                  // Black border line indicator under the selected icon (matches the reference).
                  Container(
                    height: 3,
                    width: 22,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                if (showLabels) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: narrow ? 9 : 10,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                      color:
                          selected ? _activeBlue : _inactiveLabel,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
