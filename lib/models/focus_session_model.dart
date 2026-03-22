import 'package:cloud_firestore/cloud_firestore.dart';

/// A single completed or in-progress focus session.
///
/// Notes on fields:
/// - You *can* derive duration and date from start/end times, but we keep
///   `durationSeconds` for quick queries/aggregation, and `startedAt` so you
///   always know when the session happened.
/// - `endedAt` is optional while a session is running.
class FocusSessionModel {
  /// Document id in `focus_sessions` collection.
  final String id;

  /// Firebase Auth UID (user_id FK).
  final String userId;

  /// Optional FK to `focus_timers/{timerId}` (null for default timer).
  final String? timerId;

  /// Total session duration in seconds (actual, not just planned).
  final int durationSeconds;

  /// When the session started.
  final DateTime startedAt;

  /// When the session ended (null if still running / interrupted).
  final DateTime? endedAt;

  /// Convenience field: calendar day (YYYY-MM-DD at midnight) for grouping.
  final DateTime sessionDate;

  /// True if the user paused or reset before the timer reached zero.
  final bool interrupted;

  /// True if the session counted as "completed" (e.g. ran at least half of planned time).
  /// For testing: true when durationSeconds >= 60. Later can use half of planned duration.
  final bool completed;

  FocusSessionModel({
    required this.id,
    required this.userId,
    required this.timerId,
    required this.durationSeconds,
    required this.startedAt,
    required this.endedAt,
    required this.sessionDate,
    required this.interrupted,
    required this.completed,
  });

  factory FocusSessionModel.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final startedRaw = data['started_at'];
    final endedRaw = data['ended_at'];
    final dateRaw = data['session_date'];

    DateTime started = DateTime.now();
    if (startedRaw != null) {
      if (startedRaw is Timestamp) {
        started = startedRaw.toDate();
      } else if (startedRaw is String) {
        started = DateTime.tryParse(startedRaw) ?? DateTime.now();
      }
    }

    DateTime? ended;
    if (endedRaw != null) {
      if (endedRaw is Timestamp) {
        ended = endedRaw.toDate();
      } else if (endedRaw is String) {
        ended = DateTime.tryParse(endedRaw);
      }
    }

    // Prefer calendar date string (YYYY-MM-DD) to avoid timezone issues; fallback to Timestamp or started date.
    DateTime sessionDate = DateTime(started.year, started.month, started.day);
    if (dateRaw != null) {
      if (dateRaw is String) {
        final parsed = DateTime.tryParse(dateRaw);
        sessionDate = parsed ?? DateTime(started.year, started.month, started.day);
      } else if (dateRaw is Timestamp) {
        sessionDate = dateRaw.toDate();
      }
    }

    return FocusSessionModel(
      id: documentId,
      userId: data['user_id'] ?? '',
      timerId: data['timer_id'],
      durationSeconds: data['duration_seconds'] ?? 0,
      startedAt: started,
      endedAt: ended,
      sessionDate: sessionDate,
      interrupted: data['interrupted'] ?? false,
      completed: data['completed'] ?? false,
    );
  }

  /// Calendar date as YYYY-MM-DD (local date at save) to avoid timezone shifts.
  static String sessionDateToStorage(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'timer_id': timerId,
      'duration_seconds': durationSeconds,
      'started_at': Timestamp.fromDate(startedAt),
      'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'session_date': sessionDateToStorage(sessionDate),
      'interrupted': interrupted,
      'completed': completed,
    };
  }

  FocusSessionModel copyWith({
    String? id,
    String? userId,
    String? timerId,
    int? durationSeconds,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? sessionDate,
    bool? interrupted,
    bool? completed,
  }) {
    return FocusSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timerId: timerId ?? this.timerId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      sessionDate: sessionDate ?? this.sessionDate,
      interrupted: interrupted ?? this.interrupted,
      completed: completed ?? this.completed,
    );
  }
}

