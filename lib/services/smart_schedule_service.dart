import '../models/task_model.dart';
import '../models/user_preferences_model.dart';

/// One proposed time slot from the smart scheduler (task or break).
class ProposedSlot {
  final String taskId;
  final String taskTitle;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final bool isBreak;

  const ProposedSlot({
    required this.taskId,
    required this.taskTitle,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    this.isBreak = false,
  });

  int get durationMinutes => endMinutes - startMinutes;
}

/// Configuration for the rule-based scheduler.
class SmartScheduleConfig {
  /// Day start in minutes from midnight (e.g. 8:00 = 480).
  final int dayStartMinutes;
  /// Day end in minutes from midnight (e.g. 22:00 = 1320).
  final int dayEndMinutes;
  /// Break duration in minutes between tasks.
  final int breakDurationMinutes;
  /// Insert a break after every [breakAfterTaskMinutes] minutes of task time.
  /// 0 = insert a break after every task (legacy behavior).
  final int breakAfterTaskMinutes;
  /// Snap step in minutes (e.g. 15).
  final int snapMinutes;

  const SmartScheduleConfig({
    this.dayStartMinutes = 8 * 60,
    this.dayEndMinutes = 22 * 60,
    this.breakDurationMinutes = 10,
    this.breakAfterTaskMinutes = 0,
    this.snapMinutes = 15,
  });

  /// Build config from user preferences. Uses defaults when [prefs] is null.
  static SmartScheduleConfig fromPreferences(UserPreferencesModel? prefs) {
    if (prefs == null) return const SmartScheduleConfig();
    return SmartScheduleConfig(
      dayStartMinutes: 8 * 60,
      dayEndMinutes: 22 * 60,
      breakDurationMinutes: prefs.breakDurationMinutes,
      breakAfterTaskMinutes: prefs.breakAfterTaskMinutes,
      snapMinutes: 15,
    );
  }
}

/// Result of running the smart scheduler.
class SmartScheduleResult {
  final List<ProposedSlot> slots;
  final bool hasOverflow;
  final String? overflowMessage;

  const SmartScheduleResult({
    required this.slots,
    this.hasOverflow = false,
    this.overflowMessage,
  });
}

/// Existing occupied block on the calendar (e.g. a scheduled task).
class ExistingBlock {
  final int startMinutes;
  final int endMinutes;

  const ExistingBlock({
    required this.startMinutes,
    required this.endMinutes,
  });
}

/// Rule-based smart task scheduler. Prioritizes by importance + urgency,
/// fits tasks into the day with breaks, no Firestore dependency.
class SmartScheduleService {
  static const SmartScheduleConfig defaultConfig = SmartScheduleConfig();

  /// Generates a proposed daily schedule for the given date and tasks.
  /// Tasks should be pending and for this day (caller filters by createdAt date).
  /// Returns proposed slots (tasks + breaks); does not write to Firestore.
  static SmartScheduleResult generateSchedule({
    required DateTime date,
    required List<TaskModel> tasks,
    SmartScheduleConfig config = defaultConfig,
    List<ExistingBlock> existingBlocks = const [],
  }) {
    if (tasks.isEmpty) {
      return const SmartScheduleResult(slots: []);
    }

    final dateOnly = DateTime(date.year, date.month, date.day);
    final sorted = _sortByPriority(List<TaskModel>.from(tasks));
    final slots = <ProposedSlot>[];
    int current = config.dayStartMinutes;
    final dayEnd = config.dayEndMinutes;
    bool hasOverflow = false;
    int overflowCount = 0;
    int taskMinutesSinceBreak = 0;

    for (final task in sorted) {
      final duration = _snapTo(task.duration.clamp(1, 24 * 60), config.snapMinutes);
      if (duration <= 0) continue;

      int start = _snapTo(current, config.snapMinutes);
      int end = start + duration;

      // Skip forward to avoid overlaps with existing calendar blocks.
      final adjusted = _adjustForExistingBlocks(
        start: start,
        end: end,
        duration: duration,
        dayStart: config.dayStartMinutes,
        dayEnd: dayEnd,
        snapMinutes: config.snapMinutes,
        existingBlocks: existingBlocks,
      );
      if (adjusted == null) {
        hasOverflow = true;
        overflowCount++;
        continue;
      }
      start = adjusted.$1;
      end = adjusted.$2;

      if (start >= dayEnd) {
        hasOverflow = true;
        overflowCount++;
        continue;
      }
      if (end > dayEnd) {
        end = dayEnd;
        start = end - duration;
        if (start < config.dayStartMinutes) {
          hasOverflow = true;
          overflowCount++;
          continue;
        }
      }

      slots.add(ProposedSlot(
        taskId: task.id,
        taskTitle: task.title,
        date: dateOnly,
        startMinutes: start,
        endMinutes: end,
        isBreak: false,
      ));
      taskMinutesSinceBreak += duration;
      current = end;

      final shouldInsertBreak = config.breakDurationMinutes > 0 &&
          (config.breakAfterTaskMinutes <= 0
              ? true
              : taskMinutesSinceBreak >= config.breakAfterTaskMinutes);
      if (shouldInsertBreak) {
        final breakEnd = current + config.breakDurationMinutes;
        if (breakEnd <= dayEnd) {
          slots.add(ProposedSlot(
            taskId: '',
            taskTitle: 'Break',
            date: dateOnly,
            startMinutes: current,
            endMinutes: breakEnd,
            isBreak: true,
          ));
          current = breakEnd;
        }
        taskMinutesSinceBreak = 0;
      }
    }

    String? overflowMessage;
    if (hasOverflow && overflowCount > 0) {
      overflowMessage =
          'Not all tasks fit. $overflowCount task(s) not scheduled. Consider moving them to another day.';
    }

    return SmartScheduleResult(
      slots: slots,
      hasOverflow: hasOverflow,
      overflowMessage: overflowMessage,
    );
  }

