import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences — one document per user in `user_preferences` collection.
/// Document ID = user ID (Firebase Auth UID).
class UserPreferencesModel {
  final String userId;
  // Smart Task Organizer
  final int breakDurationMinutes;
  /// Insert a break after every [breakAfterTaskMinutes] minutes of task time. 0 = break after every task.
  final int breakAfterTaskMinutes;
  // Focus Timer
  final String? defaultTimerId;
  final bool timerSoundEnabled;
  final bool timerVibrationEnabled;
  // Calendar & week
  /// 1 = Monday, 7 = Sunday.
  final int weekStartsOn;
  // Reminders
  final bool remindersEnabled;
  final int defaultReminderMinutesBefore;
  final int? quietHoursStartMinutes;
  final int? quietHoursEndMinutes;
  // Appearance
  /// "light" | "dark" | "system"
  final String theme;
  // Metadata
  final DateTime updatedAt;

  const UserPreferencesModel({
    required this.userId,
    this.breakDurationMinutes = 10,
    this.breakAfterTaskMinutes = 0,
    this.defaultTimerId,
    this.timerSoundEnabled = true,
    this.timerVibrationEnabled = true,
    this.weekStartsOn = 1,
    this.remindersEnabled = true,
    this.defaultReminderMinutesBefore = 15,
    this.quietHoursStartMinutes,
    this.quietHoursEndMinutes,
    this.theme = 'system',
    required this.updatedAt,
  });

  static const int weekMonday = 1;
  static const int weekSunday = 7;

  factory UserPreferencesModel.fromMap(Map<String, dynamic> data, String documentId) {
    final updatedRaw = data['updated_at'];
    DateTime updated = DateTime.now();
    if (updatedRaw != null) {
      if (updatedRaw is Timestamp) {
        updated = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        updated = DateTime.tryParse(updatedRaw) ?? DateTime.now();
      }
    }
    return UserPreferencesModel(
      userId: data['user_id'] ?? documentId,
      breakDurationMinutes: _toInt(data['break_duration_minutes'], 10),
      breakAfterTaskMinutes: _toInt(data['break_after_task_minutes'], 0),
      defaultTimerId: data['default_timer_id'] as String?,
      timerSoundEnabled: data['timer_sound_enabled'] ?? true,
      timerVibrationEnabled: data['timer_vibration_enabled'] ?? true,
      weekStartsOn: _toInt(data['week_starts_on'], 1),
      remindersEnabled: data['reminders_enabled'] ?? true,
      defaultReminderMinutesBefore: _toInt(data['default_reminder_minutes_before'], 15),
      quietHoursStartMinutes: data['quiet_hours_start_minutes'] != null
          ? (data['quiet_hours_start_minutes'] as num).toInt()
          : null,
      quietHoursEndMinutes: data['quiet_hours_end_minutes'] != null
          ? (data['quiet_hours_end_minutes'] as num).toInt()
          : null,
      theme: data['theme'] as String? ?? 'system',
      updatedAt: updated,
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'break_duration_minutes': breakDurationMinutes,
      'break_after_task_minutes': breakAfterTaskMinutes,
      'default_timer_id': defaultTimerId,
      'timer_sound_enabled': timerSoundEnabled,
      'timer_vibration_enabled': timerVibrationEnabled,
      'week_starts_on': weekStartsOn,
      'reminders_enabled': remindersEnabled,
      'default_reminder_minutes_before': defaultReminderMinutesBefore,
      'quiet_hours_start_minutes': quietHoursStartMinutes,
      'quiet_hours_end_minutes': quietHoursEndMinutes,
      'theme': theme,
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  UserPreferencesModel copyWith({
    String? userId,
    int? breakDurationMinutes,
    int? breakAfterTaskMinutes,
    String? defaultTimerId,
    bool? timerSoundEnabled,
    bool? timerVibrationEnabled,
    int? weekStartsOn,
    bool? remindersEnabled,
    int? defaultReminderMinutesBefore,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
    String? theme,
    DateTime? updatedAt,
  }) {
    return UserPreferencesModel(
      userId: userId ?? this.userId,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      breakAfterTaskMinutes: breakAfterTaskMinutes ?? this.breakAfterTaskMinutes,
      defaultTimerId: defaultTimerId ?? this.defaultTimerId,
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      timerVibrationEnabled: timerVibrationEnabled ?? this.timerVibrationEnabled,
      weekStartsOn: weekStartsOn ?? this.weekStartsOn,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      defaultReminderMinutesBefore:
          defaultReminderMinutesBefore ?? this.defaultReminderMinutesBefore,
      quietHoursStartMinutes: quietHoursStartMinutes ?? this.quietHoursStartMinutes,
      quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
      theme: theme ?? this.theme,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
