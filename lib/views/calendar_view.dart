import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/task_viewmodel.dart';
import '../viewmodels/scheduled_task_viewmodel.dart';
import '../viewmodels/user_preferences_viewmodel.dart';
import '../models/user_preferences_model.dart';
import '../models/task_model.dart';
import '../models/scheduled_task_model.dart';
import '../models/category_model.dart';
import '../services/smart_schedule_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/calendar_speed_dial.dart';
import '../widgets/calendar_week_strip.dart';
import '../widgets/schedule_preview_dialog.dart';
import '../navigation/sidebar_drawer_controller.dart';

/// Calendar view: day timeline + week strip; date picker for jumping dates.
/// Tap-to-schedule: tap a time slot → pick task → create ScheduledTask.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

/// Drag mode for scheduled task: move whole block, resize from top, or resize from bottom.
enum _DragMode { move, resizeTop, resizeBottom }

class _CalendarViewState extends State<CalendarView> {
  DateTime _selectedDate = DateTime.now();
  DateTime _lastObservedDateOnly = DateTime.now();
  Timer? _dateTicker;
  bool _userSelectedDate = false;
  bool _calendarFabOpen = false;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _autoBackfillInFlight = <String>{};

  /// After "Remove from calendar", skip backfill for this task/date so we don't recreate.
  final Set<String> _removedFromCalendarKeys = <String>{};

  /// Drag state for adjusting scheduled task time
  String? _draggingScheduledTaskId;
  double _dragDeltaY = 0;
  _DragMode? _dragMode;
  int _dragOriginalStart = 0;
  int _dragOriginalEnd = 0;
  bool _didDragToAdjustTime = false;

  static const int _dayStartHour = 0; // Midnight (00:00)
  static const int _dayEndHour = 24; // Next midnight (24:00)
  static const int _slotHeight = 60;
  static const int _defaultScrollHour = 6; // Default scroll position: 6am
  static const int _snapMinutes = 15;
  static const int _minDurationMinutes = 15;

  /// Preset reminder offsets (minutes before start); custom values are shown as extra chips.
  static const Set<int> _presetReminderOffsets = {5, 10, 15, 30, 60, 1440};

