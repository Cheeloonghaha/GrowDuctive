import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences — one document per user in `user_preferences` collection.
/// Document ID = user ID (Firebase Auth UID).
class UserPreferencesModel {
  final String userId;
  // Smart Task Organizer
  final int breakDurationMinutes;
  /// Insert a break after every [breakAfterTaskMinutes] minutes of task time. 0 = break after every task.
  final int breakAfterTaskMinutes;
  // Appearance
  /// "light" | "dark" | "system"
  final String theme;
  // Metadata
  final DateTime updatedAt;

  const UserPreferencesModel({
    required this.userId,
    this.breakDurationMinutes = 10,
    this.breakAfterTaskMinutes = 0,
    this.theme = 'light',
    required this.updatedAt,
  });

  /// Calendar week strip: Monday-based weeks (not persisted; UI default only).
  static const int weekMonday = 1;
  /// Sunday-based weeks (not persisted; for helpers that compare to this value).
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
      theme: data['theme'] as String? ?? 'light',
      updatedAt: updated,
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return defaultValue;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'break_duration_minutes': breakDurationMinutes,
      'break_after_task_minutes': breakAfterTaskMinutes,
      'theme': theme,
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  UserPreferencesModel copyWith({
    String? userId,
    int? breakDurationMinutes,
    int? breakAfterTaskMinutes,
    String? theme,
    DateTime? updatedAt,
  }) {
    return UserPreferencesModel(
      userId: userId ?? this.userId,
      breakDurationMinutes: breakDurationMinutes ?? this.breakDurationMinutes,
      breakAfterTaskMinutes: breakAfterTaskMinutes ?? this.breakAfterTaskMinutes,
      theme: theme ?? this.theme,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
