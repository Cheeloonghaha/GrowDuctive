import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/scheduled_task_model.dart';
import '../models/user_preferences_model.dart';
import '../services/notification_service.dart';

class TaskViewModel extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId; // User ID - null means use DUMMY_USER for backward compatibility

  /// Set the current user ID (called when user logs in)
  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  /// Get the current user ID (defaults to DUMMY_USER if not set)
  String get userId => _userId ?? "DUMMY_USER";

  /// True if task is pending and creation date is in the past.
  static bool _shouldBeOverdue(TaskModel task) {
    if (task.isCompleted) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final creationDay = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
    return today.isAfter(creationDay);
  }

  /// Public helper for determining if a task should be considered overdue "today".
  /// This mirrors the internal stream logic and can be used by one-off fetches (e.g. smart scheduling).
  static bool computeShouldBeOverdue(TaskModel task) => _shouldBeOverdue(task);

  // Stream to listen to tasks in real-time (filtered by userId)
  Stream<List<TaskModel>> get tasksStream {
    return _db
        .collection('tasks')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final tasks = snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
      final result = <TaskModel>[];
      for (final task in tasks) {
        final shouldBeOverdue = _shouldBeOverdue(task);

        // If task should be overdue but flag is false → set to true
        if (shouldBeOverdue && !task.overdue) {
          await _db.collection('tasks').doc(task.id).update({'overdue': true});
          result.add(task.copyWith(overdue: true));
        }
        // If task should NOT be overdue and it is still pending → clear overdue.
        // Completed tasks must keep `overdue=true` so the completed-overdue UI stays consistent.
        // Already in correct state
        else if (!shouldBeOverdue && task.overdue && !task.isCompleted) {
          await _db.collection('tasks').doc(task.id).update({'overdue': false});
          result.add(task.copyWith(overdue: false));
        } else {
          result.add(task);
        }
      }
      return result;
    });
  }

  // Stream to listen to categories in real-time (filtered by userId)
  Stream<List<CategoryModel>> get categoriesStream {
    return _db
        .collection('categories')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Fetches pending tasks whose createdAt date equals [date] (for smart schedule).
  Future<List<TaskModel>> fetchTasksForDate(DateTime date) async {
    try {
      // Keep existing behavior: only tasks created on this date.
      final result = await fetchPendingTasksForSmartSchedule(
        date,
        includeOverdue: false,
      );
      return result;
    } catch (e) {
      print("Error fetching tasks for date: $e");
      return [];
    }
  }

  /// Fetch pending tasks for smart scheduling:
  /// - Includes tasks created on [date]
  /// - Optionally includes overdue tasks from previous days
  /// Ensures overdue flag is updated when needed (same logic as tasksStream).
  Future<List<TaskModel>> fetchPendingTasksForSmartSchedule(
    DateTime date, {
    bool includeOverdue = true,
  }) async {
    try {
      final snapshot = await _db
          .collection('tasks')
          .where('user_id', isEqualTo: userId)
          .get();

      final targetDay = DateTime(date.year, date.month, date.day);
      final result = <TaskModel>[];

      for (final doc in snapshot.docs) {
        final task = TaskModel.fromMap(doc.data(), doc.id);
        if (task.status != 'pending') continue;

        final shouldBeOverdue = _shouldBeOverdue(task);
        TaskModel effective = task;
        if (shouldBeOverdue && !task.overdue) {
          // Keep Firestore flag consistent so UI + analytics match.
          await _db.collection('tasks').doc(task.id).update({'overdue': true});
          effective = task.copyWith(overdue: true);
        }

        final createdDay = DateTime(
          effective.createdAt.year,
          effective.createdAt.month,
          effective.createdAt.day,
        );
        final isForSelectedDay = createdDay == targetDay;
        final include =
            isForSelectedDay || (includeOverdue && (effective.overdue == true));
        if (!include) continue;

        result.add(effective);
      }

      return result;
    } catch (e) {
      print("Error fetching smart-schedule tasks: $e");
      return [];
    }
  }

  // Fetch categories as a Future (for one-time fetches, filtered by userId)
  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final snapshot = await _db
          .collection('categories')
          .where('user_id', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print("Error fetching categories: $e");
      return [];
    }
  }

  // ADD CATEGORY (with userId)
  Future<String?> addCategory(String name) async {
    try {
      // Check if category already exists for this user
      final existingCategories = await _db
          .collection('categories')
          .where('user_id', isEqualTo: userId)
          .where('name', isEqualTo: name)
          .get();

      if (existingCategories.docs.isNotEmpty) {
        print("Category already exists");
        return existingCategories.docs.first.id;
      }

      // Add new category with userId
      final docRef = await _db.collection('categories').add({
        'name': name,
        'user_id': userId,
      });
      print("Category added successfully: $name");
      return docRef.id;
    } catch (e) {
      print("Error adding category: $e");
      return null;
    }
  }

  // UPDATE CATEGORY
  Future<void> updateCategory(String id, String newName) async {
    try {
      await _db.collection('categories').doc(id).update({
        'name': newName,
      });
      print("Category updated successfully");
    } catch (e) {
      print("Error updating category: $e");
    }
  }

  // DELETE CATEGORY (check tasks for this user only)
  Future<void> deleteCategory(String id) async {
    try {
      // First, check if any tasks are using this category (for this user)
      final tasksWithCategory = await _db
          .collection('tasks')
          .where('user_id', isEqualTo: userId)
          .where('category_id', isEqualTo: id)
          .get();

      if (tasksWithCategory.docs.isNotEmpty) {
        print("Cannot delete category: tasks are still using it");
        throw Exception("Cannot delete category with existing tasks");
      }

      await _db.collection('categories').doc(id).delete();
      print("Category deleted successfully");
    } catch (e) {
      print("Error deleting category: $e");
      rethrow;
    }
  }

  // ADD TASK with all new attributes (uses current userId).
  // [createdAt] when set (e.g. from calendar) creates the task for that date so it appears in to-do for that day.
  Future<String?> addTask({
    required String title,
    required String description,
    required int urgency,
    required int importance,
    required int duration,
    required String categoryId,
    DateTime? createdAt,
    int? startTime,
    int? endTime,
  }) async {
    try {
      final created = createdAt ?? DateTime.now();
      final task = TaskModel(
        id: '', // Will be set by Firestore
        userId: userId,
        categoryId: categoryId,
        title: title,
        description: description,
        urgency: urgency,
        importance: importance,
        duration: duration,
        status: "pending",
        reminderOffset: false,
        autoSchedule: false,
        createdAt: created,
        updatedAt: created,
        startTime: startTime,
        endTime: endTime,
      );

      final ref = await _db.collection('tasks').add(task.toMap());
      print("Task added successfully");
      return ref.id;
    } catch (e) {
      print("Error adding task: $e");
      return null;
    }
  }

  /// Deletes the task and all of **this user's** calendar rows for it.
  ///
  /// [scheduled_tasks] must be queried with both [task_id] and [user_id]. A query on
  /// `task_id` alone can fail with `permission-denied` because Firestore rejects any query
  /// that might return documents the client is not allowed to read (e.g. another user's
  /// row with the same task id, or evaluation edge cases). See:
  /// https://firebase.google.com/docs/firestore/security/rules-query
  ///
  /// Composite index: `scheduled_tasks` → `task_id` ASC, `user_id` ASC (see firestore.indexes.json).
  Future<void> deleteTask(String id, {UserPreferencesModel? userPrefs}) async {
    try {
      final scheduledSnapshot = await _db
          .collection('scheduled_tasks')
          .where('task_id', isEqualTo: id)
          .where('user_id', isEqualTo: userId)
          .get();

      final toDelete = scheduledSnapshot.docs.toList();

      for (final doc in toDelete) {
        try {
          final st = ScheduledTaskModel.fromMap(doc.data(), doc.id);
          await NotificationService.instance.cancelTaskReminders(
            scheduledTaskId: doc.id,
            offsetsMinutes: st.reminderOffsetsMinutes,
            prefs: userPrefs,
          );
        } catch (e) {
          debugPrint('TaskViewModel: cancel reminders for ${doc.id}: $e');
        }
      }

      final batch = _db.batch();
      for (final doc in toDelete) {
        batch.delete(doc.reference);
      }
      batch.delete(_db.collection('tasks').doc(id));
      await batch.commit();

      if (kDebugMode) {
        debugPrint(
          'TaskViewModel: deleted task $id and ${toDelete.length} scheduled_task(s)',
        );
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  // UPDATE TASK
  Future<void> updateTask({
    required String id,
    required String title,
    required String description,
    required int urgency,
    required int importance,
    required int duration,
    required String categoryId,
    String? status,
    int? startTime,
    int? endTime,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'title': title,
        'description': description,
        'urgency': urgency,
        'importance': importance,
        'duration': duration,
        'category_id': categoryId,
        'updated_at': Timestamp.fromDate(DateTime.now()),
        'start_time': startTime,
        'end_time': endTime,
      };
      
      // If status is being updated, handle completedAt and overdue
      if (status != null) {
        updateData['status'] = status;
        if (status == "completed") {
          final doc = await _db.collection('tasks').doc(id).get();
          final currentData = doc.data();
          if (currentData != null && currentData['status'] != "completed") {
            final now = DateTime.now();
            updateData['completed_at'] = Timestamp.fromDate(now);
            // Same as toggleComplete: if completion is after creation day, set overdue for analytics
            final createdAt = currentData['created_at'] as Timestamp?;
            if (createdAt != null) {
              final creationDay = DateTime(createdAt.toDate().year, createdAt.toDate().month, createdAt.toDate().day);
              final today = DateTime(now.year, now.month, now.day);
              if (today.isAfter(creationDay)) {
                updateData['overdue'] = true;
              }
            }
          }
        } else if (status == "pending") {
          // Reopened: clear completed_at. Do not clear overdue; once overdue, it stays true (analytics + UI border).
          updateData['completed_at'] = null;
        }
      }
      
      await _db.collection('tasks').doc(id).update(updateData);
      print("Task updated successfully");
    } catch (e) {
      print("Error updating task: $e");
    }
  }

  // TOGGLE TASK COMPLETION
  /// [taskCreatedAt] when provided and we're completing the task: if completion date is after creation date, sets overdue = true (stays true forever for analytics).
  Future<void> toggleComplete(String id, bool currentStatus, {DateTime? taskCreatedAt}) async {
    try {
      final newStatus = currentStatus ? "pending" : "completed";
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': Timestamp.fromDate(now),
      };

      if (newStatus == "completed") {
        updateData['completed_at'] = Timestamp.fromDate(now);
        if (taskCreatedAt != null) {
          final today = DateTime(now.year, now.month, now.day);
          final creationDay = DateTime(taskCreatedAt.year, taskCreatedAt.month, taskCreatedAt.day);
          if (today.isAfter(creationDay)) {
            updateData['overdue'] = true;
          }
        }
      } else {
        // Reopening: clear completed_at. Do not clear overdue; once overdue, it stays true (analytics + UI border).
        updateData['completed_at'] = null;
      }

      await _db.collection('tasks').doc(id).update(updateData);
      print("Task status toggled successfully");
    } catch (e) {
      print("Error toggling task: $e");
    }
  }

  /// Updates the task's scheduled flag (e.g. after smart schedule creates calendar entries).
  Future<void> setTaskScheduled(String taskId, bool scheduled) async {
    try {
      await _db.collection('tasks').doc(taskId).update({
        'scheduled': scheduled,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print("Error setting task scheduled: $e");
    }
  }

  // Initialize default categories (call this once during app setup or when user first logs in)
  Future<void> initializeDefaultCategories() async {
    try {
      final categories = await fetchCategories();
      if (categories.isEmpty) {
        await addCategory("School");
        await addCategory("Personal");
        await addCategory("Work");
        print("Default categories initialized for user: $userId");
      }
    } catch (e) {
      print("Error initializing categories: $e");
    }
  }
}