  int _snapTo(int minutes, int step) {
    final remainder = minutes % step;
    if (remainder == 0) return minutes;
    return minutes + (remainder < step / 2 ? -remainder : step - remainder);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _lastObservedDateOnly = _selectedDate;

    // Keep the calendar "Today" in sync with the device date if the app stays open.
    // If the user manually selects a date, we stop auto-updating.
    _dateTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_userSelectedDate) return;
      final n = DateTime.now();
      final todayOnly = DateTime(n.year, n.month, n.day);
      if (!_isSameDay(_selectedDate, todayOnly)) {
        if (!mounted) return;
        setState(() {
          _selectedDate = todayOnly;
          _lastObservedDateOnly = todayOnly;
        });
      } else {
        _lastObservedDateOnly = todayOnly;
      }
    });

    // Scroll to 6am after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDefaultPosition();
    });
  }

  @override
  void dispose() {
    _dateTicker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDefaultPosition() {
    if (_scrollController.hasClients) {
      // Scroll to 6am: (6 hours * 60 minutes) / 60 * slotHeight
      final scrollPosition = (_defaultScrollHour - _dayStartHour) * _slotHeight;
      _scrollController.animateTo(
        scrollPosition.toDouble(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onDateChanged(DateTime newDate) {
    final dateOnly = DateTime(newDate.year, newDate.month, newDate.day);
    setState(() {
      _selectedDate = dateOnly;
      _userSelectedDate = true;
    });
    // Scroll to 6am when date changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDefaultPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = Provider.of<TaskViewModel>(context, listen: false);
    final scheduledVM = Provider.of<ScheduledTaskViewModel>(
      context,
      listen: false,
    );

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    const fabEdge = FabLayout.edge;
    const navBlue = Color(0xFF103A8A); // darker blue used in header
    const navBg = Color(0xFFEAF3FF);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Scaffold(
          backgroundColor: AppColors.base,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(scheduledVM),
                const SizedBox(height: 10),
                _buildWeekStrip(scheduledVM),
                Expanded(child: _buildDailyView(context, taskVM, scheduledVM)),
              ],
            ),
          ),
        ),
        if (_calendarFabOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _calendarFabOpen = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
            ),
          ),
        Positioned(
          right: fabEdge,
          bottom: fabEdge + bottomPad,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    onSurface: navBlue,
                    primary: navBlue,
                    surface: navBg,
                  ),
            ),
            child: CalendarSpeedDial(
              open: _calendarFabOpen,
              onToggle: () =>
                  setState(() => _calendarFabOpen = !_calendarFabOpen),
              onAddTask: () {
                setState(() => _calendarFabOpen = false);
                _showAddTaskDialog(context, taskVM, scheduledVM);
              },
              onGenerate: () {
                setState(() => _calendarFabOpen = false);
                _showGenerateScheduleOptions(taskVM, scheduledVM);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(ScheduledTaskViewModel scheduledVM) {
    final prefsVM = Provider.of<UserPreferencesViewModel>(
      context,
      listen: false,
    );

    const navBlue = Color(0xFF103A8A);

    return StreamBuilder<UserPreferencesModel?>(
      stream: prefsVM.preferencesStream,
      builder: (context, snap) {
        final weekStartsOn =
            snap.data?.weekStartsOn ?? UserPreferencesModel.weekMonday;
        final weekStart = CalendarWeekStrip.weekStartContaining(
          _selectedDate,
          weekStartsOn,
        );

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  onSurface: navBlue,
                  primary: navBlue,
                ),
          ),
          child: Container(
            color: AppColors.base,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FutureBuilder<Map<DateTime, List<ScheduledTaskModel>>>(
              key: ValueKey(
                '${weekStart.year}-${weekStart.month}-${weekStart.day}',
              ),
              future: scheduledVM.fetchScheduledTasksForRange(
                weekStart,
                weekStart.add(const Duration(days: 6)),
              ),
              builder: (context, countSnap) {
                final map = countSnap.data ?? {};
                final counts = List.generate(7, (i) {
                  final d = weekStart.add(Duration(days: i));
                  final key = DateTime(d.year, d.month, d.day);
                  return (map[key] ?? []).length;
                });

                return CalendarWeekStrip(
                  weekStart: weekStart,
                  selectedDate: _selectedDate,
                  onDaySelected: _onDateChanged,
                  onWeekShift: (delta) {
                    _onDateChanged(
                      _selectedDate.add(Duration(days: 7 * delta)),
                    );
                  },
                  taskCountsForWeek: counts,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ScheduledTaskViewModel scheduledVM) {
    final theme = Theme.of(context);
    // Must match `MainShell` bottom-nav colors for consistent look.
    const navBg = Color(0xFFEAF3FF); // light blue header background
    const navBlue = Color(0xFF103A8A); // darker blue for title/icon
    const menuCircleBg = Color(0xFF0F2E5C); // dark circle for menu button
    const double subtitleFontSize = 12.0;
    const double subtitleLineHeight = 1.2;
    final double subtitleBoxHeight = subtitleFontSize * subtitleLineHeight * 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF132A5D).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: menuCircleBg,
                    elevation: 2,
                    shadowColor: menuCircleBg.withValues(alpha: 0.25),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        SidebarDrawerController.scaffoldKey.currentState?.openDrawer();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.menu, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calendar',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: navBlue,
                            fontSize: 21,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: subtitleBoxHeight,
                          child: Text(
                            _monthYearLabel(_selectedDate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: navBlue.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                              fontSize: subtitleFontSize,
                              height: subtitleLineHeight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: navBg,
                    elevation: 2,
                    shadowColor: navBlue.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showDatePicker(scheduledVM),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: navBlue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthYearLabel(DateTime d) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  void _showGenerateScheduleOptions(
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Generate full-day schedule'),
                subtitle: const Text('Use the whole day window'),
                onTap: () {
                  Navigator.pop(ctx);
                  _onGenerateSchedule(taskVM, scheduledVM);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Generate in custom time range'),
                subtitle: const Text('Pick a time range and tasks'),
                onTap: () {
                  Navigator.pop(ctx);
                  _onGenerateScheduleInCustomRange(taskVM, scheduledVM);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onGenerateSchedule(
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) async {
    final userPrefsVM = Provider.of<UserPreferencesViewModel>(
      context,
      listen: false,
    );
    final prefs = await userPrefsVM.fetchPreferences();

    final tasks = await taskVM.fetchPendingTasksForSmartSchedule(
      _selectedDate,
      includeOverdue: true,
    );
    final existing = await scheduledVM.fetchScheduledTasksForDate(
      _selectedDate,
    );
    final scheduledTaskIds = existing.map((st) => st.taskId).toSet();
    final occupiedBlocks = existing
        .map(
          (st) =>
              ExistingBlock(startMinutes: st.startTime, endMinutes: st.endTime),
        )
        .toList();
    final candidates = tasks
        .where((t) => !scheduledTaskIds.contains(t.id))
        .toList();

    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tasks.isEmpty
                  ? 'No tasks to schedule. Add tasks first.'
                  : 'All available/overdue tasks are already scheduled on this day.',
            ),
          ),
        );
      }
      return;
    }

    final selectedTaskIds = await _showFullDayTaskSelectionSheet(
      candidates: candidates,
    );
    if (selectedTaskIds == null || selectedTaskIds.isEmpty) return;

    final toSchedule = candidates
        .where((t) => selectedTaskIds.contains(t.id))
        .toList();
    if (toSchedule.isEmpty) return;

    final result = SmartScheduleService.generateSchedule(
      date: _selectedDate,
      tasks: toSchedule,
      config: SmartScheduleConfig.fromPreferences(prefs),
      existingBlocks: occupiedBlocks,
    );

    if (result.slots.isEmpty && !result.hasOverflow) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No slots could be generated.')),
        );
      }
      return;
    }

    if (mounted) {
      showSchedulePreviewDialog(
        context: context,
        result: result,
        selectedDate: _selectedDate,
        scheduledVM: scheduledVM,
        taskVM: taskVM,
      );
    }
  }

  Future<void> _onGenerateScheduleInCustomRange(
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) async {
    final tasks = await taskVM.fetchPendingTasksForSmartSchedule(
      _selectedDate,
      includeOverdue: true,
    );
    final existing = await scheduledVM.fetchScheduledTasksForDate(
      _selectedDate,
    );
    final scheduledTaskIds = existing.map((st) => st.taskId).toSet();
    final unscheduledTasks = tasks
        .where((t) => !scheduledTaskIds.contains(t.id))
        .toList();

    if (unscheduledTasks.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tasks.isEmpty
                ? 'No tasks for ${_formatHeaderDate(_selectedDate)}. Add tasks first.'
                : 'All tasks for this day are already scheduled.',
          ),
        ),
      );
      return;
    }

    TimeOfDay rangeStart = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay rangeEnd = const TimeOfDay(hour: 12, minute: 0);
    final selectedTaskIds = <String>{for (final t in unscheduledTasks) t.id};

    final selection = await showModalBottomSheet<_CustomScheduleSelectionResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> pickTime(bool isStart) async {
                  final initial = isStart ? rangeStart : rangeEnd;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: initial,
                  );
                  if (picked != null) {
                    setSheetState(() {
                      if (isStart) {
                        rangeStart = picked;
                      } else {
                        rangeEnd = picked;
                      }
                    });
                  }
                }

                String formatTime(TimeOfDay t) {
                  final now = DateTime.now();
                  final dt = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    t.hour,
                    t.minute,
                  );
                  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }

                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Custom smart schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatHeaderDate(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickTime(true),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Start time',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(formatTime(rangeStart)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => pickTime(false),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'End time',
                                        border: OutlineInputBorder(),
                                      ),
                                      child: Text(formatTime(rangeEnd)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selectedTaskIds.length}/${unscheduledTasks.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                _selectionActionChip(
                                  label: 'Select all',
                                  onTap: () => setSheetState(() {
                                    selectedTaskIds
                                      ..clear()
                                      ..addAll(
                                        unscheduledTasks.map((t) => t.id),
                                      );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _selectionActionChip(
                                  label: 'Clear',
                                  onTap: () => setSheetState(() {
                                    selectedTaskIds.clear();
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          children: [
                            _taskSectionCard(
                              title: 'Overdue tasks',
                              subtitle:
                                  unscheduledTasks
                                      .where((t) => t.overdue)
                                      .isEmpty
                                  ? 'None'
                                  : '${unscheduledTasks.where((t) => t.overdue).length} task${unscheduledTasks.where((t) => t.overdue).length == 1 ? '' : 's'}',
                              icon: Icons.warning_amber_rounded,
                              headerColor: Colors.red.shade600,
                              child: () {
                                final overdue = unscheduledTasks
                                    .where((t) => t.overdue)
                                    .toList();
                                if (overdue.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      'No overdue tasks found.',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    ...overdue.asMap().entries.map((e) {
                                      final i = e.key;
                                      final task = e.value;
                                      final selected = selectedTaskIds.contains(
                                        task.id,
                                      );
                                      return Column(
                                        children: [
                                          _taskPickCheckboxRow(
                                            title: task.title,
                                            subtitle:
                                                'From ${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}',
                                            durationMinutes: task.duration,
                                            importance: task.importance,
                                            urgency: task.urgency,
                                            selected: selected,
                                            leadingIcon:
                                                Icons.priority_high_rounded,
                                            leadingColor: Colors.red.shade600,
                                            badgeText: 'OVERDUE',
                                            badgeColor: Colors.red.shade600,
                                            onChanged: (v) => setSheetState(() {
                                              if (v == true) {
                                                selectedTaskIds.add(task.id);
                                              } else {
                                                selectedTaskIds.remove(task.id);
                                              }
                                            }),
                                          ),
                                          if (i != overdue.length - 1)
                                            Divider(
                                              height: 1,
                                              color: Colors.grey[200],
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                );
                              }(),
                            ),
                            const SizedBox(height: 12),
                            _taskSectionCard(
                              title:
                                  'Tasks for ${_formatHeaderDate(_selectedDate)}',
                              subtitle:
                                  unscheduledTasks
                                      .where((t) => !t.overdue)
                                      .isEmpty
                                  ? 'None'
                                  : '${unscheduledTasks.where((t) => !t.overdue).length} task${unscheduledTasks.where((t) => !t.overdue).length == 1 ? '' : 's'}',
                              icon: Icons.event_available_rounded,
                              headerColor: Colors.black,
                              child: () {
                                final todays = unscheduledTasks
                                    .where((t) => !t.overdue)
                                    .toList();
                                if (todays.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      'No tasks for this day.',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: [
                                    ...todays.asMap().entries.map((e) {
                                      final i = e.key;
                                      final task = e.value;
                                      final selected = selectedTaskIds.contains(
                                        task.id,
                                      );
                                      return Column(
                                        children: [
                                          _taskPickCheckboxRow(
                                            title: task.title,
                                            subtitle: 'Ready to schedule',
                                            durationMinutes: task.duration,
                                            importance: task.importance,
                                            urgency: task.urgency,
                                            selected: selected,
                                            leadingIcon: Icons.task_alt_rounded,
                                            leadingColor: Colors.black87,
                                            badgeText: null,
                                            badgeColor: null,
                                            onChanged: (v) => setSheetState(() {
                                              if (v == true) {
                                                selectedTaskIds.add(task.id);
                                              } else {
                                                selectedTaskIds.remove(task.id);
                                              }
                                            }),
                                          ),
                                          if (i != todays.length - 1)
                                            Divider(
                                              height: 1,
                                              color: Colors.grey[200],
                                            ),
                                        ],
                                      );
                                    }),
                                  ],
                                );
                              }(),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (selectedTaskIds.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select at least one task',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  final startMinutes =
                                      rangeStart.hour * 60 + rangeStart.minute;
                                  final endMinutes =
                                      rangeEnd.hour * 60 + rangeEnd.minute;
                                  if (endMinutes <= startMinutes) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'End time must be after start time',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(
                                    ctx,
                                    _CustomScheduleSelectionResult(
                                      selectedTaskIds: Set<String>.from(
                                        selectedTaskIds,
                                      ),
                                      rangeStartMinutes: startMinutes,
                                      rangeEndMinutes: endMinutes,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                ),
                                child: const Text(
                                  'Generate',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;

    final selectedTasks = unscheduledTasks
        .where((t) => selection.selectedTaskIds.contains(t.id))
        .toList();
    if (selectedTasks.isEmpty) return;

    final existingBlocks = existing
        .map(
          (st) =>
              ExistingBlock(startMinutes: st.startTime, endMinutes: st.endTime),
        )
        .toList();

    final userPrefsVM = Provider.of<UserPreferencesViewModel>(
      context,
      listen: false,
    );
    final prefs = await userPrefsVM.fetchPreferences();

    final result = SmartScheduleService.generateScheduleForRange(
      date: _selectedDate,
      selectedTasks: selectedTasks,
      rangeStartMinutes: selection.rangeStartMinutes,
      rangeEndMinutes: selection.rangeEndMinutes,
      existingBlocks: existingBlocks,
      prefs: prefs,
    );

    if (result.slots.isEmpty && !result.hasOverflow) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No slots could be generated.')),
      );
      return;
    }

    if (!mounted) return;
    showSchedulePreviewDialog(
      context: context,
      result: result,
      selectedDate: _selectedDate,
      scheduledVM: scheduledVM,
      taskVM: taskVM,
    );
  }

  String _formatHeaderDate(DateTime d) {
    final now = DateTime.now();
    if (_isSameDay(d, now)) return 'Today';
    final tomorrow = now.add(const Duration(days: 1));
    if (_isSameDay(d, tomorrow)) return 'Tomorrow';
    return '${d.day}/${d.month}/${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showDatePicker(ScheduledTaskViewModel scheduledVM) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    showDatePicker(
      context: context,
      initialDate: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      firstDate: DateTime(
        todayOnly.year,
        todayOnly.month,
        todayOnly.day,
      ).subtract(const Duration(days: 365)),
      lastDate: DateTime(
        todayOnly.year,
        todayOnly.month,
        todayOnly.day,
      ).add(const Duration(days: 365)),
    ).then((date) {
      if (date != null) _onDateChanged(date);
    });
  }

  Widget _buildDailyView(
    BuildContext context,
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) {
    return StreamBuilder<List<ScheduledTaskModel>>(
      stream: scheduledVM.scheduledTasksForDate(_selectedDate),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading schedule',
                    style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        final scheduled = snapshot.data ?? [];
        return StreamBuilder<List<TaskModel>>(
          stream: taskVM.tasksStream,
          builder: (context, taskSnapshot) {
            final allTasks = taskSnapshot.data ?? [];
            final taskMap = {for (var t in allTasks) t.id: t};
            // Hide scheduled blocks whose task was deleted (orphan scheduled_tasks / stream lag).
            final scheduledForUi = taskSnapshot.hasData
                ? scheduled
                      .where((st) => taskMap.containsKey(st.taskId))
                      .toList()
                : scheduled;

            // Auto-backfill calendar blocks for tasks that already have start/end times
            // but no scheduled_tasks entry for the selected date (e.g. imported from DB).
            _autoBackfillScheduledForDay(
              allTasks: allTasks,
              scheduled: scheduled,
              scheduledVM: scheduledVM,
            );

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildTimeSlots(
                    context,
                    scheduledVM,
                    taskVM,
                    scheduledForUi,
                    taskMap,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSlots(
    BuildContext context,
    ScheduledTaskViewModel scheduledVM,
    TaskViewModel taskVM,
    List<ScheduledTaskModel> scheduled,
    Map<String, TaskModel> taskMap,
  ) {
    final totalMinutes = (_dayEndHour - _dayStartHour) * 60;
    final slots = <Widget>[];

    // Draw each scheduled task block once
    final minHeightPx = (_minDurationMinutes / 60.0) * _slotHeight - 2;
    for (final block in scheduled) {
      final task = taskMap[block.taskId];
      double top = (block.startTime - _dayStartHour * 60) / 60 * _slotHeight;
      double calculatedHeight =
          (block.endTime - block.startTime) / 60 * _slotHeight;
      double height = calculatedHeight - 2;
      if (block.id == _draggingScheduledTaskId && _dragMode != null) {
        if (_dragMode == _DragMode.move) {
          top += _dragDeltaY;
        } else if (_dragMode == _DragMode.resizeTop) {
          top += _dragDeltaY;
          height = (height - _dragDeltaY).clamp(minHeightPx, double.infinity);
        } else {
          height = (height + _dragDeltaY).clamp(minHeightPx, double.infinity);
        }
      }
      final isShortTask = (block.endTime - block.startTime) <= 30;
      final blockTitle =
          task?.title ??
          (block.taskName.trim().isNotEmpty
              ? block.taskName
              : 'Scheduled block');
      slots.add(
        Positioned(
          left: 56,
          right: 0,
          top: top,
          height: height,
          child: _buildScheduledTaskCard(
            context,
            block,
            blockTitle,
            scheduledVM,
            taskVM,
            isShortTask,
            task,
            cardHeight: height + 2,
          ),
        ),
      );
    }

    // Draw empty tap targets for 30-min slots that don't overlap any block
    for (var minute = 0; minute < totalMinutes; minute += 30) {
      final startMinutes = _dayStartHour * 60 + minute;
      final endMinutes = startMinutes + 30;
      if (_scheduledBlockInRange(scheduled, startMinutes, endMinutes) == null) {
        slots.add(
          Positioned(
            left: 56,
            right: 0,
            top: (minute / 60) * _slotHeight,
            height: _slotHeight / 2 - 2,
            child: _buildEmptySlot(context, startMinutes, scheduledVM, taskVM),
          ),
        );
      }
    }

    return SizedBox(
      height: totalMinutes / 60 * _slotHeight,
      child: Stack(
        children: [
          Column(
            children: List.generate(_dayEndHour - _dayStartHour, (i) {
              final hour = _dayStartHour + i;
              return SizedBox(
                height: _slotHeight.toDouble(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 0),
                        height: 1,
                        color: Colors.grey[200],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          ...slots,
        ],
      ),
    );
  }

  /// Ensure that tasks which already have start/end times are reflected on the calendar.
  /// This is mainly for tasks imported or created outside the app UI.
  void _autoBackfillScheduledForDay({
    required List<TaskModel> allTasks,
    required List<ScheduledTaskModel> scheduled,
    required ScheduledTaskViewModel scheduledVM,
  }) {
    if (allTasks.isEmpty) return;

    final scheduledByTaskId = <String, List<ScheduledTaskModel>>{};
    for (final st in scheduled) {
      (scheduledByTaskId[st.taskId] ??= []).add(st);
    }

    for (final task in allTasks) {
      if (task.startTime == null ||
          task.endTime == null ||
          task.endTime! <= task.startTime! ||
          task.isCompleted) {
        continue;
      }

      // Only consider tasks for the currently selected date
      if (!_isSameDay(task.createdAt, _selectedDate)) continue;

      final removedKey =
          '${task.id}|${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';
      if (_removedFromCalendarKeys.contains(removedKey)) {
        if (task.startTime == null && task.endTime == null) {
          _removedFromCalendarKeys.remove(removedKey);
        }
        continue;
      }

      final existing = scheduledByTaskId[task.id] ?? const [];
      final hasForSelectedDate = existing.any(
        (st) =>
            st.scheduleDate.year == _selectedDate.year &&
            st.scheduleDate.month == _selectedDate.month &&
            st.scheduleDate.day == _selectedDate.day,
      );

      if (!hasForSelectedDate) {
        final key =
            '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}|${task.id}';
        if (_autoBackfillInFlight.contains(key)) continue;
        _autoBackfillInFlight.add(key);

        // Fire-and-forget: if there is no entry for this task on this date,
        // create or update scheduled_tasks row(s) based on task start/end time.
        scheduledVM
            .updateOrCreateScheduledTasksForTask(
              taskId: task.id,
              startTimeMinutes: task.startTime!,
              endTimeMinutes: task.endTime!,
              scheduleDate: _selectedDate,
              taskName: task.title,
            )
            .whenComplete(() => _autoBackfillInFlight.remove(key));
      }
    }
  }

  ScheduledTaskModel? _scheduledBlockInRange(
    List<ScheduledTaskModel> scheduled,
    int slotStart,
    int slotEnd,
  ) {
    for (final s in scheduled) {
      if (s.startTime < slotEnd && s.endTime > slotStart) return s;
    }
    return null;
  }

  Widget _buildEmptySlot(
    BuildContext context,
    int startMinutes,
    ScheduledTaskViewModel scheduledVM,
    TaskViewModel taskVM,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            _showScheduleTaskDialog(context, startMinutes, taskVM, scheduledVM),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  /// Status colors for calendar blocks: orange = pending, red = overdue, green = completed.
  Color _scheduledTaskStatusColor(ScheduledTaskModel st, TaskModel? task) {
    final isCompleted = task?.isCompleted ?? (st.status == 'completed');
    if (isCompleted) return Colors.green;
    if (task?.overdue ?? false) return Colors.red;
    return Colors.orange;
  }

  Widget _buildScheduledTaskCard(
    BuildContext context,
    ScheduledTaskModel st,
    String title,
    ScheduledTaskViewModel scheduledVM,
    TaskViewModel taskVM,
    bool isShortTask,
    TaskModel? task, {
    required double cardHeight,
  }) {
    final statusColor = _scheduledTaskStatusColor(st, task);
    // One-hour blocks (~58px tall) need tight line metrics; default text heights overflow ~3px.
    final compactCard = cardHeight <= 66;
    return GestureDetector(
      onTap: () {
        if (_didDragToAdjustTime) {
          _didDragToAdjustTime = false;
          return;
        }
        _showScheduledTaskDetails(
          context,
          st,
          title,
          scheduledVM,
          taskVM,
          task,
        );
      },
      onVerticalDragStart: (details) {
        final ratio = details.localPosition.dy / cardHeight;
        setState(() {
          _draggingScheduledTaskId = st.id;
          _dragOriginalStart = st.startTime;
          _dragOriginalEnd = st.endTime;
          _dragDeltaY = 0;
          _dragMode = ratio < 0.2
              ? _DragMode.resizeTop
              : (ratio > 0.8 ? _DragMode.resizeBottom : _DragMode.move);
        });
      },
      onVerticalDragUpdate: (details) {
        setState(() => _dragDeltaY += details.delta.dy);
      },
      onVerticalDragEnd: (details) async {
        final id = _draggingScheduledTaskId;
        final origStart = _dragOriginalStart;
        final origEnd = _dragOriginalEnd;
        final mode = _dragMode;
        final deltaY = _dragDeltaY;
        setState(() {
          _draggingScheduledTaskId = null;
          _dragDeltaY = 0;
          _dragMode = null;
          if (deltaY.abs() > 8) _didDragToAdjustTime = true;
        });
        if (id == null || mode == null) return;
        final deltaMinutes = (deltaY * 60 / _slotHeight).round();
        int newStart = origStart;
        int newEnd = origEnd;
        final duration = origEnd - origStart;
        if (mode == _DragMode.move) {
          newStart = _snapTo(origStart + deltaMinutes, _snapMinutes);
          newStart = newStart.clamp(0, 24 * 60 - _minDurationMinutes);
          newEnd = (newStart + duration).clamp(_minDurationMinutes, 24 * 60);
          if (newEnd > 24 * 60) {
            newEnd = 24 * 60;
            newStart = newEnd - duration;
          }
        } else if (mode == _DragMode.resizeTop) {
          newStart = _snapTo(origStart + deltaMinutes, _snapMinutes);
          newStart = newStart.clamp(0, origEnd - _minDurationMinutes);
        } else {
          newEnd = _snapTo(origEnd + deltaMinutes, _snapMinutes);
          newEnd = newEnd.clamp(origStart + _minDurationMinutes, 24 * 60);
        }
        try {
          await scheduledVM.updateScheduledTask(
            id: id,
            scheduleDate: _selectedDate,
            startTimeMinutes: newStart,
            endTimeMinutes: newEnd,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Time updated to ${_minutesToTime(newStart)} – ${_minutesToTime(newEnd)}',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not update time'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isShortTask ? 4 : 8,
          vertical: isShortTask ? 2 : (compactCard ? 4 : 6),
        ),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (cardHeight > 44) _buildResizeHandle(compact: compactCard),
            Expanded(
              child: isShortTask
                  ? Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              size: compactCard ? 12 : 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: compactCard ? 11 : 12,
                                  height: 1.0,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compactCard ? 1 : 2),
                        Text(
                          '${_minutesToTime(st.startTime)} - ${_minutesToTime(st.endTime)}',
                          style: TextStyle(
                            fontSize: compactCard ? 9 : 10,
                            height: 1.0,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            if (cardHeight > 44) _buildResizeHandle(compact: compactCard),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeHandle({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
      child: Center(
        child: Container(
          width: compact ? 20 : 24,
          height: compact ? 2 : 3,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(compact ? 1 : 1.5),
          ),
        ),
      ),
    );
  }

  String _minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _showAddTaskDialog(
    BuildContext context,
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    String? selectedCategoryId;
    int urgency = 3;
    int importance = 3;
    TimeOfDay scheduleTime = const TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.add_task,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Task',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatHeaderDate(_selectedDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: 'Task Title',
                              hintText: 'Enter task title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'Enter description',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (minutes)',
                              hintText: 'e.g. 30',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: scheduleTime,
                              );
                              if (picked != null) {
                                setDialogState(() => scheduleTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Time on calendar',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                scheduleTime.format(context),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<List<CategoryModel>>(
                            stream: taskVM.categoriesStream,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final categories = snapshot.data!;
                              if (categories.isEmpty) {
                                return const Text(
                                  'No categories. Add one in Tasks.',
                                );
                              }
                              if (selectedCategoryId == null &&
                                  categories.isNotEmpty) {
                                selectedCategoryId = categories.first.id;
                              }
                              return DropdownButtonFormField<String>(
                                value: selectedCategoryId,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: categories
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setDialogState(
                                  () => selectedCategoryId = value,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Urgency',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Colors.black,
                                    inactiveTrackColor: Colors.grey[300],
                                    thumbColor: Colors.black,
                                  ),
                                  child: Slider(
                                    value: urgency.toDouble(),
                                    min: 1,
                                    max: 5,
                                    divisions: 4,
                                    onChanged: (v) => setDialogState(
                                      () => urgency = v.toInt(),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text(
                                    '$urgency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Importance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Colors.black,
                                    inactiveTrackColor: Colors.grey[300],
                                    thumbColor: Colors.black,
                                  ),
                                  child: Slider(
                                    value: importance.toDouble(),
                                    min: 1,
                                    max: 5,
                                    divisions: 4,
                                    onChanged: (v) => setDialogState(
                                      () => importance = v.toInt(),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Center(
                                  child: Text(
                                    '$importance',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a task title'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final catId = selectedCategoryId;
                              if (catId == null || catId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a category'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final duration =
                                  int.tryParse(durationController.text) ?? 30;
                              final dateOnly = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              );
                              final taskId = await taskVM.addTask(
                                title: title,
                                description: descriptionController.text.trim(),
                                urgency: urgency,
                                importance: importance,
                                duration: duration,
                                categoryId: catId,
                                taskDate: dateOnly,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (taskId != null) {
                                final startMinutes =
                                    scheduleTime.hour * 60 +
                                    scheduleTime.minute;
                                try {
                                  await scheduledVM.addScheduledTask(
                                    taskId: taskId,
                                    scheduleDate: _selectedDate,
                                    startTimeMinutes: startMinutes,
                                    endTimeMinutes: startMinutes + duration,
                                    taskName: title,
                                    taskStatus: 'pending',
                                  );
                                } catch (_) {}
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added: $title (Tasks & Calendar)',
                                      ),
                                      backgroundColor: Colors.black,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to add task'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Add Task',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showScheduleTaskDialog(
    BuildContext context,
    int startMinutes,
    TaskViewModel taskVM,
    ScheduledTaskViewModel scheduledVM,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StreamBuilder<List<TaskModel>>(
        stream: taskVM.tasksStream,
        builder: (context, taskSnapshot) {
          final tasks = taskSnapshot.data ?? [];
          return StreamBuilder<List<ScheduledTaskModel>>(
            stream: scheduledVM.scheduledTasksForDate(_selectedDate),
            builder: (context, scheduledSnapshot) {
              final scheduled = scheduledSnapshot.data ?? [];
              final scheduledTaskIds = scheduled.map((s) => s.taskId).toSet();
              final overdue = tasks
                  .where(
                    (t) =>
                        !t.isCompleted &&
                        (t.overdue) &&
                        !scheduledTaskIds.contains(t.id),
                  )
                  .toList();
              final available = tasks
                  .where(
                    (t) =>
                        !t.isCompleted &&
                        !t.overdue &&
                        _isSameDay(t.createdAt, _selectedDate) &&
                        !scheduledTaskIds.contains(t.id),
                  )
                  .toList();

              if (overdue.isEmpty && available.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No tasks to schedule. '
                        'Add tasks for ${_formatHeaderDate(_selectedDate)} (use + button above) '
                        'or complete any overdue tasks.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Schedule task at ${_minutesToTime(startMinutes)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (overdue.isNotEmpty) ...[
                            _taskSectionCard(
                              title: 'Overdue tasks',
                              subtitle:
                                  '${overdue.length} task${overdue.length == 1 ? '' : 's'}',
                              icon: Icons.warning_amber_rounded,
                              headerColor: Colors.red.shade600,
                              child: Column(
                                children: [
                                  ...overdue.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final task = entry.value;
                                    final endMinutes =
                                        startMinutes + task.duration;
                                    return Column(
                                      children: [
                                        _taskPickRow(
                                          title: task.title,
                                          subtitle:
                                              'From ${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}',
                                          durationMinutes: task.duration,
                                          startMinutes: startMinutes,
                                          endMinutes: endMinutes,
                                          leadingIcon:
                                              Icons.priority_high_rounded,
                                          leadingColor: Colors.red.shade600,
                                          badgeText: 'OVERDUE',
                                          badgeColor: Colors.red.shade600,
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            try {
                                              await scheduledVM
                                                  .addScheduledTask(
                                                    taskId: task.id,
                                                    scheduleDate: _selectedDate,
                                                    startTimeMinutes:
                                                        startMinutes,
                                                    endTimeMinutes: endMinutes,
                                                    taskName: task.title,
                                                    taskStatus: task.status,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Scheduled: ${task.title}',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to schedule: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        if (index != overdue.length - 1)
                                          Divider(
                                            height: 1,
                                            color: Colors.grey[200],
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (available.isNotEmpty) ...[
                            _taskSectionCard(
                              title: 'Available tasks',
                              subtitle:
                                  '${available.length} task${available.length == 1 ? '' : 's'} • ${_formatHeaderDate(_selectedDate)}',
                              icon: Icons.event_available_rounded,
                              headerColor: Colors.black,
                              child: Column(
                                children: [
                                  ...available.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final task = entry.value;
                                    final endMinutes =
                                        startMinutes + task.duration;
                                    return Column(
                                      children: [
                                        _taskPickRow(
                                          title: task.title,
                                          subtitle: 'Ready to schedule',
                                          durationMinutes: task.duration,
                                          startMinutes: startMinutes,
                                          endMinutes: endMinutes,
                                          leadingIcon: Icons.task_alt_rounded,
                                          leadingColor: Colors.black87,
                                          badgeText: null,
                                          badgeColor: null,
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            try {
                                              await scheduledVM
                                                  .addScheduledTask(
                                                    taskId: task.id,
                                                    scheduleDate: _selectedDate,
                                                    startTimeMinutes:
                                                        startMinutes,
                                                    endTimeMinutes: endMinutes,
                                                    taskName: task.title,
                                                    taskStatus: task.status,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Scheduled: ${task.title}',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Failed to schedule: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        if (index != available.length - 1)
                                          Divider(
                                            height: 1,
                                            color: Colors.grey[200],
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _taskSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color headerColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: headerColor.withOpacity(0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: headerColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: headerColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Text(
                      'Tap to schedule',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskPickRow({
    required String title,
    required String subtitle,
    required int durationMinutes,
    required int startMinutes,
    required int endMinutes,
    required IconData leadingIcon,
    required Color leadingColor,
    required String? badgeText,
    required Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: leadingColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leadingIcon, color: leadingColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (badgeText != null && badgeColor != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: badgeColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _metaChip(
                          icon: Icons.timer_outlined,
                          text: '${durationMinutes}m',
                        ),
                        const SizedBox(width: 8),
                        _metaChip(
                          icon: Icons.schedule,
                          text:
                              '${_minutesToTime(startMinutes)}–${_minutesToTime(endMinutes)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionActionChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey[800],
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskPickCheckboxRow({
    required String title,
    required String subtitle,
    required int durationMinutes,
    required int importance,
    required int urgency,
    required bool selected,
    required IconData leadingIcon,
    required Color leadingColor,
    required String? badgeText,
    required Color? badgeColor,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: onChanged,
                activeColor: Colors.black,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: leadingColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leadingIcon, color: leadingColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (badgeText != null && badgeColor != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: badgeColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metaChip(
                          icon: Icons.timer_outlined,
                          text: '${durationMinutes}m',
                        ),
                        _metaChip(
                          icon: Icons.star_outline,
                          text: 'I$importance/5',
                        ),
                        _metaChip(
                          icon: Icons.flag_outlined,
                          text: 'U$urgency/5',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Set<String>?> _showFullDayTaskSelectionSheet({
    required List<TaskModel> candidates,
  }) async {
    final overdue = candidates.where((t) => t.overdue).toList();
    final todays = candidates.where((t) => !t.overdue).toList();
    final selectedTaskIds = <String>{for (final t in candidates) t.id};

    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Full-day smart schedule',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatHeaderDate(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${selectedTaskIds.length}/${candidates.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                _selectionActionChip(
                                  label: 'Select all',
                                  onTap: () => setSheetState(() {
                                    selectedTaskIds
                                      ..clear()
                                      ..addAll(candidates.map((t) => t.id));
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _selectionActionChip(
                                  label: 'Clear',
                                  onTap: () => setSheetState(() {
                                    selectedTaskIds.clear();
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          children: [
                            _taskSectionCard(
                              title: 'Overdue tasks',
                              subtitle: overdue.isEmpty
                                  ? 'None'
                                  : '${overdue.length} task${overdue.length == 1 ? '' : 's'}',
                              icon: Icons.warning_amber_rounded,
                              headerColor: Colors.red.shade600,
                              child: overdue.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'No overdue tasks found.',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        ...overdue.asMap().entries.map((e) {
                                          final i = e.key;
                                          final task = e.value;
                                          final selected = selectedTaskIds
                                              .contains(task.id);
                                          return Column(
                                            children: [
                                              _taskPickCheckboxRow(
                                                title: task.title,
                                                subtitle:
                                                    'From ${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}',
                                                durationMinutes: task.duration,
                                                importance: task.importance,
                                                urgency: task.urgency,
                                                selected: selected,
                                                leadingIcon:
                                                    Icons.priority_high_rounded,
                                                leadingColor:
                                                    Colors.red.shade600,
                                                badgeText: 'OVERDUE',
                                                badgeColor: Colors.red.shade600,
                                                onChanged: (v) =>
                                                    setSheetState(() {
                                                      if (v == true) {
                                                        selectedTaskIds.add(
                                                          task.id,
                                                        );
                                                      } else {
                                                        selectedTaskIds.remove(
                                                          task.id,
                                                        );
                                                      }
                                                    }),
                                              ),
                                              if (i != overdue.length - 1)
                                                Divider(
                                                  height: 1,
                                                  color: Colors.grey[200],
                                                ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _taskSectionCard(
                              title:
                                  'Tasks for ${_formatHeaderDate(_selectedDate)}',
                              subtitle: todays.isEmpty
                                  ? 'None'
                                  : '${todays.length} task${todays.length == 1 ? '' : 's'}',
                              icon: Icons.event_available_rounded,
                              headerColor: Colors.black,
                              child: todays.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'No tasks for this day.',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        ...todays.asMap().entries.map((e) {
                                          final i = e.key;
                                          final task = e.value;
                                          final selected = selectedTaskIds
                                              .contains(task.id);
                                          return Column(
                                            children: [
                                              _taskPickCheckboxRow(
                                                title: task.title,
                                                subtitle: 'Ready to schedule',
                                                durationMinutes: task.duration,
                                                importance: task.importance,
                                                urgency: task.urgency,
                                                selected: selected,
                                                leadingIcon:
                                                    Icons.task_alt_rounded,
                                                leadingColor: Colors.black87,
                                                badgeText: null,
                                                badgeColor: null,
                                                onChanged: (v) =>
                                                    setSheetState(() {
                                                      if (v == true) {
                                                        selectedTaskIds.add(
                                                          task.id,
                                                        );
                                                      } else {
                                                        selectedTaskIds.remove(
                                                          task.id,
                                                        );
                                                      }
                                                    }),
                                              ),
                                              if (i != todays.length - 1)
                                                Divider(
                                                  height: 1,
                                                  color: Colors.grey[200],
                                                ),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (selectedTaskIds.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select at least one task',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(
                                    ctx,
                                    Set<String>.from(selectedTaskIds),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                ),
                                child: const Text(
                                  'Generate',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showScheduledTaskDetails(
    BuildContext context,
    ScheduledTaskModel st,
    String title,
    ScheduledTaskViewModel scheduledVM,
    TaskViewModel taskVM,
    TaskModel? task,
  ) {
    // Prefs future + reminder UI state must live *outside* the modal `builder`.
    // If they are created inside `builder`, every route rebuild (e.g. Firestore stream
    // on Android) recreates the Set and re-inits from [st], wiping edits and re-saving
    // stale offsets (Chrome often doesn't hit the same rebuild timing).
    final userPrefsVM = Provider.of<UserPreferencesViewModel>(
      context,
      listen: false,
    );
    final prefsFuture = userPrefsVM.fetchPreferences();

    final selectedOffsetsState = <int>{};
    var didInitReminderState = false;
    var remindersEnabledState = true;
    String? reminderSaveMessage;
    var reminderSaveError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<UserPreferencesModel?>(
              future: prefsFuture,
              builder: (context, prefsSnap) {
                final prefs = prefsSnap.data;

                if (!didInitReminderState &&
                    prefsSnap.connectionState != ConnectionState.waiting) {
                  didInitReminderState = true;
                  remindersEnabledState =
                      st.remindersEnabled ?? prefs?.remindersEnabled ?? true;
                  selectedOffsetsState
                    ..clear()
                    ..addAll(st.reminderOffsetsMinutes);
                }

                Future<void> addCustomOffset() async {
                  final controller = TextEditingController();
                  final value = await showDialog<int?>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Custom reminder'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minutes before',
                          hintText: 'e.g. 90',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, null),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final parsed = int.tryParse(controller.text.trim());
                            if (parsed == null || parsed <= 0) {
                              Navigator.pop(dCtx, null);
                              return;
                            }
                            Navigator.pop(dCtx, parsed);
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                  if (value != null && value > 0) {
                    setSheetState(() => selectedOffsetsState.add(value));
                  }
                }

                Future<void> saveReminderSettings() async {
                  try {
                    await scheduledVM.updateScheduledTask(
                      id: st.id,
                      scheduleDate: _selectedDate,
                      startTimeMinutes: st.startTime,
                      endTimeMinutes: st.endTime,
                      reminderOffsetsMinutes: selectedOffsetsState.toList(),
                      remindersEnabled: remindersEnabledState,
                      prefs: prefs,
                    );
                    final effectiveOffsets = selectedOffsetsState.isEmpty
                        ? <int>[prefs?.defaultReminderMinutesBefore ?? 0]
                        : selectedOffsetsState.toList();
                    effectiveOffsets.removeWhere((v) => v <= 0);
                    effectiveOffsets.sort((a, b) => b.compareTo(a));
                    final offsetsText = effectiveOffsets.isEmpty
                        ? 'no offsets'
                        : effectiveOffsets
                              .map((m) => m == 1440 ? '1 day' : '$m min')
                              .join(', ');
                    setSheetState(() {
                      reminderSaveError = false;
                      reminderSaveMessage =
                          'Saved for "$title" (${_minutesToTime(st.startTime)} - ${_minutesToTime(st.endTime)}), offsets: $offsetsText.';
                    });
                  } catch (_) {
                    setSheetState(() {
                      reminderSaveError = true;
                      reminderSaveMessage =
                          'Could not save reminders for "$title". Please try again.';
                    });
                  }
                }

                return DraggableScrollableSheet(
                  initialChildSize: 0.6,
                  minChildSize: 0.35,
                  maxChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event_note,
                                  color: Colors.black87,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'Scheduled task',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Flexible(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _detailRow(
                                  Icons.schedule,
                                  'Time',
                                  '${_minutesToTime(st.startTime)} – ${_minutesToTime(st.endTime)} (${st.durationMinutes} min)',
                                ),
                                if (task != null) ...[
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _detailRow(
                                      Icons.description_outlined,
                                      'Description',
                                      task.description,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _detailRow(
                                    Icons.flag_outlined,
                                    'Urgency',
                                    '${task.urgency}/5',
                                  ),
                                  const SizedBox(height: 8),
                                  _detailRow(
                                    Icons.star_outline,
                                    'Importance',
                                    '${task.importance}/5',
                                  ),
                                  const SizedBox(height: 12),
                                  StreamBuilder<List<CategoryModel>>(
                                    stream: taskVM.categoriesStream,
                                    builder: (context, snapshot) {
                                      String categoryName = task.categoryId;
                                      if (snapshot.hasData) {
                                        for (final c in snapshot.data!) {
                                          if (c.id == task.categoryId) {
                                            categoryName = c.name;
                                            break;
                                          }
                                        }
                                      }
                                      return _detailRow(
                                        Icons.label_outline,
                                        'Category',
                                        categoryName,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _detailRow(
                                    Icons.timer_outlined,
                                    'Duration',
                                    '${task.duration} min',
                                  ),
                                  const SizedBox(height: 8),
                                  _detailRow(
                                    Icons.info_outline,
                                    'Task status',
                                    task.status,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _detailRow(
                                  Icons.calendar_today,
                                  'Schedule status',
                                  st.status,
                                ),
                                const SizedBox(height: 24),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                const Text(
                                  'Reminders',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Remind me'),
                                  subtitle: Text(
                                    remindersEnabledState
                                        ? 'Notifications will be scheduled for this task'
                                        : 'No reminders for this scheduled task',
                                  ),
                                  value: remindersEnabledState,
                                  onChanged: (v) => setSheetState(() {
                                    remindersEnabledState = v;
                                  }),
                                ),
                                const SizedBox(height: 6),
                                if (remindersEnabledState) ...[
                                  Text(
                                    'Minutes before start',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final minutes in const [
                                        5,
                                        10,
                                        15,
                                        30,
                                        60,
                                        1440,
                                      ])
                                        FilterChip(
                                          label: Text(
                                            minutes == 1440
                                                ? '1 day'
                                                : '$minutes',
                                          ),
                                          selected: selectedOffsetsState
                                              .contains(minutes),
                                          onSelected: (sel) =>
                                              setSheetState(() {
                                                if (sel) {
                                                  selectedOffsetsState.add(
                                                    minutes,
                                                  );
                                                } else {
                                                  selectedOffsetsState.remove(
                                                    minutes,
                                                  );
                                                }
                                              }),
                                        ),
                                      ActionChip(
                                        label: const Text('Custom'),
                                        onPressed: addCustomOffset,
                                      ),
                                      for (final minutes
                                          in (selectedOffsetsState
                                              .where(
                                                (m) => !_presetReminderOffsets
                                                    .contains(m),
                                              )
                                              .toList()
                                            ..sort()))
                                        FilterChip(
                                          label: Text(
                                            minutes >= 60 && minutes % 60 == 0
                                                ? '${minutes ~/ 60} hr'
                                                : '$minutes min',
                                          ),
                                          selected: true,
                                          onSelected: (sel) =>
                                              setSheetState(() {
                                                if (!sel) {
                                                  selectedOffsetsState.remove(
                                                    minutes,
                                                  );
                                                }
                                              }),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton(
                                      onPressed: saveReminderSettings,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Save reminders'),
                                    ),
                                  ),
                                  if (reminderSaveMessage != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: reminderSaveError
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: reminderSaveError
                                              ? Colors.red.shade200
                                              : Colors.green.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            reminderSaveError
                                                ? Icons.error_outline
                                                : Icons.check_circle_outline,
                                            size: 18,
                                            color: reminderSaveError
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              reminderSaveMessage!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: reminderSaveError
                                                    ? Colors.red.shade800
                                                    : Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 24),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      Navigator.pop(ctx);
                                      final removedKey =
                                          '${st.taskId}|${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';
                                      setState(
                                        () => _removedFromCalendarKeys.add(
                                          removedKey,
                                        ),
                                      );
                                      try {
                                        await scheduledVM.deleteScheduledTask(
                                          st.id,
                                          prefs: prefs,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Removed "$title" from calendar',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (_) {
                                        setState(
                                          () => _removedFromCalendarKeys.remove(
                                            removedKey,
                                          ),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not remove from schedule',
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.event_busy_rounded,
                                              size: 20,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Remove from calendar',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red.shade800,
                                              fontSize: 15,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomScheduleSelectionResult {
  final Set<String> selectedTaskIds;
  final int rangeStartMinutes;
  final int rangeEndMinutes;

  const _CustomScheduleSelectionResult({
    required this.selectedTaskIds,
    required this.rangeStartMinutes,
    required this.rangeEndMinutes,
  });
}
