# Focus Timer Module — Summary

## Overview

The Focus Timer module is a Pomodoro-style timer that lets users run focus sessions, short breaks, and long breaks. Sessions are saved to Firestore and can be viewed by day. Each user has an auto-created default timer (stored in the DB); custom timers can be created and selected.

---

## Features

- **Phases:** Focus, Short Break, Long Break (durations come from the selected timer).
- **Default timer:** One “Pomodoro” timer per user (25/5/15 min, `is_default: true`) is created on first login and auto-selected so all sessions have a `timer_id`.
- **Custom timers:** Create, edit, delete timers; when the selected timer is edited, the on-screen countdown updates immediately.
- **Session recording:** When a focus run ends (reaches zero) or is paused/reset, a session is saved with `completed`, `interrupted`, `durationSeconds`, `session_date` (YYYY-MM-DD string), and `timer_id`.
- **Auto-switch after focus:** When focus ends → switch to Short Break (or Long Break every 4 cycles) and show a “Start break?” dialog. When a break ends → switch back to Focus (no auto-start).
- **Sessions today:** Count of **completed** sessions for today; list of **all** sessions for today (with status: Completed / Interrupted / Incomplete).

---

## Focus Score (Analytics)

The **Focus Score** (0–100) is calculated in the **Analytics** module from focus sessions in the selected week. Formula summary:

- **Time (up to 40 pts):** `(totalFocusMinutes clamped 0–125) / 125 × 40` — 125 minutes = 5 Pomodoro focus sessions (5 × 25 min); full points if the user achieves at least 5 focus sessions in the week.
- **Completion (up to 35 pts):** `completionRate × 35` (completed sessions ÷ total sessions)
- **Interruption (up to 25 pts):** `25 × (1 − interruptionRate)` — full 25 pts when no sessions interrupted; 0 when all interrupted.
- **Final:** `timeScore + completeScore + interruptionScore`, rounded and clamped to 0–100 (100/100 is reachable when perfect).

See **Analytics Module** docs for the full formula and inputs.

---

## How to get a high Focus Score

The Focus Score (0–100) in Analytics is based on **total focus time**, **session completion**, and **few interruptions**. To get a high score:

1. **Reach at least 125 minutes of focus per week (up to 40 pts)**  
   The time component is capped at 125 minutes = 5 × 25 min (five full Pomodoro focus sessions). Do at least five full focus blocks in the selected week to get the full 40 pts.

2. **Complete sessions without stopping early (up to 35 pts)**  
   Let the focus timer reach zero instead of pausing or resetting. Only sessions that run to the end (or meet the minimum completed threshold) count as “completed”; the more completed sessions out of total, the higher this part.

3. **Avoid interrupting sessions (up to 25 pts)**  
   Pausing or resetting marks a session as **interrupted**, which reduces this component. No interrupted sessions = full 25 pts. Start focus only when you can commit to the block.

**Practical tips:**
- Use the Focus Timer: start a focus block and let it run to zero; take short/long breaks between blocks.
- Aim for at least five full focus blocks (e.g. 25 min each) per week to max out the time component.
- Minimize pausing or resetting mid-session; if you must stop, starting a new session later still helps total time and completion rate.

---

## Data Model

### FocusTimerModel (`focus_timers`)

| Field | Type | Description |
|-------|------|-------------|
| id  | string | Document id |
| user_id | string | Firebase Auth UID |
| name | string | Display name |
| focus_duration_seconds | int | Focus phase duration |
| short_break_seconds | int | Short break duration |
| long_break_seconds | int | Long break duration |
| created_at / updated_at | Timestamp | Audit |
| is_default | bool | True for the auto-created Pomodoro timer |

### FocusSessionModel (`focus_sessions`)

| Field | Type | Description |
|-------|------|-------------|
| id | string | Document id |
| user_id | string | Firebase Auth UID |
| timer_id | string? | FK to focus_timers (null if default) |
| duration_seconds | int | Actual session length |
| started_at / ended_at | Timestamp | Session bounds |
| session_date | string | YYYY-MM-DD (calendar day, avoids timezone issues) |
| interrupted | bool | User paused/reset before finish |
| completed | bool | Counts as “completed” (e.g. ran to zero or ≥60s) |

---

## ViewModel (FocusTimerViewModel)

- **Auth:** `setUserId(String?)` — clears caches, (re)subscribes to custom timers; `ensureDefaultTimer()` creates the default timer if the user has none.
- **Timer state:** `phase`, `remainingSeconds`, `isRunning`, `formattedTime`, `currentPhaseDuration`; `start()`, `pause()`, `reset()`, `selectPhase()`, `selectTimer()`.
- **Custom timers:** `customTimersStream`, `customTimers`, `selectedTimerId`, `selectedTimer`; `createCustomTimer()`, `updateCustomTimer()`, `deleteCustomTimer()`. On load, if no timer is selected, the default (or first) timer is auto-selected; if the selected timer is updated in the list, remaining time is synced.
- **Sessions today:** `sessionsTodayStream` (count of **completed** sessions today); `sessionsTodayListStream` (list of **all** sessions today for the list). Dates use device local; `session_date` is stored as YYYY-MM-DD string.
- **Display status:** `getSessionDisplayStatus(session)` → Completed (green), Interrupted (orange), Incomplete (grey). Interrupted = completed and interrupted; Incomplete = not completed (even if interrupted).
- **Auto-switch:** When focus reaches zero, session is saved, cycle counter incremented; next phase is Short Break or Long Break (every 4 focus cycles). `onPromptStartBreak` callback triggers the “Start break?” dialog. When a break reaches zero, phase switches back to Focus.

---

## UI (Focus Timer View)

- **Header:** White bar with “Focus Timer” and “Custom Timers” button.
- **Card:** Phase chips (Focus / Short Break / Long Break), large countdown, progress bar, Start/Pause and Reset.
- **Focus Sessions Today:** Count (completed only) and below a “Sessions today (N)” list with time, duration, and status chip per session.
- **Custom Timers sheet:** List of timers + create form (name, focus/short/long minutes).
- **“Start break?” dialog:** After focus ends, dialog matches app style (white card, black/white buttons).

---

## Firestore Rules

- `focus_timers`: read/create/update/delete when `resource.data.user_id == request.auth.uid` (create uses `request.resource.data.user_id`).
- `focus_sessions`: read when `resource.data.user_id == request.auth.uid`; create when `request.resource.data.user_id == request.auth.uid`; update/delete when `resource.data.user_id == request.auth.uid`.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/viewmodels/focus_timer_viewmodel.dart` | Timer logic, sessions, custom timers, streams |
| `lib/views/focus_timer_view.dart` | UI, phase chips, session list, dialog |
| `lib/models/focus_session_model.dart` | Session model and Firestore mapping |
| `lib/models/focus_timer_model.dart` | Timer preset model and Firestore mapping |
