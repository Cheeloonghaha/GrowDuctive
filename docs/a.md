# Reminder & notification module

This document describes how **task reminders** and **local notifications** are implemented in GrowDuctive.

## Overview

- Notifications are **local** (on-device) via **`flutter_local_notifications`**, not push/FCM.
- **`timezone`** is used so `zonedSchedule` respects the device’s local time zone.
- The current implementation targets **Android** (Android initialization, notification channel, `AndroidScheduleMode.inexactAllowWhileIdle`). Web/iOS are not fully wired in `NotificationService`.

## Data model

### Per scheduled instance (`scheduled_tasks`)

Stored on **`ScheduledTaskModel`** / Firestore:

| Field | Type | Meaning |
|--------|------|--------|
| `reminder_offsets_minutes` | `List<int>` | Minutes **before** that instance’s **start** (e.g. `[15, 5]` → 15 min and 5 min before). |
| `reminders_enabled` | `bool?` | Per-instance override. `null` → follow user preference when resolving behavior in the notification layer. |

### User defaults (`user_preferences`)

| Field | Meaning |
|--------|--------|
| `reminders_enabled` | Global default when the scheduled task doesn’t override. |
| `default_reminder_minutes_before` | Used when the scheduled task’s offset list is **empty** (after sanitization). Default in code: 15. |
| `quiet_hours_start_minutes` / `quiet_hours_end_minutes` | Optional window (minutes from midnight) where reminders are **not** scheduled; supports ranges that wrap midnight. |

## `NotificationService` (`lib/services/notification_service.dart`)

### Initialization (`init`)

Called from **`main.dart`** before `runApp`:

1. Loads timezone data (`tz_data.initializeTimeZones()`), then sets **`tz.local`** from the device IANA zone via **`flutter_timezone`** (so scheduled times match local wall clock).
2. Initializes the plugin with **Android** settings and channel **`task_reminders`**.
3. Requests **Android 13+** notification permission (no-op on older versions).

### `scheduleTaskReminders(...)`

1. **Enable/disable**: Uses `remindersEnabledOverride` (from the scheduled doc) if set, else `prefs?.remindersEnabled`, default **true**. If reminders are off → **`cancelTaskReminders`** and return.
2. **Effective offsets**: Sanitizes the Firestore list (positive integers, capped to 7 days, deduped). If **empty** → uses **`defaultReminderMinutesBefore`** from prefs.
3. For **each** offset, computes **fire time** = **schedule date** + **start time** (minutes from midnight) − **offset minutes**.
4. **Past times**: If the fire time is **not** slightly in the past (within ~30s skew), the notification is **skipped**. Slight skew schedules **~1 second from now** so short test offsets remain reliable.
5. **Quiet hours**: If the fire time falls inside the user’s quiet window, that notification is **skipped**.
6. Otherwise **`zonedSchedule`** with:
   - **Title**: task title  
   - **Body**: human-readable text (`_bodyForOffset` — minutes, hours, or days)  
   - **`AndroidScheduleMode.inexactAllowWhileIdle`**  
   - **Payload**: `scheduled_task_id=<Firestore doc id>` (for future tap handling)

### Notification IDs

`_notificationId(scheduledTaskId, offsetMinutes)` — deterministic FNV-style hash so a given scheduled task + offset always maps to the same notification id (stable cancel/update).

### `cancelTaskReminders(...)`

Cancels notifications for that scheduled task id and the **effective** offset list (same defaulting rules as schedule), so stale alarms are cleared when settings or instances change.

## `ScheduledTaskViewModel` integration

The view model **persists Firestore** and then **syncs the OS scheduler**:

- **`_scheduleRemindersForDoc`** → `NotificationService.scheduleTaskReminders` (doc id, title, date, start time, offsets, prefs, optional `remindersEnabled`).
- **`_cancelRemindersForDoc`** → `cancelTaskReminders` before delete or when removing duplicate docs.

Typical call sites:

- Create/update scheduled task (`_createScheduledTaskIfMissing`, `addScheduledTask`, `updateScheduledTask`, etc.).
- Bulk calendar updates (`updateOrCreateScheduledTasksForTask`).
- **Deletes** (`deleteScheduledTask`, `deleteAllScheduledTasksForTask`) and **deduplication** of duplicate docs — cancel first, then delete.

**Firestore is the source of truth**; local notifications are updated whenever the relevant `scheduled_tasks` row changes or is removed.

## UI

- **Calendar** — scheduled-task **details bottom sheet**: toggle reminders, preset + custom minute offsets, **Save reminders** → updates that `scheduled_tasks` document via the view model (which schedules/cancels as above).
- **Profile** — global reminders on/off, default minutes before, and quiet hours (consumed by `NotificationService`).

