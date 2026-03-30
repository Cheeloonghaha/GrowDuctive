import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Used when a scheduled task has no explicit reminder offsets.
  static const int kDefaultReminderMinutesBefore = 15;

  static const String _channelId = 'task_reminders';
  static const String _channelName = 'Task reminders';
  static const String _channelDescription = 'Reminders for upcoming scheduled tasks';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ runtime notification permission (no-op on older versions).
    try {
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('NotificationService: requestNotificationsPermission failed: $e');
    }

    // Exact alarms — needed for reliable zonedSchedule on many OEMs (open Settings if denied).
    try {
      await androidImpl?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('NotificationService: requestExactAlarmsPermission failed: $e');
    }

    await _ensureAndroidReminderChannel(androidImpl);

    _initialized = true;
  }

  Future<void> _ensureAndroidReminderChannel(
    AndroidFlutterLocalNotificationsPlugin? androidImpl,
  ) async {
    if (androidImpl == null || kIsWeb) return;
    try {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: createNotificationChannel failed: $e');
    }
  }

  /// Prefer exact alarms (reliable on OEMs); fall back if permission/OS rejects.
  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } on PlatformException catch (e) {
      debugPrint(
        'NotificationService: exact schedule failed (${e.code} ${e.message}), '
        'retrying inexact',
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Align [tz.local] with the device IANA zone so [zonedSchedule] matches wall-clock times.
  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      debugPrint('NotificationService: tz.local set to ${info.identifier}');
    } catch (e, st) {
      debugPrint('NotificationService: tz.local setup failed: $e\n$st');
    }
  }

  /// Schedule one notification per offset for a scheduled task instance.
  ///
  /// - [scheduledTaskId] should be the Firestore doc ID for `scheduled_tasks`.
  /// - [scheduleDateOnly] is date-only (time ignored).
  /// - [startTimeMinutes] / [endTimeMinutes] are minutes from midnight (0-1439).
  ///   When both are set and valid, the notification body includes the time range (e.g. `09:00–10:00`).
  /// - [offsetsMinutes] are minutes before the start time (e.g. [60, 15]).
  Future<void> scheduleTaskReminders({
    required String scheduledTaskId,
    required String taskTitle,
    required DateTime scheduleDateOnly,
    required int startTimeMinutes,
    int? endTimeMinutes,
    required List<int> offsetsMinutes,
    bool? remindersEnabledOverride,
  }) async {
    await init();

    final remindersEnabled = remindersEnabledOverride ?? true;
    if (!remindersEnabled) {
      await cancelTaskReminders(
        scheduledTaskId: scheduledTaskId,
        offsetsMinutes: offsetsMinutes,
      );
      return;
    }

    final sanitizedOffsets = _effectiveOffsets(offsetsMinutes);
    if (sanitizedOffsets.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: no effective offsets for $scheduledTaskId (skip schedule)',
        );
      }
      return;
    }

    for (final offset in sanitizedOffsets) {
      final fireAt = _computeFireTime(
        scheduleDateOnly: scheduleDateOnly,
        startTimeMinutes: startTimeMinutes,
        offsetMinutes: offset,
      );
      if (fireAt == null) continue;

      final now = DateTime.now();
      // If the computed reminder time is only slightly in the past (clock skew / user
      // saved just after the reminder time), nudge to soon; otherwise skip.
      if (!fireAt.isAfter(now)) {
        final skew = now.difference(fireAt);
        if (skew <= const Duration(minutes: 2)) {
          // Nudge to a future time to satisfy the plugin constraints.
          final nudged = now.add(const Duration(seconds: 1));
          if (kDebugMode) {
            debugPrint(
              'NotificationService: offset $offset min → nudge (skew ${skew.inSeconds}s) '
              'for $scheduledTaskId at $nudged',
            );
          }
          await _scheduleOneNudged(
            scheduledTaskId: scheduledTaskId,
            taskTitle: taskTitle,
            offsetMinutes: offset,
            fireAt: nudged,
            startTimeMinutes: startTimeMinutes,
            endTimeMinutes: endTimeMinutes,
          );
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            'NotificationService: offset $offset min SKIPPED (fireAt $fireAt is '
            '${skew.inSeconds}s past; grace is 2 min)',
          );
        }
        continue;
      }

      final id = _notificationId(scheduledTaskId, offset);

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      );

      final details = NotificationDetails(android: androidDetails);

      if (kDebugMode) {
        debugPrint(
          'NotificationService: zonedSchedule id=$id offset=${offset}m fireAt=$fireAt '
          '(local) title="$taskTitle"',
        );
      }
      await _zonedScheduleWithFallback(
        id: id,
        title: taskTitle,
        body: _notificationBody(
          offsetMinutes: offset,
          startTimeMinutes: startTimeMinutes,
          endTimeMinutes: endTimeMinutes,
        ),
        scheduledDate: _toTzDateTime(fireAt),
        details: details,
        payload: 'scheduled_task_id=$scheduledTaskId',
      );
    }
  }

  Future<void> _scheduleOneNudged({
    required String scheduledTaskId,
    required String taskTitle,
    required int offsetMinutes,
    required DateTime fireAt,
    required int startTimeMinutes,
    int? endTimeMinutes,
  }) async {
    final id = _notificationId(scheduledTaskId, offsetMinutes);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);

    await _zonedScheduleWithFallback(
      id: id,
      title: taskTitle,
      body: _notificationBody(
        offsetMinutes: offsetMinutes,
        startTimeMinutes: startTimeMinutes,
        endTimeMinutes: endTimeMinutes,
      ),
      scheduledDate: _toTzDateTime(fireAt),
      details: details,
      payload: 'scheduled_task_id=$scheduledTaskId',
    );
  }

  Future<void> cancelTaskReminders({
    required String scheduledTaskId,
    required List<int> offsetsMinutes,
  }) async {
    await init();
    final sanitizedOffsets = _effectiveOffsets(offsetsMinutes);
    for (final offset in sanitizedOffsets) {
      await _plugin.cancel(_notificationId(scheduledTaskId, offset));
    }
  }

  List<int> _effectiveOffsets(List<int> offsets) {
    final sanitized = _sanitizeOffsets(offsets);
    if (sanitized.isNotEmpty) return sanitized;
    return _sanitizeOffsets([kDefaultReminderMinutesBefore]);
  }

  List<int> _sanitizeOffsets(List<int> offsets) {
    final out = <int>{};
    for (final o in offsets) {
      if (o <= 0) continue;
      // cap to 7 days to avoid silly values
      out.add(o.clamp(1, 7 * 24 * 60));
    }
    final list = out.toList();
    list.sort((a, b) => b.compareTo(a)); // bigger offset first
    return list;
  }

  DateTime? _computeFireTime({
    required DateTime scheduleDateOnly,
    required int startTimeMinutes,
    required int offsetMinutes,
  }) {
    final day = DateTime(scheduleDateOnly.year, scheduleDateOnly.month, scheduleDateOnly.day);
    final clampedStart = startTimeMinutes.clamp(0, 24 * 60 - 1);
    final start = day.add(Duration(minutes: clampedStart));
    final fireAt = start.subtract(Duration(minutes: offsetMinutes));
    // If reminder would fire before the day starts, still allow (it might land in previous day),
    // but if it's absurdly far in the past due to bad data, skip later by `isAfter(now)`.
    return fireAt;
  }

  /// Relative phrase only ("Starts in 15 minutes", …).
  String _relativeStartsInPhrase({required int offsetMinutes}) {
    if (offsetMinutes >= 24 * 60 && offsetMinutes % (24 * 60) == 0) {
      final days = offsetMinutes ~/ (24 * 60);
      return days == 1 ? 'Starts in 1 day' : 'Starts in $days days';
    }
    if (offsetMinutes >= 60 && offsetMinutes % 60 == 0) {
      final hours = offsetMinutes ~/ 60;
      return hours == 1 ? 'Starts in 1 hour' : 'Starts in $hours hours';
    }
    return offsetMinutes == 1 ? 'Starts in 1 minute' : 'Starts in $offsetMinutes minutes';
  }

  String _minutesToClock(int minutesFromMidnight) {
    final m = minutesFromMidnight.clamp(0, 24 * 60 - 1);
    final h = m ~/ 60;
    final min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  /// Body line: relative reminder + optional scheduled time range.
  String _notificationBody({
    required int offsetMinutes,
    required int startTimeMinutes,
    int? endTimeMinutes,
  }) {
    final lead = _relativeStartsInPhrase(offsetMinutes: offsetMinutes);
    if (endTimeMinutes != null && endTimeMinutes > startTimeMinutes) {
      final start = _minutesToClock(startTimeMinutes);
      final end = _minutesToClock(endTimeMinutes);
      return '$lead · $start–$end';
    }
    return lead;
  }

  // Stable 32-bit FNV-1a hash to produce deterministic notification IDs.
  int _notificationId(String scheduledTaskId, int offsetMinutes) {
    final key = '$scheduledTaskId|$offsetMinutes';
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    // flutter_local_notifications expects a signed int.
    final signed = hash > 0x7fffffff ? hash - 0x100000000 : hash;
    // Avoid 0 which can be confusing in debugging (still valid, but we nudge).
    final maxInt31 = 0x7fffffff;
    return signed == 0 ? 1 : signed.abs().clamp(1, maxInt31);
  }

  tz.TZDateTime _toTzDateTime(DateTime dt) => tz.TZDateTime.from(dt, tz.local);
}

