import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_preferences_model.dart';

class UserPreferencesViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;

  /// Stable stream per signed-in user so [StreamBuilder] does not resubscribe every frame.
  Stream<UserPreferencesModel?>? _cachedPrefsStream;
  String? _cachedPrefsStreamUserId;

  void setUserId(String? userId) {
    if (_userId != userId) {
      _cachedPrefsStream = null;
      _cachedPrefsStreamUserId = null;
      _optimisticTheme = null;
    }
    _userId = userId;
    notifyListeners();
  }

  /// While Firestore syncs, we show this theme immediately for responsive UI.
  String? _optimisticTheme;

  /// Resolved theme for UI: optimistic tap first, then prefs stream, then default.
  String themeResolved(String? prefsTheme) {
    if (_optimisticTheme != null) return _optimisticTheme!;
    return prefsTheme ?? 'light';
  }

  String? get userId => _userId;

  static const String _collection = 'user_preferences';

  /// Stream of current user's preferences. Returns null when logged out or doc missing.
  Stream<UserPreferencesModel?> get preferencesStream {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      return Stream<UserPreferencesModel?>.value(null);
    }
    if (_cachedPrefsStreamUserId != uid || _cachedPrefsStream == null) {
      _cachedPrefsStreamUserId = uid;
      _cachedPrefsStream = _db.collection(_collection).doc(uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        final prefs = UserPreferencesModel.fromMap(doc.data()!, doc.id);
        if (_optimisticTheme != null && prefs.theme == _optimisticTheme) {
          _optimisticTheme = null;
        }
        return prefs;
      });
    }
    return _cachedPrefsStream!;
  }

  /// One-time fetch. Returns null if doc does not exist.
  Future<UserPreferencesModel?> fetchPreferences() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return null;
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserPreferencesModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('UserPreferencesViewModel fetchPreferences: $e');
      return null;
    }
  }

  /// Ensure the user has a preferences document. Creates one with defaults if missing.
  /// Call after login so subsequent fetch/stream return a doc.
  Future<void> ensureDefaults() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final ref = _db.collection(_collection).doc(uid);
      final doc = await ref.get();
      if (!doc.exists || doc.data() == null) {
        final now = DateTime.now();
        final defaults = UserPreferencesModel(
          userId: uid,
          updatedAt: now,
        );
        await ref.set(defaults.toMap());
        debugPrint('UserPreferencesViewModel: created default prefs for user $uid');
      }
    } catch (e) {
      debugPrint('UserPreferencesViewModel ensureDefaults: $e');
    }
  }

  /// Update one or more preference fields. Merges with existing doc.
  Future<void> update(Map<String, dynamic> fields) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    try {
      final updateData = Map<String, dynamic>.from(fields)
        ..['updated_at'] = Timestamp.fromDate(DateTime.now());
      await _db.collection(_collection).doc(uid).set(updateData, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      debugPrint('UserPreferencesViewModel update: $e');
      rethrow;
    }
  }

  /// Update Smart Task Organizer break settings.
  Future<void> updateScheduleBreakPreferences({
    required int breakDurationMinutes,
    required int breakAfterTaskMinutes,
  }) async {
    await update({
      'break_duration_minutes': breakDurationMinutes,
      'break_after_task_minutes': breakAfterTaskMinutes,
    });
  }

  /// Update Focus Timer preferences.
  Future<void> updateFocusTimerPreferences({
    String? defaultTimerId,
    bool? timerSoundEnabled,
    bool? timerVibrationEnabled,
  }) async {
    final map = <String, dynamic>{};
    if (defaultTimerId != null) map['default_timer_id'] = defaultTimerId;
    if (timerSoundEnabled != null) map['timer_sound_enabled'] = timerSoundEnabled;
    if (timerVibrationEnabled != null) map['timer_vibration_enabled'] = timerVibrationEnabled;
    if (map.isEmpty) return;
    await update(map);
  }

  /// Update theme (applies optimistically, then persists to Firestore).
  Future<void> updateTheme(String theme) async {
    _optimisticTheme = theme;
    notifyListeners();
    try {
      await update({'theme': theme});
    } catch (e) {
      _optimisticTheme = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Update reminder preferences.
  Future<void> updateReminderPreferences({
    bool? remindersEnabled,
    int? defaultReminderMinutesBefore,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
  }) async {
    final map = <String, dynamic>{};
    if (remindersEnabled != null) map['reminders_enabled'] = remindersEnabled;
    if (defaultReminderMinutesBefore != null) {
      map['default_reminder_minutes_before'] = defaultReminderMinutesBefore;
    }
    if (quietHoursStartMinutes != null) map['quiet_hours_start_minutes'] = quietHoursStartMinutes;
    if (quietHoursEndMinutes != null) map['quiet_hours_end_minutes'] = quietHoursEndMinutes;
    if (map.isEmpty) return;
    await update(map);
  }

  /// Update week start (1 = Monday, 7 = Sunday).
  Future<void> updateWeekStartsOn(int weekStartsOn) async {
    await update({'week_starts_on': weekStartsOn});
  }
}
