import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/focus_session_model.dart';
import '../models/focus_timer_model.dart';

/// Phases for the basic Pomodoro timer.
enum FocusTimerPhase {
  focus,
  shortBreak,
  longBreak,
}

/// Display status for a focus session in the UI.
/// - [completed] and [interrupted]: show as "Interrupted" (orange).
/// - [completed] and not [interrupted]: show as "Completed" (green).
/// - Not [completed]: show as "Incomplete" (grey), even if [interrupted] is true.
enum FocusSessionDisplayStatus {
  completed,
  interrupted,
  incomplete,
}

/// Returns the display status for a session. Use this from the view;
/// logic: completed+interrupted → interrupted, completed+!interrupted → completed, !completed → incomplete.
FocusSessionDisplayStatus getSessionDisplayStatus(FocusSessionModel session) {
  if (!session.completed) return FocusSessionDisplayStatus.incomplete;
  if (session.interrupted) return FocusSessionDisplayStatus.interrupted;
  return FocusSessionDisplayStatus.completed;
}

class FocusTimerViewModel extends ChangeNotifier {
  static const int _defaultFocusSeconds = 25 * 60;
  static const int _defaultShortBreakSeconds = 5 * 60;
  static const int _defaultLongBreakSeconds = 15 * 60;

  /// For testing: session counts as "completed" if duration >= this (seconds).
  static const int _minCompletedSeconds = 60;

  /// After this many completed focus sessions, auto-switch to Long Break instead of Short Break.
  static const int focusCyclesBeforeLongBreak = 4;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  FocusTimerPhase _phase = FocusTimerPhase.focus;
  int _remainingSeconds = _defaultFocusSeconds;
  bool _isRunning = false;
  Timer? _ticker;

  /// Number of focus sessions completed in the current cycle (resets after a long break).
  int _focusCyclesCompleted = 0;
  int get focusCyclesCompleted => _focusCyclesCompleted;

  /// Called when focus ends and we've switched to Short/Long Break; show prompt to start or not.
  void Function(FocusTimerPhase breakPhase)? onPromptStartBreak;

  /// When current focus run started (null if not in a run or not focus phase).
  DateTime? _sessionStartedAt;
  /// Planned duration for current run (for completed logic: half of this; testing uses _minCompletedSeconds).
  int _plannedDurationSeconds = _defaultFocusSeconds;

  /// Custom timers for current user.
  List<FocusTimerModel> _customTimers = [];
  /// Selected custom timer id; null = use default 25/5/15.
  String? _selectedTimerId;

  StreamSubscription<List<FocusTimerModel>>? _customTimersSub;
  Stream<int>? _sessionsTodayStreamCache;
  Stream<List<FocusSessionModel>>? _sessionsTodayListStreamCache;

  List<FocusTimerModel> get customTimers => List.unmodifiable(_customTimers);
  String? get selectedTimerId => _selectedTimerId;
  FocusTimerPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;

  void setUserId(String? userId) {
    _customTimersSub?.cancel();
    _sessionsTodayStreamCache = null;
    _sessionsTodayListStreamCache = null;
    _userId = userId;
    _customTimers = [];
    _selectedTimerId = null;
    if (userId != null && userId.isNotEmpty) {
      _customTimersSub = customTimersStream.listen(_loadCustomTimersFromStream);
    } else {
      _customTimersSub = null;
    }
    notifyListeners();
  }

  String? get userId => _userId;

