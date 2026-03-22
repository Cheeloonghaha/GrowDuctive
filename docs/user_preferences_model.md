# User Preferences Model — What to Include

Each user has one preferences document (e.g. in a `user_preferences` collection, keyed by `user_id` or using the same ID as the user profile). Below is what should be included, grouped by feature.

---

## 1. Smart Task Organizer / Scheduling

These map to `SmartScheduleConfig` so the scheduler can use per-user values instead of hardcoded defaults.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `day_start_minutes` | int | 480 (8:00) | Start of schedulable day (minutes from midnight). |
| `day_end_minutes` | int | 1320 (22:00) | End of schedulable day (minutes from midnight). |
| `schedule_break_minutes` | int | 10 | Break duration (minutes) inserted between tasks. |
| `schedule_snap_minutes` | int | 15 | Snap step for slot boundaries (optional; can stay app-wide). |

---

## 2. Focus Timer

Either store a reference to the user’s default timer, or default durations if you prefer not to depend on `focus_timers` for first-time defaults.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default_timer_id` | string? | null | Document ID of the default focus timer. If null, use app default or first timer. |
| *(optional)* `focus_duration_minutes` | int | 25 | Default focus duration when no custom timer. |
| *(optional)* `short_break_minutes` | int | 5 | Default short break. |
| *(optional)* `long_break_minutes` | int | 15 | Default long break. |
| `timer_sound_enabled` | bool | true | Play sound when a focus/break session ends. |
| `timer_vibration_enabled` | bool | true | Vibrate when a session ends (mobile). |

---

## 3. Calendar & Week

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `week_starts_on` | int | 1 | 1 = Monday, 7 = Sunday. Used for analytics “current week” and any week-based UI. |

---

## 4. Reminders & Notifications

For the FYP Reminder and Notification module.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `reminders_enabled` | bool | true | Whether to send task reminders. |
| `default_reminder_minutes_before` | int | 15 | Default minutes before a task start to trigger a reminder. |
| `quiet_hours_start_minutes` | int? | null | Start of quiet hours (minutes from midnight); null = no quiet hours. |
| `quiet_hours_end_minutes` | int? | null | End of quiet hours; null = no quiet hours. Notifications suppressed in this window. |

---

## 5. Appearance

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `theme` | string | `"system"` | `"light"` \| `"dark"` \| `"system"`. |

---

## 6. Metadata

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | string | Owner (same as auth UID). Use as doc ID or required field. |
| `updated_at` | timestamp | Last update time. |

---

## Suggested Firestore Structure

- **Collection:** `user_preferences`
- **Document ID:** same as `user_id` (one doc per user), or use `user_id` as a field and another ID.
- **Fields:** snake_case as in the tables above; store numbers and booleans natively; use Firestore `Timestamp` for `updated_at`.

---

## Optional / Later

- **Locale / language** (e.g. `locale`: `"en"`, `"ms"`) for future i18n.
- **Time zone** (e.g. IANA string) if you support scheduling across time zones.
- **Onboarding completed** (bool) to show/hide onboarding or tips once.

---

## Relation to Existing Code

- **UserProfileModel** holds identity/display (email, username, bio, etc.). Keep preferences separate so they can be loaded/updated independently and stay small.
- **SmartScheduleConfig** in `smart_schedule_service.dart` can take values from this model (e.g. build config from `UserPreferencesModel` when calling `generateSchedule`).
- **AnalyticsViewModel** uses Monday–Sunday; `week_starts_on` would allow Sunday–Saturday or other week start.
- **Focus timer** defaults are currently in `FocusTimerViewModel` constants; `default_timer_id` or the optional duration fields can override them per user.