## End-to-end flow

1. User sets offsets (and optional per-instance toggle) on a calendar instance.
2. Firestore stores `reminder_offsets_minutes` and `reminders_enabled`.
3. `ScheduledTaskViewModel` calls **`NotificationService.scheduleTaskReminders`**.
4. The plugin schedules **one local notification per offset** at **start time − offset**, respecting quiet hours and defaults when the offset list is empty.

## Testing note

Validate notifications on an **Android emulator or device**. Chrome/web does not exercise this Android-only path reliably.

## Related files

| Area | File |
|------|------|
| Local notifications | `lib/services/notification_service.dart` |
| Scheduled task data | `lib/models/scheduled_task_model.dart` |
| Scheduling hooks | `lib/viewmodels/scheduled_task_viewmodel.dart` |
| User prefs | `lib/models/user_preferences_model.dart` |
| App init | `lib/main.dart` |
| Calendar UI | `lib/views/calendar_view.dart` |
| Profile / defaults | `lib/views/profile_view.dart` |

--------------------------------------------------------------------------------------------------

## Detailed logic: when and how notifications fire after reminder offsets are set

This section walks through **exactly** what runs after the user sets `reminder_offsets_minutes` (and optional `reminders_enabled`) and taps **Save reminders** (or after any other code path that updates a `scheduled_tasks` row with reminder fields).

### Step 1 — Persist Firestore, then call the scheduler

1. The UI calls `ScheduledTaskViewModel.updateScheduledTask(...)` with the new `reminderOffsetsMinutes` and `remindersEnabled` (see `calendar_view.dart` → **Save reminders**).
2. The view model **`update`s** the `scheduled_tasks` document (same `id` as the open instance).
3. If the document existed, it calls **`_scheduleRemindersForDoc`**, passing:
   - `scheduledTaskDocId` — Firestore document id (used as `scheduledTaskId` for notifications),
   - `taskTitle` — task name from the existing scheduled row,
   - `dateOnly` — calendar date of that instance,
   - `startTimeMinutes` — minutes from midnight for the **start** of the block,
   - `reminderOffsetsMinutes` — the list just saved (or merged with existing if the API passed `null` for offsets),
   - `remindersEnabled` — per-instance override or merged value,
   - `prefs` — current `UserPreferencesModel` (or `null`).

So: **the OS is not notified until after Firestore write succeeds** (same `try` block order: `update` then `_scheduleRemindersForDoc`).

### Step 2 — `NotificationService.scheduleTaskReminders`

All of the following is in `lib/services/notification_service.dart`.

1. **`init()`**  
   Ensures timezone data is loaded, the Android plugin is initialized, and (on Android 13+) notification permission is requested. Safe to call repeatedly (idempotent).

2. **Reminders globally / per-instance off**  
   `remindersEnabled = remindersEnabledOverride ?? prefs?.remindersEnabled ?? true`.  
   If this resolves to **false**, the service calls **`cancelTaskReminders`** with the same `offsetsMinutes` and `prefs` (to clear matching notification ids), then **returns** — **no new** `zonedSchedule` calls.

3. **Effective offsets (`_effectiveOffsets`)**  
   - Input is `offsetsMinutes` from the view model (what you saved in Firestore for that instance).  
   - **`_sanitizeOffsets`**: keep only positive integers, clamp each to **1 … 7×24×60** minutes, dedupe, sort descending (order does not change fire times, only iteration order).  
   - If that list is **empty**, fall back to **`prefs.defaultReminderMinutesBefore`** if it is positive; otherwise **no offsets** → **function returns** without scheduling anything.

