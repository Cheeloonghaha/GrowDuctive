import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  String id; // task_id (PK)
  String userId; // user_id (FK) - Default to "DUMMY_USER"
  String categoryId; // category_id (FK)
  String title;
  String description;
  int urgency; // 1-5
  int importance; // 1-5
  int duration; // in minutes
  String status; // "pending" or "completed"
  bool reminderOffset; // dummy for now
  bool autoSchedule; // dummy for now
  /// True if this task has at least one scheduled calendar entry.
  bool scheduled;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt; // Date/time when task was completed (null if pending)
  /// True once the task has passed its creation date without being completed. Never set back to false (for analytics).
  bool overdue;
  /// Start time in minutes from midnight (0–1439). Set when the task is scheduled on the calendar.
  int? startTime;
  /// End time in minutes from midnight (0–1439). Set when the task is scheduled on the calendar.
  int? endTime;

  TaskModel({
    required this.id,
    this.userId = "DUMMY_USER",
    required this.categoryId,
    required this.title,
    this.description = '',
    required this.urgency,
    required this.importance,
    this.duration = 30,
    this.status = "pending",
    this.reminderOffset = false,
    this.autoSchedule = false,
    this.scheduled = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
    this.overdue = false,
    this.startTime,
    this.endTime,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompleted => status == "completed";

  /// True if this task is or was overdue (stored field; once true, stays true for analytics).
  bool get isOverdue => overdue;

  TaskModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    String? title,
    String? description,
    int? urgency,
    int? importance,
    int? duration,
    String? status,
    bool? reminderOffset,
    bool? autoSchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool? overdue,
    int? startTime,
    int? endTime,
    bool? scheduled,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      importance: importance ?? this.importance,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      reminderOffset: reminderOffset ?? this.reminderOffset,
      autoSchedule: autoSchedule ?? this.autoSchedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      overdue: overdue ?? this.overdue,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      scheduled: scheduled ?? this.scheduled,
    );
  }

  static int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return defaultValue;
  }

  // Convert Firestore Document to TaskModel (FETCHING)
  factory TaskModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TaskModel(
      id: documentId,
      userId: data['user_id'] ?? "DUMMY_USER",
      categoryId: data['category_id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      urgency: data['urgency'] ?? 1,
      importance: data['importance'] ?? 1,
      // Renamed from estimated_duration; still read old key for backward compatibility.
      duration: _toInt(data['duration'] ?? data['estimated_duration'], 30),
      status: data['status'] ?? "pending",
      reminderOffset: data['reminder_offset'] ?? false,
      autoSchedule: data['auto_schedule'] ?? false,
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: data['completed_at'] != null
          ? (data['completed_at'] as Timestamp).toDate()
          : null,
      overdue: data['overdue'] == true,
      startTime: data['start_time'] != null ? (data['start_time'] as num).toInt() : null,
      endTime: data['end_time'] != null ? (data['end_time'] as num).toInt() : null,
      scheduled: data['scheduled'] == true,
    );
  }

  // Convert TaskModel to Map for Firestore (SAVING)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'urgency': urgency,
      'importance': importance,
      'duration': duration,
      'status': status,
      'reminder_offset': reminderOffset,
      'auto_schedule': autoSchedule,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'overdue': overdue,
      'start_time': startTime,
      'end_time': endTime,
      'scheduled': scheduled,
    };
  }
}
