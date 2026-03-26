import 'package:flutter/material.dart';

/// Floating speed dial: two secondary actions sit tight around the main FAB (left + above).
class CalendarSpeedDial extends StatelessWidget {
  const CalendarSpeedDial({
    super.key,
    required this.open,
    required this.onToggle,
    required this.onAddTask,
    required this.onGenerate,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAddTask;
  final VoidCallback onGenerate;

  static const double _mainSize = 56;
  static const double _miniSize = 48;

  /// Insets for each mini FAB's bottom-right corner; ~6px gap from main (56px) circle.
  /// [0] = left of main (same vertical center), [1] = directly above (same horizontal center).
  static const List<({double right, double bottom, Offset closedSlide})> _miniLayout = [
    (right: 62, bottom: 4, closedSlide: Offset(0.2, 0.05)),
    (right: 4, bottom: 62, closedSlide: Offset(0.05, 0.2)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fabBorder = BorderSide(
      color: scheme.surface.withValues(alpha: 0.45),
      width: 1.2,
    );

    return SizedBox(
      width: 118,
      height: 124,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomRight,
        children: [
          for (var i = 0; i < 2; i++)
            _DialAction(
              open: open,
              staggerIndex: i,
              right: _miniLayout[i].right,
              bottom: _miniLayout[i].bottom,
              closedSlide: _miniLayout[i].closedSlide,
              backgroundColor: i == 0
                  ? scheme.secondaryContainer
                  : scheme.primaryContainer,
              foregroundColor: i == 0
                  ? scheme.onSecondaryContainer
                  : scheme.onPrimaryContainer,
              icon: i == 0 ? Icons.add_task : Icons.auto_awesome,
              tooltip: i == 0 ? 'Add task' : 'Generate schedule',
              onTap: i == 0 ? onAddTask : onGenerate,
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              width: _mainSize,
              height: _mainSize,
              child: FloatingActionButton(
                heroTag: 'calendar_speed_dial_main',
                elevation: 6,
                onPressed: onToggle,
                tooltip: open ? 'Close' : 'Calendar actions',
                backgroundColor: scheme.onSurface,
                shape: CircleBorder(side: fabBorder),
                child: Icon(
                  open ? Icons.close : Icons.edit_calendar_rounded,
                  color: scheme.surface,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialAction extends StatelessWidget {
  const _DialAction({
    required this.open,
    required this.staggerIndex,
    required this.right,
    required this.bottom,
    required this.closedSlide,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool open;
  final int staggerIndex;
  final double right;
  final double bottom;
  final Offset closedSlide;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fabBorder = BorderSide(
      color: scheme.surface.withValues(alpha: 0.45),
      width: 1.0,
    );
    return Positioned(
      right: right,
      bottom: bottom,
        child: AnimatedSlide(
          duration: Duration(milliseconds: 220 + staggerIndex * 45),
          curve: Curves.easeOutBack,
          offset: open ? Offset.zero : closedSlide,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 160 + staggerIndex * 30),
          opacity: open ? 1 : 0,
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !open,
            child: Tooltip(
              message: tooltip,
              child: Material(
                elevation: 5,
                shadowColor: Colors.black26,
                shape: CircleBorder(side: fabBorder),
                color: backgroundColor,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    width: CalendarSpeedDial._miniSize,
                    height: CalendarSpeedDial._miniSize,
                    child: Icon(icon, color: foregroundColor, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