4. **One loop iteration per offset**  
   For each integer `offset` in the effective list:

   **a. Compute when the notification should fire (`_computeFireTime`)**  
   - Take **date-only** `scheduleDateOnly` (year/month/day).  
   - **Start datetime** = that day at `startTimeMinutes` minutes after midnight (clamped to `0 … 24×60−1`).  
   - **Fire time** = `start − offset minutes` (as `DateTime` in local wall time).  
   - Example: date = March 10, start = 14:00 (840 min), offset = 15 → fire at March 10 **13:45**.

   **b. Compare with “now”**  
   - If **`fireAt` is strictly after `now`**: this is the normal path (reminder still in the future).  
   - If **`fireAt` is not after `now`** (already passed or equal):  
     - Compute **skew** = `now − fireAt`.  
     - If skew **≤ 30 seconds**: treat as clock/scheduling skew; schedule at **`now + 1 second`** via `_scheduleOne` (unless that nudged instant falls in quiet hours — then **skip**).  
     - If skew **> 30 seconds**: **skip** this offset (no notification scheduled for it).

   **c. Quiet hours (`_isInQuietHours`)**  
   If **both** `prefs.quietHoursStartMinutes` and `quietHoursEndMinutes` are non-null and not equal, the code checks whether the **fire** instant’s time-of-day (minutes from midnight) falls inside the configured window (including wrap past midnight). If **yes**, this offset is **skipped** (no `zonedSchedule`). If either quiet field is **null**, quiet hours are **not** applied.

   **d. Schedule with the platform plugin**  
   If the notification was not skipped above, the service builds an **`AndroidNotificationDetails`** (channel `task_reminders`, high importance) and calls **`_plugin.zonedSchedule`** with:
   - **id** — `_notificationId(scheduledTaskId, offset)` (stable hash from doc id + offset),
   - **title** — `taskTitle`,
   - **body** — `_bodyForOffset(offset)` (e.g. “Starts in 15 minutes”),
   - **scheduled date/time** — `TZDateTime` from `fireAt` (or the nudged time in the skew branch),
   - **`androidScheduleMode`**: `inexactAllowWhileIdle`,
   - **payload**: `scheduled_task_id=<scheduledTaskId>`.

   `_scheduleOne` is the same `zonedSchedule` path used for the “skew nudge” case.

### Step 3 — What actually “calls” the notification

There is **no separate timer in app code** after save. **`zonedSchedule`** registers the alarm with the **OS** (via `flutter_local_notifications`). The **system** delivers the notification at (approximately) the requested local time. **Inexact** mode means the exact moment can shift slightly on some devices (battery optimizations).

### Step 4 — Cancellation (`cancelTaskReminders`) — when it runs

`cancelTaskReminders` computes the **same** effective offset list (sanitize + default fallback), then **`cancel(id)`** for each `id = _notificationId(scheduledTaskId, offset)`.

It is used when:

- Reminders are **disabled** inside `scheduleTaskReminders` (see step 2.2), or  
- The view model **deletes** a scheduled instance or duplicate docs (calls `_cancelRemindersForDoc` before delete).

**Note:** Before rescheduling, the view model **cancels** prior notifications for that scheduled-task doc using the **previous** `reminder_offsets_minutes` (via `_cancelRemindersForDoc`), then schedules the new effective offsets — so changing offsets or start time should not leave orphan OS alarms.

### Summary diagram (mental model)

```
Save offsets in UI
  → updateScheduledTask (Firestore update)
    → _cancelRemindersForDoc (previous offsets)
    → _scheduleRemindersForDoc
        → for each effective offset:
             fireAt = startDateTime − offset
             → skip if too far in past; else apply quiet hours; else zonedSchedule(id, fireAt)
```

The **reminder offset** is only the input to **`fireAt`**; the **notification** is the **`zonedSchedule`** registration for that `fireAt`.

## Android manifest (required since `flutter_local_notifications` v16)

The plugin’s own manifest is **minimal**. Your **`android/app/src/main/AndroidManifest.xml`** must declare:

- **`RECEIVE_BOOT_COMPLETED`** — rescheduling after reboot.
- **`ScheduledNotificationReceiver`** and **`ScheduledNotificationBootReceiver`** (see plugin README) — without these, **scheduled notifications may never fire**.
- **`SCHEDULE_EXACT_ALARM`** / **`USE_EXACT_ALARM`** (and runtime **`requestExactAlarmsPermission()`**) if you use **exact** alarm mode for reliable delivery on OEM devices.

## Device timezone & OEM behavior (e.g. Honor / MagicOS)

- **`tz.local`**: On startup, `NotificationService` uses **`flutter_timezone`** to set `tz.setLocalLocation(...)` from the device IANA id so `zonedSchedule` matches local wall time. Without this, reminders could fire at the wrong clock time or be skipped by the “past time” rule.
- **Past-time grace**: If the computed `fireAt` is already in the past but by **≤ 2 minutes**, the app schedules **~1 second from now** instead of skipping (helps if you save just after the reminder minute).
- **Honor / MagicOS**: Allow **notifications**, disable **battery restrictions** for the app if alarms are delayed or missing. **`inexactAllowWhileIdle`** means the OS may shift delivery slightly.
- **Debug**: In **debug** builds, watch the console for `NotificationService:` lines (`zonedSchedule`, `SKIPPED`, `tz.local set to …`).

### Example: start 15:30, offset 20 min, quiet hours null

- Reminder **`fireAt`** = **15:10** on the scheduled date.
- If you tap **Save reminders** **after 15:12** (more than 2 minutes late), that offset is **skipped** (log: `SKIPPED … grace is 2 min`).
- Quiet hours **null** → no skip from quiet mode.
