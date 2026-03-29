import 'package:flutter/material.dart';

import '../models/user_preferences_model.dart';

String _weekdayNameForSemantics(int weekday) {
  const names = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
}

/// Short weekday labels (Mon … Sun) matching Dart [DateTime.weekday] order.
String weekdayShortLabel(int weekday) {
  const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[weekday - 1];
}

/// Horizontal row of seven days: weekday abbrev, day number, scheduled task count, week nav.
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.onDaySelected,
    required this.onWeekShift,
    required this.taskCountsForWeek,
  }) : assert(taskCountsForWeek.length == 7);

  final DateTime weekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  /// -1 = previous week, +1 = next week (moves [selectedDate] by ±7 days).
  final ValueChanged<int> onWeekShift;

  /// Scheduled task count per day, aligned with [weekStart] … [weekStart + 6 days].
  final List<int> taskCountsForWeek;

  /// First day of the calendar week that contains [date].
  static DateTime weekStartContaining(DateTime date, int weekStartsOn) {
    final d = DateTime(date.year, date.month, date.day);
    if (weekStartsOn == UserPreferencesModel.weekSunday) {
      final daysBack = d.weekday == DateTime.sunday ? 0 : d.weekday;
      return d.subtract(Duration(days: daysBack));
    }
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    const navButtonSize = 52.0;
    const navIconSize = 30.0;

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(
            minWidth: navButtonSize,
            minHeight: navButtonSize,
          ),
          iconSize: navIconSize,
          icon: Icon(
            Icons.chevron_left,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
          onPressed: () => onWeekShift(-1),
          tooltip: 'Previous week',
        ),
        Expanded(
          child: Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final selected = _sameDay(day, selectedDate);
              final muted = scheme.onSurface.withValues(alpha: 0.45);
              final primary = scheme.onSurface;
              final taskCount = taskCountsForWeek[i];
              final labelStyle = theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: selected ? primary : muted,
                height: 1,
              );

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onDaySelected(day),
                    borderRadius: BorderRadius.circular(12),
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label:
                          '${_weekdayNameForSemantics(day.weekday)}, ${day.day}, $taskCount scheduled tasks',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              weekdayShortLabel(day.weekday),
                              style: labelStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 17,
                                color: selected ? primary : muted,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$taskCount',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: taskCount > 0
                                    ? primary
                                    : muted.withValues(alpha: 0.55),
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              height: 3,
                              width: selected ? 22 : 0,
                              decoration: BoxDecoration(
                                color: selected ? primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(
            minWidth: navButtonSize,
            minHeight: navButtonSize,
          ),
          iconSize: navIconSize,
          icon: Icon(
            Icons.chevron_right,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
          onPressed: () => onWeekShift(1),
          tooltip: 'Next week',
        ),
      ],
    );
  }
}
