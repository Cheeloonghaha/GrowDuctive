import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/category_model.dart';
import '../models/focus_session_model.dart';
import '../models/task_model.dart';

/// Aggregated task (productivity) analytics for the current user.
/// All counts and rates are for the current calendar week (Monday–Sunday).
class TaskAnalytics {
  final int totalTasks;
  final int completedTasks;
  final double completionRate; // 0.0 - 1.0
  /// Completed tasks per weekday: index 0 = Monday, 6 = Sunday.
  final List<int> weeklyCompleted;
  final List<CategoryCount> tasksByCategory;
  final int productivityScore; // 0-100

  const TaskAnalytics({
    required this.totalTasks,
    required this.completedTasks,
    required this.completionRate,
    required this.weeklyCompleted,
    required this.tasksByCategory,
    required this.productivityScore,
  });

  static const TaskAnalytics empty = TaskAnalytics(
    totalTasks: 0,
    completedTasks: 0,
    completionRate: 0,
    weeklyCompleted: [],
    tasksByCategory: [],
    productivityScore: 0,
  );
}

class CategoryCount {
  final String categoryId;
  final String categoryName;
  final int count;

  const CategoryCount({
    required this.categoryId,
    required this.categoryName,
    required this.count,
  });
}

/// Aggregated focus timer analytics for the current user.
/// All counts are for the current calendar week (Monday–Sunday).
class FocusAnalytics {
  final int totalSessions;
  final int totalFocusMinutes;
  final double averageFocusLengthMinutes;
  final int totalInterruptions;
  final int focusScore; // 0-100

  const FocusAnalytics({
    required this.totalSessions,
    required this.totalFocusMinutes,
    required this.averageFocusLengthMinutes,
    required this.totalInterruptions,
    required this.focusScore,
  });

  static const FocusAnalytics empty = FocusAnalytics(
    totalSessions: 0,
    totalFocusMinutes: 0,
    averageFocusLengthMinutes: 0,
    totalInterruptions: 0,
    focusScore: 0,
  );
}

class AnalyticsViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;
  DateTime _selectedWeek = DateTime.now();

  String? get userId => _userId;
  DateTime get selectedWeek => _selectedWeek;

  void setUserId(String? userId) {
    _userId = userId;
    _selectedWeek = DateTime.now();
    // Reset stream initialization flags when user changes
    _taskStreamInitialized = false;
    _focusStreamInitialized = false;
    // Cancel existing subscriptions
    _taskStreamSub?.cancel();
    _taskWeekSub?.cancel();
    _focusStreamSub?.cancel();
    _focusWeekSub?.cancel();
    notifyListeners();
  }

  /// Select a week by providing any date within that week.
  /// Future weeks are clamped to the current week (no viewing future weeks).
  void selectWeek(DateTime dateInWeek) {
    final now = DateTime.now();
    final selectedWeekStart = weekStart(dateInWeek);
    final currentWeekStart = weekStart(now);
    // Clamp to current week: do not allow selecting a week in the future
    if (selectedWeekStart.isAfter(currentWeekStart)) {
      dateInWeek = now;
    }
    // Only trigger update if week actually changed
    final newWeekStart = weekStart(dateInWeek);
    final prevWeekStart = weekStart(_selectedWeek);
    if (newWeekStart.year != prevWeekStart.year ||
        newWeekStart.month != prevWeekStart.month ||
        newWeekStart.day != prevWeekStart.day) {
      _selectedWeek = dateInWeek;
      _weekChangeController.add(_selectedWeek);
      notifyListeners();
    } else {
      // Same week, but still trigger refresh for tab switching
      _weekChangeController.add(_selectedWeek);
    }
  }

  /// Navigate to previous week.
  void previousWeek() {
    _selectedWeek = _selectedWeek.subtract(const Duration(days: 7));
    _weekChangeController.add(_selectedWeek);
    notifyListeners();
  }

  /// Whether the user can navigate to the next week (false when already at current week).
  bool get canGoToNextWeek => !isCurrentWeek;

  /// Navigate to next week. No-op if already at current week (no future weeks).
  void nextWeek() {
    if (isCurrentWeek) return;
    _selectedWeek = _selectedWeek.add(const Duration(days: 7));
    _weekChangeController.add(_selectedWeek);
    notifyListeners();
  }

  /// Jump to the current week.
  void goToCurrentWeek() {
    _selectedWeek = DateTime.now();
    _weekChangeController.add(_selectedWeek);
    notifyListeners();
  }

  /// Check if the selected week is the current week.
  bool get isCurrentWeek {
    final now = DateTime.now();
    final selectedMon = weekStart(_selectedWeek);
    final currentMon = weekStart(now);
    return selectedMon.year == currentMon.year &&
        selectedMon.month == currentMon.month &&
        selectedMon.day == currentMon.day;
  }

  /// Start of current week (Monday 00:00:00) in local time.
  static DateTime weekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    final monday = DateTime(date.year, date.month, date.day).subtract(Duration(days: daysFromMonday));
    return monday;
  }

  /// End of current week (Sunday 23:59:59.999) in local time.
  static DateTime weekEnd(DateTime date) {
    final end = weekStart(date).add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
    return end;
  }

  /// Human-readable label for a week, e.g. "Mon 3 Feb – Sun 9 Feb".
  static String weekLabel(DateTime dateInWeek) {
    final mon = weekStart(dateInWeek);
    final sun = mon.add(const Duration(days: 6));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_dayName(mon.weekday)} ${mon.day} ${months[mon.month - 1]} – ${_dayName(sun.weekday)} ${sun.day} ${months[sun.month - 1]}';
  }

  /// Human-readable label for the selected week.
  String get selectedWeekLabel => weekLabel(_selectedWeek);

  static String _dayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  final _weekChangeController = StreamController<DateTime>.broadcast();
  StreamSubscription<QuerySnapshot>? _taskStreamSub;
  StreamSubscription<DateTime>? _taskWeekSub;
  final _taskAnalyticsController = StreamController<TaskAnalytics>.broadcast();
  bool _taskStreamInitialized = false;

  /// Task analytics stream for the selected week (Mon–Sun). Updates when week or data changes.
  Stream<TaskAnalytics> get taskAnalyticsStream {
    if (_userId == null || _userId!.isEmpty) return Stream.value(TaskAnalytics.empty);
    final uid = _userId!;
    
    // Initialize subscriptions only once
    if (!_taskStreamInitialized) {
      final firestoreStream = _db
          .collection('tasks')
          .where('user_id', isEqualTo: uid)
          .snapshots();
      
      _taskStreamSub = firestoreStream.listen((_) => _computeAndEmitTaskAnalytics(uid));
      _taskWeekSub = _weekChangeController.stream.listen((_) => _computeAndEmitTaskAnalytics(uid));
      
      // Emit initial value
      _computeAndEmitTaskAnalytics(uid);
      _taskStreamInitialized = true;
    }
    
    return _taskAnalyticsController.stream;
  }

  Future<void> _computeAndEmitTaskAnalytics(String uid) async {
    final taskSnap = await _db
        .collection('tasks')
        .where('user_id', isEqualTo: uid)
        .get();
    final tasks = taskSnap.docs
        .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
        .toList();
    final categorySnap = await _db
        .collection('categories')
        .where('user_id', isEqualTo: uid)
        .get();
    final categories = <String, CategoryModel>{};
    for (final doc in categorySnap.docs) {
      final c = CategoryModel.fromMap(doc.data(), doc.id);
      categories[c.id] = c;
    }
    final analytics = _computeTaskAnalytics(tasks, categories);
    if (!_taskAnalyticsController.isClosed) {
      _taskAnalyticsController.add(analytics);
    }
  }

  TaskAnalytics _computeTaskAnalytics(
    List<TaskModel> tasks,
    Map<String, CategoryModel> categories,
  ) {
    final start = weekStart(_selectedWeek);
    final end = weekEnd(_selectedWeek);
    final weekTasks = tasks.where((t) => !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end)).toList();
    final total = weekTasks.length;
    final completed = weekTasks.where((t) => t.status == 'completed').toList();
    final completedCount = completed.length;
    final rate = total > 0 ? completedCount / total : 0.0;

    final weeklyCompleted = List<int>.filled(7, 0);
    for (final t in completed) {
      // Only use completedAt - skip tasks without completion date
      // Validate that completion date is within the selected week
      if (t.completedAt != null) {
        final completionDate = t.completedAt!;
        // Check if completion date is within the selected week range
        if (!completionDate.isBefore(start) && !completionDate.isAfter(end)) {
          final wd = completionDate.weekday;
          if (wd >= 1 && wd <= 7) weeklyCompleted[wd - 1]++;
        }
      }
    }

    final byCategory = <String, int>{};
    for (final t in weekTasks) {
      byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + 1;
    }

    final tasksByCategory = byCategory.entries
        .map((e) => CategoryCount(
              categoryId: e.key,
              categoryName: categories[e.key]?.name ?? 'Uncategorized',
              count: e.value,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final score = _productivityScore(rate, weeklyCompleted);
    return TaskAnalytics(
      totalTasks: total,
      completedTasks: completedCount,
      completionRate: rate,
      weeklyCompleted: weeklyCompleted,
      tasksByCategory: tasksByCategory,
      productivityScore: score,
    );
  }

  /// Productivity score (0–100): rewards completion rate, number of days with
  /// completed tasks, and total tasks. More tasks and more active days = higher score.
  /// No hardcoded task cap; volume uses diminishing returns so score scales with activity.
  int _productivityScore(double completionRate, List<int> weeklyCompleted) {
    final weeklyTotal = weeklyCompleted.reduce((a, b) => a + b);
    final daysWithActivity = weeklyCompleted.where((c) => c > 0).length;

    // Completion rate: up to 40 pts (finish what you start)
    final completionPart = completionRate * 40;

    // Consistency: up to 30 pts (active on more days in the week)
    final daysPart = (daysWithActivity / 7) * 30;

    // Volume: up to 30 pts (more tasks = higher; diminishing returns, no fixed cap)
    final volumePart = weeklyTotal > 0 ? 30 * (1 - 1 / (1 + weeklyTotal)) : 0.0;

    final raw = completionPart + daysPart + volumePart;
    return raw.round().clamp(0, 100);
  }

  StreamSubscription<QuerySnapshot>? _focusStreamSub;
  StreamSubscription<DateTime>? _focusWeekSub;
  final _focusAnalyticsController = StreamController<FocusAnalytics>.broadcast();
  bool _focusStreamInitialized = false;

  /// Focus analytics stream for the selected week (Mon–Sun). Updates when week or data changes.
  Stream<FocusAnalytics> get focusAnalyticsStream {
    if (_userId == null || _userId!.isEmpty) return Stream.value(FocusAnalytics.empty);
    final uid = _userId!;
    
    // Initialize subscriptions only once
    if (!_focusStreamInitialized) {
      final firestoreStream = _db
          .collection('focus_sessions')
          .where('user_id', isEqualTo: uid)
          .snapshots();
      
      _focusStreamSub = firestoreStream.listen((_) => _computeAndEmitFocusAnalytics(uid));
      _focusWeekSub = _weekChangeController.stream.listen((_) => _computeAndEmitFocusAnalytics(uid));
      
      // Emit initial value
      _computeAndEmitFocusAnalytics(uid);
      _focusStreamInitialized = true;
    }
    
    return _focusAnalyticsController.stream;
  }

  Future<void> _computeAndEmitFocusAnalytics(String uid) async {
    final snap = await _db
        .collection('focus_sessions')
        .where('user_id', isEqualTo: uid)
        .get();
    final sessions = snap.docs
        .map((doc) => FocusSessionModel.fromMap(doc.data(), doc.id))
        .toList();
    final analytics = _computeFocusAnalytics(sessions);
    if (!_focusAnalyticsController.isClosed) {
      _focusAnalyticsController.add(analytics);
    }
  }

  FocusAnalytics _computeFocusAnalytics(List<FocusSessionModel> sessions) {
    final start = weekStart(_selectedWeek);
    final end = weekEnd(_selectedWeek);
    final inWeek = sessions.where((s) {
      final d = s.startedAt;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
    final totalSessions = inWeek.length;
    final totalSeconds = inWeek.fold<int>(0, (s, x) => s + x.durationSeconds);
    final totalFocusMinutes = totalSeconds ~/ 60;
    final avgMinutes = totalSessions > 0 ? totalSeconds / 60 / totalSessions : 0.0;
    final totalInterruptions = inWeek.where((s) => s.interrupted).length;
    final completedCount = inWeek.where((s) => s.completed).length;
    final completionRate = totalSessions > 0 ? completedCount / totalSessions : 0.0;
    final score = _focusScore(
      totalMinutes: totalFocusMinutes,
      completionRate: completionRate,
      interruptionRate: totalSessions > 0 ? totalInterruptions / totalSessions : 0,
    );
    return FocusAnalytics(
      totalSessions: totalSessions,
      totalFocusMinutes: totalFocusMinutes,
      averageFocusLengthMinutes: avgMinutes,
      totalInterruptions: totalInterruptions,
      focusScore: score,
    );
  }

  int _focusScore({
    required int totalMinutes,
    required double completionRate,
    required double interruptionRate,
  }) {
    // 125 min = 5 × 25 min (5 Pomodoro focus sessions) — full points if user achieves at least 5 focus sessions per week
    final timeScore = (totalMinutes.clamp(0, 125) / 125) * 40;
    final completeScore = completionRate * 35;
    // Up to 25 pts for no interruptions; 0 pts when all sessions interrupted (so max total = 40+35+25 = 100)
    final interruptionScore = 25 * (1.0 - interruptionRate);
    final raw = (timeScore + completeScore + interruptionScore).clamp(0.0, 100.0);
    return raw.round();
  }

  @override
  void dispose() {
    _taskStreamSub?.cancel();
    _taskWeekSub?.cancel();
    _focusStreamSub?.cancel();
    _focusWeekSub?.cancel();
    _taskAnalyticsController.close();
    _focusAnalyticsController.close();
    _weekChangeController.close();
    super.dispose();
  }
}
