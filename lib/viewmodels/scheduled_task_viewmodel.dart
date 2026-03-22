import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/scheduled_task_model.dart';
import '../models/task_model.dart';
import '../models/user_preferences_model.dart';
import '../services/notification_service.dart';

class ScheduledTaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId; // User ID - null means use DUMMY_USER for backward compatibility

  /// Set the current user ID (called when user logs in)
  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  /// Get the current user ID (defaults to DUMMY_USER if not set)
  String get userId => _userId ?? "DUMMY_USER";

  /// Helper method to convert minutes from midnight to readable time string (HH:MM)
  /// Example: 480 → "08:00", 510 → "08:30"
  static String _minutesToTimeString(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Stream of scheduled tasks for a single day (for daily view).
  /// Fetches by user_id only and filters by date in memory to avoid Firestore composite index.
  Stream<List<ScheduledTaskModel>> scheduledTasksForDate(DateTime date) {
    final targetYear = date.year;
    final targetMonth = date.month;
    final targetDay = date.day;
    return _db
        .collection('scheduled_tasks')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = <ScheduledTaskModel>[];
          for (final doc in snapshot.docs) {
            final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
            if (st.scheduleDate.year == targetYear &&
                st.scheduleDate.month == targetMonth &&
                st.scheduleDate.day == targetDay) {
              list.add(st);
            }
          }
          list.sort((a, b) => a.startTime.compareTo(b.startTime));
          // If multiple scheduled_task docs exist for the same task/date (data duplication),
          // keep the first one (earliest start) to avoid rendering duplicates.
          final byTaskId = <String, ScheduledTaskModel>{};
          final deduped = <ScheduledTaskModel>[];
          for (final st in list) {
            if (byTaskId.containsKey(st.taskId)) continue;
            byTaskId[st.taskId] = st;
            deduped.add(st);
          }
          return deduped;
        });
  }

  /// One-time fetch for a date (e.g. for weekly overview)
  Future<List<ScheduledTaskModel>> fetchScheduledTasksForDate(DateTime date) async {
    final snapshot = await _db
        .collection('scheduled_tasks')
        .where('user_id', isEqualTo: userId)
        .get();
    final targetYear = date.year;
    final targetMonth = date.month;
    final targetDay = date.day;
    final list = snapshot.docs
        .map((doc) => ScheduledTaskModel.fromMap(doc.data(), doc.id))
        .where((st) =>
            st.scheduleDate.year == targetYear &&
            st.scheduleDate.month == targetMonth &&
            st.scheduleDate.day == targetDay)
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    final byTaskId = <String, ScheduledTaskModel>{};
    final deduped = <ScheduledTaskModel>[];
    for (final st in list) {
      if (byTaskId.containsKey(st.taskId)) continue;
      byTaskId[st.taskId] = st;
      deduped.add(st);
    }
    return deduped;
  }

  /// Fetch scheduled tasks for a date range (e.g. week)
  Future<Map<DateTime, List<ScheduledTaskModel>>> fetchScheduledTasksForRange(
      DateTime start, DateTime end) async {
    final snapshot = await _db
        .collection('scheduled_tasks')
        .where('user_id', isEqualTo: userId)
        .get();

    final map = <DateTime, List<ScheduledTaskModel>>{};
    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(DateTime(end.year, end.month, end.day));
        d = d.add(const Duration(days: 1))) {
      map[d] = [];
    }
    for (final doc in snapshot.docs) {
      final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
      final key = DateTime(st.scheduleDate.year, st.scheduleDate.month, st.scheduleDate.day);
      if (map.containsKey(key)) {
        map[key]!.add(st);
      }
    }
    for (final list in map.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
      final byTaskId = <String, ScheduledTaskModel>{};
      final deduped = <ScheduledTaskModel>[];
      for (final st in list) {
        if (byTaskId.containsKey(st.taskId)) continue;
        byTaskId[st.taskId] = st;
        deduped.add(st);
      }
      // Replace contents so callers see a deduplicated list.
      list
        ..clear()
        ..addAll(deduped);
    }
    return map;
  }

  /// Deterministic doc ID: one scheduled_task per (user, task, date). Prevents duplicates when
  /// edit and calendar backfill both try to create for the same task/date.
  static String _scheduledTaskDocId(String userId, String taskId, DateTime dateOnly) {
    return '${userId}_${taskId}_${dateOnly.year}_${dateOnly.month}_${dateOnly.day}';
  }

  Map<String, dynamic> _reminderFields({
    List<int>? reminderOffsetsMinutes,
    bool? remindersEnabled,
  }) {
    final map = <String, dynamic>{};
    if (reminderOffsetsMinutes != null) {
      map['reminder_offsets_minutes'] = reminderOffsetsMinutes;
    }
    if (remindersEnabled != null) {
      map['reminders_enabled'] = remindersEnabled;
    }
    return map;
  }

  Future<void> _scheduleRemindersForDoc({
    required String scheduledTaskDocId,
    required String taskTitle,
    required DateTime dateOnly,
    required int startTimeMinutes,
    required List<int> reminderOffsetsMinutes,
    required bool? remindersEnabled,
    required UserPreferencesModel? prefs,
  }) async {
    try {
      await NotificationService.instance.scheduleTaskReminders(
        scheduledTaskId: scheduledTaskDocId,
        taskTitle: taskTitle,
        scheduleDateOnly: dateOnly,
        startTimeMinutes: startTimeMinutes,
        offsetsMinutes: reminderOffsetsMinutes,
        prefs: prefs,
        remindersEnabledOverride: remindersEnabled,
      );
    } catch (e) {
      debugPrint('ScheduledTaskViewModel: schedule reminders failed: $e');
    }
  }

  Future<void> _cancelRemindersForDoc({
    required String scheduledTaskDocId,
    required List<int> reminderOffsetsMinutes,
    required UserPreferencesModel? prefs,
  }) async {
    try {
      await NotificationService.instance.cancelTaskReminders(
        scheduledTaskId: scheduledTaskDocId,
        offsetsMinutes: reminderOffsetsMinutes,
        prefs: prefs,
      );
    } catch (e) {
      debugPrint('ScheduledTaskViewModel: cancel reminders failed: $e');
    }
  }

  /// Creates or updates the single scheduled task for this task/date only (for smart schedule apply).
  /// Use this when applying proposed slots so other dates for the same task are not changed.
  Future<void> createOrUpdateScheduledTaskForDate({
    required String taskId,
    required DateTime dateOnly,
    required int startTimeMinutes,
    required int endTimeMinutes,
    String taskName = '',
    List<int>? reminderOffsetsMinutes,
    bool? remindersEnabled,
    UserPreferencesModel? prefs,
  }) async {
    await _createScheduledTaskIfMissing(
      taskId: taskId,
      dateOnly: dateOnly,
      startTimeMinutes: startTimeMinutes,
      endTimeMinutes: endTimeMinutes,
      taskName: taskName,
      reminderOffsetsMinutes: reminderOffsetsMinutes,
      remindersEnabled: remindersEnabled,
      prefs: prefs,
    );
  }

  /// Creates or updates the single scheduled task for this task/date.
  /// If a doc already exists for this task/date (e.g. from tap-to-schedule), we update it.
  /// Otherwise we use a deterministic doc ID so concurrent calls (edit + backfill) write the same doc.
  Future<void> _createScheduledTaskIfMissing({
    required String taskId,
    required DateTime dateOnly,
    required int startTimeMinutes,
    required int endTimeMinutes,
    String taskName = '',
    List<int>? reminderOffsetsMinutes,
    bool? remindersEnabled,
    UserPreferencesModel? prefs,
  }) async {
    final existing = await _db
        .collection('scheduled_tasks')
        .where('task_id', isEqualTo: taskId)
        .where('user_id', isEqualTo: userId)
        .get();
    final matchingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final matchingSt = <ScheduledTaskModel>[];
    for (final doc in existing.docs) {
      final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
      if (st.scheduleDate.year == dateOnly.year &&
          st.scheduleDate.month == dateOnly.month &&
          st.scheduleDate.day == dateOnly.day) {
        matchingDocs.add(doc);
        matchingSt.add(st);
      }
    }

    // If there are multiple scheduled_task docs for the same task/date, keep one and delete the rest.
    if (matchingDocs.isNotEmpty) {
      final primaryDoc = matchingDocs.first;
      final primarySt = matchingSt.first;

      final updateData = <String, dynamic>{
        'start_time': startTimeMinutes,
        'end_time': endTimeMinutes,
        'start_time_display': _minutesToTimeString(startTimeMinutes),
        'end_time_display': _minutesToTimeString(endTimeMinutes),
        if (taskName.isNotEmpty) 'task_name': taskName,
        ..._reminderFields(
          reminderOffsetsMinutes: reminderOffsetsMinutes,
          remindersEnabled: remindersEnabled,
        ),
      };

      await primaryDoc.reference.update(updateData);
      await _syncTaskTime(taskId, startTimeMinutes, endTimeMinutes);

      // Cancel previous OS alarms for this doc so changed offsets / times don't leave orphans.
      await _cancelRemindersForDoc(
        scheduledTaskDocId: primaryDoc.id,
        reminderOffsetsMinutes: primarySt.reminderOffsetsMinutes,
        prefs: prefs,
      );

      await _scheduleRemindersForDoc(
        scheduledTaskDocId: primaryDoc.id,
        taskTitle: taskName.isNotEmpty ? taskName : primarySt.taskName,
        dateOnly: dateOnly,
        startTimeMinutes: startTimeMinutes,
        reminderOffsetsMinutes:
            reminderOffsetsMinutes ?? primarySt.reminderOffsetsMinutes,
        remindersEnabled: remindersEnabled ?? primarySt.remindersEnabled,
        prefs: prefs,
      );

      for (var i = 1; i < matchingDocs.length; i++) {
        final doc = matchingDocs[i];
        final st = matchingSt[i];
        await _cancelRemindersForDoc(
          scheduledTaskDocId: doc.id,
          reminderOffsetsMinutes: st.reminderOffsetsMinutes,
          prefs: prefs,
        );
        await doc.reference.delete();
      }

      return;
    }

    final docId = _scheduledTaskDocId(userId, taskId, dateOnly);
    await _db.collection('scheduled_tasks').doc(docId).set({
      'task_id': taskId,
      'user_id': userId,
      'task_name': taskName.isNotEmpty ? taskName : '',
      'schedule_date': Timestamp.fromDate(dateOnly),
      'start_time': startTimeMinutes,
      'end_time': endTimeMinutes,
      'start_time_display': _minutesToTimeString(startTimeMinutes),
      'end_time_display': _minutesToTimeString(endTimeMinutes),
      'status': 'pending',
      ..._reminderFields(
        reminderOffsetsMinutes: reminderOffsetsMinutes,
        remindersEnabled: remindersEnabled,
      ),
    }, SetOptions(merge: true));
    await _syncTaskTime(taskId, startTimeMinutes, endTimeMinutes);

    await _scheduleRemindersForDoc(
      scheduledTaskDocId: docId,
      taskTitle: taskName,
      dateOnly: dateOnly,
      startTimeMinutes: startTimeMinutes,
      reminderOffsetsMinutes: reminderOffsetsMinutes ?? const [],
      remindersEnabled: remindersEnabled,
      prefs: prefs,
    );
  }

  /// Sync start/end time and duration from calendar to the task document (to-do list).
  Future<void> _syncTaskTime(String taskId, int startTimeMinutes, int endTimeMinutes) async {
    try {
      final durationMinutes = (endTimeMinutes - startTimeMinutes).clamp(1, 24 * 60);
      await _db.collection('tasks').doc(taskId).update({
        'start_time': startTimeMinutes,
        'end_time': endTimeMinutes,
        'duration': durationMinutes,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint("Error syncing task time: $e");
    }
  }

  /// Add a scheduled task (tap-to-schedule). Also updates the task's start_time/end_time for to-do list sync.
  /// [taskName] is stored for easy identification in Firestore.
  Future<void> addScheduledTask({
    required String taskId,
    required DateTime scheduleDate,
    required int startTimeMinutes,
    required int endTimeMinutes,
    String taskName = '',
    String taskStatus = 'pending',
    List<int>? reminderOffsetsMinutes,
    bool? remindersEnabled,
    UserPreferencesModel? prefs,
  }) async {
    try {
      final dateOnly = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
      final ref = await _db.collection('scheduled_tasks').add({
        'task_id': taskId,
        'user_id': userId,
        'task_name': taskName,
        'schedule_date': Timestamp.fromDate(dateOnly),
        'start_time': startTimeMinutes,
        'end_time': endTimeMinutes,
        'start_time_display': _minutesToTimeString(startTimeMinutes),
        'end_time_display': _minutesToTimeString(endTimeMinutes),
        'status': taskStatus,
        ..._reminderFields(
          reminderOffsetsMinutes: reminderOffsetsMinutes,
          remindersEnabled: remindersEnabled,
        ),
      });
      await _syncTaskTime(taskId, startTimeMinutes, endTimeMinutes);

      await _scheduleRemindersForDoc(
        scheduledTaskDocId: ref.id,
        taskTitle: taskName,
        dateOnly: dateOnly,
        startTimeMinutes: startTimeMinutes,
        reminderOffsetsMinutes: reminderOffsetsMinutes ?? const [],
        remindersEnabled: remindersEnabled,
        prefs: prefs,
      );
    } catch (e) {
      debugPrint("Error adding scheduled task: $e");
      rethrow;
    }
  }

  /// Update time slot of an existing scheduled task. Also syncs to the task document (to-do list).
  Future<void> updateScheduledTask({
    required String id,
    required DateTime scheduleDate,
    required int startTimeMinutes,
    required int endTimeMinutes,
    List<int>? reminderOffsetsMinutes,
    bool? remindersEnabled,
    UserPreferencesModel? prefs,
  }) async {
    try {
      final stDoc = await _db.collection('scheduled_tasks').doc(id).get();
      final taskId = stDoc.data()?['task_id'] as String?;
      final existing = stDoc.data() == null
          ? null
          : ScheduledTaskModel.fromMap(stDoc.data()!, id);
      final dateOnly = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);
      await _db.collection('scheduled_tasks').doc(id).update({
        'schedule_date': Timestamp.fromDate(dateOnly),
        'start_time': startTimeMinutes,
        'end_time': endTimeMinutes,
        'start_time_display': _minutesToTimeString(startTimeMinutes),
        'end_time_display': _minutesToTimeString(endTimeMinutes),
        ..._reminderFields(
          reminderOffsetsMinutes: reminderOffsetsMinutes,
          remindersEnabled: remindersEnabled,
        ),
      });
      if (taskId != null && taskId.isNotEmpty) {
        await _syncTaskTime(taskId, startTimeMinutes, endTimeMinutes);
      }

      if (existing != null) {
        await _cancelRemindersForDoc(
          scheduledTaskDocId: id,
          reminderOffsetsMinutes: existing.reminderOffsetsMinutes,
          prefs: prefs,
        );
        await _scheduleRemindersForDoc(
          scheduledTaskDocId: id,
          taskTitle: existing.taskName,
          dateOnly: dateOnly,
          startTimeMinutes: startTimeMinutes,
          reminderOffsetsMinutes:
              reminderOffsetsMinutes ?? existing.reminderOffsetsMinutes,
          remindersEnabled: remindersEnabled ?? existing.remindersEnabled,
          prefs: prefs,
        );
      }
    } catch (e) {
      debugPrint("Error updating scheduled task: $e");
      rethrow;
    }
  }

  /// Update start/end time for all calendar entries of a task; if none exist, create one.
  /// [scheduleDate] and [taskName] are used when creating a new scheduled task.
  Future<void> updateOrCreateScheduledTasksForTask({
    required String taskId,
    required int startTimeMinutes,
    required int endTimeMinutes,
    DateTime? scheduleDate,
    String taskName = '',
    UserPreferencesModel? prefs,
  }) async {
    try {
      final snapshot = await _db
          .collection('scheduled_tasks')
          .where('task_id', isEqualTo: taskId)
          .where('user_id', isEqualTo: userId)
          .get();
      final dateOnly = scheduleDate != null
          ? DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day)
          : null;

      // Clean up duplicates for the provided date early so we don't re-schedule reminders or
      // show multiple blocks for the same (task_id, schedule_date).
      final idsToSkip = <String>{};
      final stById = <String, ScheduledTaskModel>{};
      if (dateOnly != null && snapshot.docs.isNotEmpty) {
        QueryDocumentSnapshot<Map<String, dynamic>>? primary;
        for (final doc in snapshot.docs) {
          final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
          if (st.scheduleDate.year == dateOnly.year &&
              st.scheduleDate.month == dateOnly.month &&
              st.scheduleDate.day == dateOnly.day) {
            if (primary == null) {
              primary = doc;
            } else {
              idsToSkip.add(doc.id);
              stById[doc.id] = st;
            }
          }
        }

        for (final id in idsToSkip) {
          final st = stById[id];
          if (st == null) continue;
          await _cancelRemindersForDoc(
            scheduledTaskDocId: id,
            reminderOffsetsMinutes: st.reminderOffsetsMinutes,
            prefs: prefs,
          );
          await _db.collection('scheduled_tasks').doc(id).delete();
        }
      }

      bool hasForProvidedDate = false;

      if (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          if (idsToSkip.contains(doc.id)) continue;
          final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);

          final updateData = <String, dynamic>{
            'start_time': startTimeMinutes,
            'end_time': endTimeMinutes,
            'start_time_display': _minutesToTimeString(startTimeMinutes),
            'end_time_display': _minutesToTimeString(endTimeMinutes),
          };

          // Keep scheduled task title in sync with the task title.
          if (taskName.isNotEmpty) {
            updateData['task_name'] = taskName;
          }

          // If a scheduleDate was provided, ensure there is an entry on that day.
          // Only update schedule_date for entries that already belong to that day,
          // so we don't accidentally move other calendar instances.
          if (dateOnly != null &&
              st.scheduleDate.year == dateOnly.year &&
              st.scheduleDate.month == dateOnly.month &&
              st.scheduleDate.day == dateOnly.day) {
            updateData['schedule_date'] = Timestamp.fromDate(dateOnly);
            hasForProvidedDate = true;
          }

          await _cancelRemindersForDoc(
            scheduledTaskDocId: doc.id,
            reminderOffsetsMinutes: st.reminderOffsetsMinutes,
            prefs: prefs,
          );
          await doc.reference.update(updateData);

          final dateForReminders = dateOnly != null &&
                  st.scheduleDate.year == dateOnly.year &&
                  st.scheduleDate.month == dateOnly.month &&
                  st.scheduleDate.day == dateOnly.day
              ? dateOnly
              : DateTime(st.scheduleDate.year, st.scheduleDate.month, st.scheduleDate.day);

          await _scheduleRemindersForDoc(
            scheduledTaskDocId: doc.id,
            taskTitle: taskName.isNotEmpty ? taskName : st.taskName,
            dateOnly: dateForReminders,
            startTimeMinutes: startTimeMinutes,
            reminderOffsetsMinutes: st.reminderOffsetsMinutes,
            remindersEnabled: st.remindersEnabled,
            prefs: prefs,
          );
        }

        // If there are scheduled tasks for this task, but none on the provided date,
        // create one so it shows on the calendar for that day (after re-check to avoid duplicates).
        if (dateOnly != null && !hasForProvidedDate) {
          await _createScheduledTaskIfMissing(
            taskId: taskId,
            dateOnly: dateOnly,
            startTimeMinutes: startTimeMinutes,
            endTimeMinutes: endTimeMinutes,
            taskName: taskName,
            prefs: prefs,
          );
        }
      } else if (dateOnly != null) {
        await _createScheduledTaskIfMissing(
          taskId: taskId,
          dateOnly: dateOnly,
          startTimeMinutes: startTimeMinutes,
          endTimeMinutes: endTimeMinutes,
          taskName: taskName,
          prefs: prefs,
        );
      }
    } catch (e) {
      debugPrint("Error updating/creating scheduled tasks for task: $e");
      rethrow;
    }
  }

  /// Update status (e.g. completed, missed)
  Future<void> updateScheduledTaskStatus(String id, String status) async {
    try {
      await _db.collection('scheduled_tasks').doc(id).update({'status': status});
    } catch (e) {
      debugPrint("Error updating scheduled task status: $e");
    }
  }

  /// Delete all scheduled_tasks for the given task (e.g. when task is unscheduled: start/end time cleared).
  Future<void> deleteAllScheduledTasksForTask(String taskId, {UserPreferencesModel? prefs}) async {
    try {
      final snapshot = await _db
          .collection('scheduled_tasks')
          .where('task_id', isEqualTo: taskId)
          .where('user_id', isEqualTo: userId)
          .get();
      for (final doc in snapshot.docs) {
        final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
        await _cancelRemindersForDoc(
          scheduledTaskDocId: doc.id,
          reminderOffsetsMinutes: st.reminderOffsetsMinutes,
          prefs: prefs,
        );
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error deleting scheduled tasks for task: $e");
      rethrow;
    }
  }

  /// Delete a scheduled task. If no other scheduled instances remain for that task, clears the task's start_time/end_time.
  Future<void> deleteScheduledTask(String id, {UserPreferencesModel? prefs}) async {
    try {
      final stDoc = await _db.collection('scheduled_tasks').doc(id).get();
      final taskId = stDoc.data()?['task_id'] as String?;
      if (stDoc.data() != null) {
        final st = ScheduledTaskModel.fromMap(stDoc.data()!, id);
        await _cancelRemindersForDoc(
          scheduledTaskDocId: id,
          reminderOffsetsMinutes: st.reminderOffsetsMinutes,
          prefs: prefs,
        );
      }
      await _db.collection('scheduled_tasks').doc(id).delete();
      if (taskId != null && taskId.isNotEmpty) {
        final remaining = await _db
            .collection('scheduled_tasks')
            .where('task_id', isEqualTo: taskId)
            .where('user_id', isEqualTo: userId)
            .get();
        if (remaining.docs.isEmpty) {
          await _db.collection('tasks').doc(taskId).update({
            'start_time': FieldValue.delete(),
            'end_time': FieldValue.delete(),
            'updated_at': Timestamp.fromDate(DateTime.now()),
          });
        }
      }
    } catch (e) {
      debugPrint("Error deleting scheduled task: $e");
      rethrow;
    }
  }
}