  /// Convenience helper: generate a schedule only within a specific time range
  /// chosen by the user. The organizer:
  /// - Only considers [selectedTasks]
  /// - Only schedules inside [rangeStartMinutes]..[rangeEndMinutes]
  /// - Still avoids [existingBlocks] on the calendar
  /// - Still uses user preferences (break duration / break-after) when provided
  static SmartScheduleResult generateScheduleForRange({
    required DateTime date,
    required List<TaskModel> selectedTasks,
    required int rangeStartMinutes,
    required int rangeEndMinutes,
    List<ExistingBlock> existingBlocks = const [],
    UserPreferencesModel? prefs,
  }) {
    if (selectedTasks.isEmpty) {
      return const SmartScheduleResult(slots: []);
    }

    // Build base config from preferences, then override the day window
    final baseConfig = SmartScheduleConfig.fromPreferences(prefs);
    final clampedStart = rangeStartMinutes.clamp(0, 24 * 60);
    final clampedEnd = rangeEndMinutes.clamp(0, 24 * 60);
    if (clampedEnd <= clampedStart) {
      return const SmartScheduleResult(slots: []);
    }

    final rangeConfig = SmartScheduleConfig(
      dayStartMinutes: clampedStart,
      dayEndMinutes: clampedEnd,
      breakDurationMinutes: baseConfig.breakDurationMinutes,
      breakAfterTaskMinutes: baseConfig.breakAfterTaskMinutes,
      snapMinutes: baseConfig.snapMinutes,
    );

    return generateSchedule(
      date: date,
      tasks: selectedTasks,
      config: rangeConfig,
      existingBlocks: existingBlocks,
    );
  }

  /// Find an adjusted [start, end] pair that does not overlap existing blocks,
  /// or null if no such window fits in the day.
  static (int, int)? _adjustForExistingBlocks({
    required int start,
    required int end,
    required int duration,
    required int dayStart,
    required int dayEnd,
    required int snapMinutes,
    required List<ExistingBlock> existingBlocks,
  }) {
    int candidateStart = start;
    int candidateEnd = end;

    while (true) {
      if (candidateStart >= dayEnd) return null;
      if (candidateEnd > dayEnd) {
        candidateEnd = dayEnd;
        candidateStart = candidateEnd - duration;
        if (candidateStart < dayStart) return null;
      }

      final overlapping = _findOverlappingBlock(
        existingBlocks,
        candidateStart,
        candidateEnd,
      );
      if (overlapping == null) {
        return (candidateStart, candidateEnd);
      }

      // Move start to the end of the overlapping block and try again.
      candidateStart = _snapTo(overlapping.endMinutes, snapMinutes);
      candidateEnd = candidateStart + duration;
    }
  }

  static ExistingBlock? _findOverlappingBlock(
    List<ExistingBlock> blocks,
    int start,
    int end,
  ) {
    for (final b in blocks) {
      if (b.startMinutes < end && b.endMinutes > start) {
        return b;
      }
    }
    return null;
  }

  /// Priority score: higher = schedule earlier. Importance and urgency 1-5.
  /// Overdue tasks get a boost so they appear earlier.
  static int _priorityScore(TaskModel t) {
    const weightI = 1;
    const weightU = 1;
    int score = t.importance * weightI + t.urgency * weightU;
    if (t.overdue) score += 10;
    return score;
  }

  /// Eisenhower matrix quadrant for a task.
  /// 1 = Do first (high importance, high urgency)
  /// 2 = Schedule (high importance, lower urgency)
  /// 3 = Delegate / quick (lower importance, high urgency)
  /// 4 = Eliminate / lowest value (everything else)
  static int _eisenhowerQuadrant(TaskModel t) {
    final i = t.importance;
    final u = t.urgency;

    final bool highImportance = i >= 4;
    final bool highUrgency = u >= 4;

    if (highImportance && highUrgency) return 1;
    if (highImportance) return 2;
    if (highUrgency) return 3;
    return 4;
  }

  /// Sort by priority (desc), then by duration (asc) to reduce fragmentation, then by createdAt.
  static List<TaskModel> _sortByPriority(List<TaskModel> tasks) {
    tasks.sort((a, b) {
      // 1) Eisenhower quadrant (lower = more important)
      final quadA = _eisenhowerQuadrant(a);
      final quadB = _eisenhowerQuadrant(b);
      if (quadA != quadB) return quadA.compareTo(quadB);

      // 2) Existing numeric priority score (higher first)
      final scoreA = _priorityScore(a);
      final scoreB = _priorityScore(b);
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);

      // 3) Shorter tasks earlier to reduce fragmentation
      final durA = a.duration;
      final durB = b.duration;
      if (durA != durB) return durA.compareTo(durB);

      // 4) Older tasks first
      return a.createdAt.compareTo(b.createdAt);
    });
    return tasks;
  }

  static int _snapTo(int minutes, int step) {
    final remainder = minutes % step;
    if (remainder == 0) return minutes;
    return minutes + (step - remainder);
  }
}
