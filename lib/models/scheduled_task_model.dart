import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a task scheduled on the calendar (one instance in a time slot).
/// Follows ERD: Task + ScheduledTask; one Task can have many ScheduledTasks.
class ScheduledTaskModel {
  String id; // scheduled_task_id (PK)
  String taskId; // task_id (FK → tasks)
  String userId; // user_id (FK)
  String taskName; // task title for easy identification in Firestore
  DateTime scheduleDate; // which day (date only)
  int startTime; // minutes from midnight (e.g. 540 = 09:00)
  int endTime; // minutes from midnight (e.g. 630 = 10:30)
  /// Mirrors the associated task status ("pending" or "completed") for coloring/time-block state.
  String status;
  /// Per-scheduled-instance reminder offsets (minutes before start). Empty = use user default.
  List<int> reminderOffsetsMinutes;
  /// Per-scheduled-instance reminders toggle. Null = use user preference.
  bool? remindersEnabled;

  ScheduledTaskModel({
    required this.id,
    required this.taskId,
    required this.userId,
    this.taskName = '',
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    this.status = "pending",
    List<int>? reminderOffsetsMinutes,
    this.remindersEnabled,
  }) : reminderOffsetsMinutes = reminderOffsetsMinutes ?? const [];

  /// Duration in minutes
  int get durationMinutes => endTime - startTime;

  factory ScheduledTaskModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dateRaw = data['schedule_date'];
    DateTime date = DateTime.now();
    if (dateRaw != null) {
      if (dateRaw is Timestamp) {
        date = dateRaw.toDate();
      } else if (dateRaw is String) {
        date = DateTime.tryParse(dateRaw) ?? DateTime.now();
      }
    }
    return ScheduledTaskModel(
      id: documentId,
      taskId: data['task_id'] ?? '',
      userId: data['user_id'] ?? 'DUMMY_USER',
      taskName: data['task_name'] ?? '',
      scheduleDate: DateTime(date.year, date.month, date.day),
      startTime: data['start_time'] ?? 0,
      endTime: data['end_time'] ?? 60,
      status: data['status'] ?? 'pending',
      reminderOffsetsMinutes: (data['reminder_offsets_minutes'] is List)
          ? (data['reminder_offsets_minutes'] as List)
              .whereType<num>()
              .map((n) => n.toInt())
              .toList()
          : const [],
      remindersEnabled: data['reminders_enabled'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'task_id': taskId,
      'user_id': userId,
      'task_name': taskName,
      'schedule_date': Timestamp.fromDate(scheduleDate),
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'reminder_offsets_minutes': reminderOffsetsMinutes,
      'reminders_enabled': remindersEnabled,
    };
  }
}
