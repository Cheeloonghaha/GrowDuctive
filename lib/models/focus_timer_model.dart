import 'package:cloud_firestore/cloud_firestore.dart';

/// User-defined (or default) Pomodoro timer configuration.
/// This can back the \"Custom Timers\" feature later.
class FocusTimerModel {
  /// Document id in `focus_timers` collection.
  final String id;
  final String userId; // user_id (FK)

  /// Display name, e.g. \"Default Pomodoro\", \"Deep work\".
  final String name;

  /// Durations in seconds.
  final int focusDurationSeconds;
  final int shortBreakSeconds;
  final int longBreakSeconds;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional: mark built-in timer vs user-created.
  final bool isDefault;

  FocusTimerModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.focusDurationSeconds,
    required this.shortBreakSeconds,
    required this.longBreakSeconds,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
  });

  factory FocusTimerModel.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final createdRaw = data['created_at'];
    final updatedRaw = data['updated_at'];

    DateTime created = DateTime.now();
    if (createdRaw != null) {
      if (createdRaw is Timestamp) {
        created = createdRaw.toDate();
      } else if (createdRaw is String) {
        created = DateTime.tryParse(createdRaw) ?? DateTime.now();
      }
    }

    DateTime updated = DateTime.now();
    if (updatedRaw != null) {
      if (updatedRaw is Timestamp) {
        updated = updatedRaw.toDate();
      } else if (updatedRaw is String) {
        updated = DateTime.tryParse(updatedRaw) ?? DateTime.now();
      }
    }

    return FocusTimerModel(
      id: documentId,
      userId: data['user_id'] ?? '',
      name: data['name'] ?? 'Timer',
      focusDurationSeconds: data['focus_duration_seconds'] ?? (25 * 60),
      shortBreakSeconds: data['short_break_seconds'] ?? (5 * 60),
      longBreakSeconds: data['long_break_seconds'] ?? (15 * 60),
      createdAt: created,
      updatedAt: updated,
      isDefault: data['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'focus_duration_seconds': focusDurationSeconds,
      'short_break_seconds': shortBreakSeconds,
      'long_break_seconds': longBreakSeconds,
      'is_default': isDefault,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  FocusTimerModel copyWith({
    String? id,
    String? userId,
    String? name,
    int? focusDurationSeconds,
    int? shortBreakSeconds,
    int? longBreakSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return FocusTimerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      focusDurationSeconds: focusDurationSeconds ?? this.focusDurationSeconds,
      shortBreakSeconds: shortBreakSeconds ?? this.shortBreakSeconds,
      longBreakSeconds: longBreakSeconds ?? this.longBreakSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