  /// Stream of custom timers for the current user (newest first, sorted in memory to avoid composite index).
  Stream<List<FocusTimerModel>> get customTimersStream {
    if (_userId == null || _userId!.isEmpty) return Stream.value([]);
    return _db
        .collection('focus_timers')
        .where('user_id', isEqualTo: _userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => FocusTimerModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Today's date as YYYY-MM-DD in device local time (for comparison with stored session_date).
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Normalize any date to YYYY-MM-DD from DateTime (device local).
  static String _dateToYyyyMmDd(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Stream of completed focus sessions count for today ("Focus Sessions Today").
  ///
  /// Only sessions with [completed] == true and session date today are counted.
  /// Uses [session_date] (string or Timestamp) with fallback to [started_at].
  /// Cached per userId so StreamBuilder keeps a stable subscription.
  Stream<int> get sessionsTodayStream {
    if (_userId == null || _userId!.isEmpty) return Stream.value(0);
    _sessionsTodayStreamCache ??= _buildSessionsTodayStream();
    return _sessionsTodayStreamCache!;
  }

  Stream<int> _buildSessionsTodayStream() {
    final todayStr = _todayString();
    final uid = _userId!;
    return _db
        .collection('focus_sessions')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['completed'] != true) continue;
        String? sessionDateStr = _sessionDateStringFromDoc(data);
        if (sessionDateStr == null || sessionDateStr != todayStr) continue;
        count++;
      }
      return count;
    });
  }

  /// List of all focus sessions for today (all statuses: completed, incomplete, interrupted).
  /// Newest first. Cached per userId.
  Stream<List<FocusSessionModel>> get sessionsTodayListStream {
    if (_userId == null || _userId!.isEmpty) return Stream.value([]);
    _sessionsTodayListStreamCache ??= _buildSessionsTodayListStream();
    return _sessionsTodayListStreamCache!;
  }

  Stream<List<FocusSessionModel>> _buildSessionsTodayListStream() {
    final todayStr = _todayString();
    final uid = _userId!;
    return _db
        .collection('focus_sessions')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = <FocusSessionModel>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sessionDateStr = _sessionDateStringFromDoc(data);
        if (sessionDateStr == null || sessionDateStr != todayStr) continue;
        list.add(FocusSessionModel.fromMap(data, doc.id));
      }
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    });
  }

  /// Extracts session date as YYYY-MM-DD from doc; falls back to started_at if session_date missing.
  String? _sessionDateStringFromDoc(Map<String, dynamic> data) {
    final sessionDateRaw = data['session_date'];
    if (sessionDateRaw is String) {
      final parsed = DateTime.tryParse(sessionDateRaw);
      return parsed != null ? _dateToYyyyMmDd(parsed) : sessionDateRaw.length >= 10 ? sessionDateRaw.substring(0, 10) : null;
    }
    if (sessionDateRaw is Timestamp) {
      return _dateToYyyyMmDd(sessionDateRaw.toDate());
    }
    final startedRaw = data['started_at'];
    if (startedRaw != null) {
      if (startedRaw is Timestamp) {
        return _dateToYyyyMmDd(startedRaw.toDate());
      }
      if (startedRaw is String) {
        final parsed = DateTime.tryParse(startedRaw);
        if (parsed != null) return _dateToYyyyMmDd(parsed);
      }
    }
    return null;
  }

  void _loadCustomTimersFromStream(List<FocusTimerModel> list) {
    _customTimers = list;
    // If selected timer was deleted, clear selection.
    if (_selectedTimerId != null &&
        !_customTimers.any((t) => t.id == _selectedTimerId)) {
      _selectedTimerId = null;
    }
    // When no timer is selected but user has timers, auto-select the default (is_default: true) or first.
    if (_selectedTimerId == null && _customTimers.isNotEmpty) {
      FocusTimerModel? defaultTimer;
      for (final t in _customTimers) {
        if (t.isDefault) {
          defaultTimer = t;
          break;
        }
      }
      _selectedTimerId = (defaultTimer ?? _customTimers.first).id;
    }
    // If list is empty, ensure default timer exists (will trigger stream re-emit).
    if (_customTimers.isEmpty && _userId != null && _userId!.isNotEmpty) {
      ensureDefaultTimer();
    }
    // When the selected timer is updated (e.g. duration edited), sync current phase duration.
    if (_selectedTimerId != null) {
      final newDuration = _durationForPhase(_phase);
      _remainingSeconds = newDuration;
      if (_phase == FocusTimerPhase.focus) {
        _plannedDurationSeconds = newDuration;
      }
    }
    notifyListeners();
  }

  void setCustomTimers(List<FocusTimerModel> list) {
    _loadCustomTimersFromStream(list);
  }

  void selectTimer(String? timerId) {
    _selectedTimerId = timerId;
    _stopTimer();
    _remainingSeconds = _durationForPhase(_phase);
    _isRunning = false;
    notifyListeners();
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Total duration in seconds for the current phase (for progress bar).
  int get currentPhaseDuration => _durationForPhase(_phase);

  FocusTimerModel? get _selectedTimer {
    if (_selectedTimerId == null) return null;
    for (final t in _customTimers) {
      if (t.id == _selectedTimerId) return t;
    }
    return null;
  }

  int _durationForPhase(FocusTimerPhase phase) {
    final timer = _selectedTimer;
    if (timer != null) {
      switch (phase) {
        case FocusTimerPhase.focus:
          return timer.focusDurationSeconds;
        case FocusTimerPhase.shortBreak:
          return timer.shortBreakSeconds;
        case FocusTimerPhase.longBreak:
          return timer.longBreakSeconds;
      }
    }
    switch (phase) {
      case FocusTimerPhase.focus:
        return _defaultFocusSeconds;
      case FocusTimerPhase.shortBreak:
        return _defaultShortBreakSeconds;
      case FocusTimerPhase.longBreak:
        return _defaultLongBreakSeconds;
    }
  }

  void selectPhase(FocusTimerPhase phase) {
    _stopTimer();
    _sessionStartedAt = null;
    _phase = phase;
    _remainingSeconds = _durationForPhase(phase);
    _plannedDurationSeconds = _durationForPhase(phase);
    _isRunning = false;
    notifyListeners();
  }

  void start() {
    if (_isRunning) return;

    if (_remainingSeconds <= 0) {
      _remainingSeconds = _durationForPhase(_phase);
      _plannedDurationSeconds = _remainingSeconds;
    }

    if (_phase == FocusTimerPhase.focus && _sessionStartedAt == null) {
      _sessionStartedAt = DateTime.now();
      _plannedDurationSeconds = _durationForPhase(FocusTimerPhase.focus);
    }

    _isRunning = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _onTimerReachedZero();
      }
    });
    notifyListeners();
  }

  void _onTimerReachedZero() {
    _stopTimer();
    if (_phase == FocusTimerPhase.focus && _sessionStartedAt != null) {
      final startedAt = _sessionStartedAt!;
      _sessionStartedAt = null;
      _saveSession(
        startedAt: startedAt,
        endedAt: DateTime.now(),
        interrupted: false,
        completed: true,
      );
      _focusCyclesCompleted++;
      final nextBreak = _focusCyclesCompleted % focusCyclesBeforeLongBreak == 0
          ? FocusTimerPhase.longBreak
          : FocusTimerPhase.shortBreak;
      _phase = nextBreak;
      _remainingSeconds = _durationForPhase(_phase);
      _isRunning = false;
      notifyListeners();
      onPromptStartBreak?.call(_phase);
    } else if (_phase == FocusTimerPhase.shortBreak ||
        _phase == FocusTimerPhase.longBreak) {
      if (_phase == FocusTimerPhase.longBreak) {
        _focusCyclesCompleted = 0;
      }
      _phase = FocusTimerPhase.focus;
      _remainingSeconds = _durationForPhase(_phase);
      _sessionStartedAt = null;
      _isRunning = false;
      notifyListeners();
    } else {
      _isRunning = false;
      notifyListeners();
    }
  }

  void pause() {
    if (!_isRunning) return;
    if (_phase == FocusTimerPhase.focus && _sessionStartedAt != null) {
      final startedAt = _sessionStartedAt!;
      _sessionStartedAt = null;
      final endedAt = DateTime.now();
      final elapsed = endedAt.difference(startedAt).inSeconds;
      _saveSession(
        startedAt: startedAt,
        endedAt: endedAt,
        interrupted: true,
        completed: elapsed >= _minCompletedSeconds,
      );
    }
    _stopTimer();
    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    if (_phase == FocusTimerPhase.focus && _sessionStartedAt != null) {
      final startedAt = _sessionStartedAt!;
      _sessionStartedAt = null;
      final endedAt = DateTime.now();
      final elapsed = endedAt.difference(startedAt).inSeconds;
      _saveSession(
        startedAt: startedAt,
        endedAt: endedAt,
        interrupted: true,
        completed: elapsed >= _minCompletedSeconds,
      );
    }
    _stopTimer();
    _remainingSeconds = _durationForPhase(_phase);
    _isRunning = false;
    notifyListeners();
  }

  Future<void> _saveSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required bool interrupted,
    required bool completed,
  }) async {
    if (_userId == null || _userId!.isEmpty) return;
    final durationSeconds = endedAt.difference(startedAt).inSeconds;
    final sessionDate = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final session = FocusSessionModel(
      id: '',
      userId: _userId!,
      timerId: _selectedTimerId,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
      endedAt: endedAt,
      sessionDate: sessionDate,
      interrupted: interrupted,
      completed: completed,
    );
    try {
      await _db.collection('focus_sessions').add(session.toMap());
    } catch (e) {
      print('FocusTimerViewModel: failed to save session: $e');
    }
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
  }

  // --- Custom timer CRUD ---

  /// Creates a custom timer. Returns the new document id, or throws on error.
  Future<String> createCustomTimer({
    required String name,
    required int focusMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
  }) async {
    if (_userId == null || _userId!.isEmpty) {
      throw StateError('Not logged in. Cannot create timer without user id.');
    }
    final now = DateTime.now();
    final model = FocusTimerModel(
      id: '',
      userId: _userId!,
      name: name,
      focusDurationSeconds: focusMinutes * 60,
      shortBreakSeconds: shortBreakMinutes * 60,
      longBreakSeconds: longBreakMinutes * 60,
      createdAt: now,
      updatedAt: now,
      isDefault: false,
    );
    final data = model.toMap();
    assert(data.containsKey('user_id') && data['user_id'] == _userId);
    final ref = await _db.collection('focus_timers').add(data);
    print('FocusTimerViewModel: created timer ${ref.id}');
    return ref.id;
  }

  /// Ensure the current user has at least one focus timer (default "Pomodoro timer"). Call after login.
  Future<void> ensureDefaultTimer() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      final snapshot = await _db
          .collection('focus_timers')
          .where('user_id', isEqualTo: _userId)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return; // already has at least one
      final now = DateTime.now();
      final defaultModel = FocusTimerModel(
        id: '',
        userId: _userId!,
        name: 'Pomodoro timer',
        focusDurationSeconds: 25 * 60,
        shortBreakSeconds: 5 * 60,
        longBreakSeconds: 15 * 60,
        createdAt: now,
        updatedAt: now,
        isDefault: true,
      );
      await _db.collection('focus_timers').add(defaultModel.toMap());
      print('FocusTimerViewModel: created default Pomodoro timer for user $_userId');
    } catch (e) {
      print('FocusTimerViewModel: ensureDefaultTimer failed: $e');
    }
  }

  /// Updates an existing custom timer. Throws on error.
  Future<void> updateCustomTimer(
    String id, {
    String? name,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
  }) async {
    final updates = <String, dynamic>{'updated_at': FieldValue.serverTimestamp()};
    if (name != null) updates['name'] = name;
    if (focusMinutes != null) updates['focus_duration_seconds'] = focusMinutes * 60;
    if (shortBreakMinutes != null) updates['short_break_seconds'] = shortBreakMinutes * 60;
    if (longBreakMinutes != null) updates['long_break_seconds'] = longBreakMinutes * 60;
    await _db.collection('focus_timers').doc(id).update(updates);
  }

  Future<void> deleteCustomTimer(String id) async {
    try {
      await _db.collection('focus_timers').doc(id).delete();
      if (_selectedTimerId == id) {
        _selectedTimerId = null;
        _remainingSeconds = _durationForPhase(_phase);
        notifyListeners();
      }
    } catch (e) {
      print('FocusTimerViewModel: deleteCustomTimer failed: $e');
    }
  }

  @override
  void dispose() {
    _customTimersSub?.cancel();
    _stopTimer();
    super.dispose();
  }
}
