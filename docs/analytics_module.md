# Analytics Module — Summary

## Overview

The Analytics module shows productivity and focus insights for the **current calendar week (Monday–Sunday)**. It reads from the Tasks Planner and Focus Timer data and presents task completion, weekly productivity, tasks by category, and focus metrics with simple scores. The week refreshes automatically when the calendar week changes.

---

## Features

- **Date range:** All metrics are for the **current week** (Monday 00:00 to Sunday 23:59, local time). A “This week” label (e.g. “Mon 3 Feb – Sun 9 Feb”) is shown on the screen.
- **Summary cards:** Completion % (tasks) and Focus minutes (focus sessions) for the week.
- **Tabs:** **Productivity** (Tasks Planner) and **Focus Timer**, with content and styling consistent with the rest of the app.

### Productivity tab (Tasks Planner)

- **Task Completion Rate** — Completed vs total tasks this week, progress bar, short description.
- **Weekly Productivity** — Bar chart: completed tasks per weekday (Mon–Sun).
- **Tasks by Category** — Count and bar per category for the week.
- **Productivity Score** — 0–100 from completion rate and weekly activity.

### Focus Timer tab

- **Total Focus Sessions** — Number of sessions this week.
- **Total Focus Time** — Sum of session durations (minutes).
- **Average Focus Length** — Average session length (minutes).
- **Total Interruptions** — Sessions with `interrupted == true` this week.
- **Focus Score** — 0–100 from total time, completion rate, and interruption rate.

---

## Score Formulas

### Productivity Score (0–100)

The productivity score rewards **completion rate**, **consistency (days with activity)**, and **volume (total tasks)** for the selected week. More tasks and activity on more days give a higher score; there is no hardcoded task cap.

- **Inputs:**
  - `completionRate` = completed tasks ÷ total tasks (0.0–1.0) for the week.
  - `weeklyCompleted` = list of 7 counts (Mon–Sun) of tasks completed each day (using `completedAt` within the week).

- **Formula:**
  - `weeklyTotal` = sum of `weeklyCompleted`.
  - `daysWithActivity` = number of weekdays (1–7) with at least one completed task.
  - **Completion (40 pts):** `completionRate × 40` — finish what you start.
  - **Consistency (30 pts):** `(daysWithActivity ÷ 7) × 30` — active on more days in the week (e.g. all 7 days → 30 pts).
  - **Volume (30 pts):** `30 × (1 − 1/(1 + weeklyTotal))` — more tasks = higher; diminishing returns, no fixed cap.
  - **Final score** = sum of the three parts, rounded and clamped to 0–100.

- **Meaning:**
  - Completing tasks only on a few days (e.g. Mon–Wed) gives a lower consistency share than being active every day.
  - More completed tasks always increase the volume part; the formula does not use a fixed maximum task count (e.g. no “cap at 20”).

---

## How to get a high Productivity Score

The Productivity Score (0–100) is based on **three pillars**: finishing tasks, spreading work across the week, and doing a healthy volume. To get a high score:

1. **Complete most of your tasks (up to 40 pts)**  
   The score uses your **completion rate** (completed ÷ total tasks created that week). Aim to complete every task you create, or at least a high percentage. Creating many tasks and leaving them unfinished hurts the score.

2. **Be active on more days (up to 30 pts)**  
   Completing at least one task on **each weekday** (Mon–Sun) gives the full 30 pts. Completing everything in one or two days caps this part. Spread completions across the week for maximum consistency points.

3. **Complete a solid number of tasks (up to 30 pts)**  
   More **completed** tasks increase the volume part (with diminishing returns). There is no fixed cap: even 5–10 completed tasks already give a large share of the 30 pts; more completions keep nudging the score up.

**Practical tips:**
- Create a realistic number of tasks each week and complete them rather than over-committing.
- Prefer completing at least one task every day instead of batching everything on one day.
- Mark tasks complete when done so `completedAt` falls within the current week (used for the bar chart and score).

---

### Focus Score (0–100)

The focus score combines **total focus time**, **session completion rate**, and **interruption rate** for the selected week.

- **Inputs:**
  - `totalMinutes` = sum of all focus session durations (minutes) in the week.
  - `completionRate` = completed sessions ÷ total sessions (0.0–1.0).
  - `interruptionRate` = interrupted sessions ÷ total sessions (0.0–1.0).

- **Formula:**
  - `timeScore` = (totalMinutes clamped to 0–125 ÷ 125) × 40  → up to **40 points**.
  - **125 minutes** = 5 × 25 min (5 Pomodoro focus sessions); full time points if the user achieves at least 5 focus sessions in the week.
  - `completeScore` = completionRate × 35  → up to **35 points**.
  - `interruptionScore` = 25 × (1 − interruptionRate)  → up to **25 points** when no sessions are interrupted; 0 when all are interrupted.
  - `raw` = timeScore + completeScore + interruptionScore.
  - **Final score** = `raw` rounded and clamped to 0–100.

- **Meaning:**
  - Up to **40 points** for focus time (125+ minutes = full 40 pts).
  - Up to **35 points** for completing sessions without stopping early.
  - Up to **25 points** for having no interrupted sessions (100/100 is reachable: 40+35+25 when perfect).

---

## How to get a high Focus Score

The Focus Score (0–100) is based on **total focus time**, **session completion**, and **few interruptions**. To get a high score:

1. **Reach at least 125 minutes of focus per week (up to 40 pts)**  
   The time component is capped at 125 minutes = 5 × 25 min (five full Pomodoro focus sessions). Hitting 125+ minutes in the selected week gives the full 40 pts. Less time gives a proportional share (e.g. ~63 min ≈ 20 pts).

2. **Complete sessions without stopping early (up to 35 pts)**  
   Only sessions that run to the end (or meet the minimum completed threshold) count as “completed.” Let the focus timer reach zero instead of pausing or resetting. The more completed sessions out of total sessions, the higher this part of the score.

3. **Avoid interrupting sessions (up to 25 pts)**  
   Pausing or resetting a focus session marks it as **interrupted**, which reduces the interruption component. No interrupted sessions = full 25 pts; if every session is interrupted, this part is 0. Start focus only when you can commit to the block.

**Practical tips:**
- Aim for at least five full focus blocks (e.g. 25 min each) per week to max out the time component.
- Use the Focus Timer tab: start a focus block and let it run to zero; take short/long breaks between blocks.
- Minimize pausing or resetting mid-session; if you must stop, starting a new session later still helps total time and completion rate.

---

## Week Picker Calendar — Color Theme (Conclusion)

The “Select Week” dialog uses Flutter’s `CalendarDatePicker` with a local `Theme` that overrides `DatePickerThemeData`. Here is how the calendar colors and shapes work.

### 1. **All days (default)**

- **Text:** `dayForegroundColor` is **black87** for every state (selected, disabled, normal). Using one color for all states avoids the selected day’s number disappearing when the framework applies a different style.
- **Background:** No fill by default (`dayBackgroundColor` is only set for the selected state).
- **Shape:** `dayShape` is a **rounded rectangle** (8px radius) for all days. The Material date picker needs an explicit shape so it actually draws the selected day’s background; without `dayShape`, the selected background may not show.

### 2. **Selected day**

- **Text:** Same **black87** as other days (so the number is always visible).
- **Background:** **Light grey** (`Colors.grey.shade300`) inside the rounded rectangle. Only the selected cell gets this fill.
- **Shape:** Same rounded rectangle as above; the grey is drawn inside it.

### 3. **Today**

- **Text:** **Blue** (`#1976D2`) via `todayForegroundColor`, so “today” is visible even when it is also the selected date (e.g. on first open).
- **Background:** **Light blue** (`#E3F2FD`) via `todayBackgroundColor`.
- **Border:** **Blue** 1.5px outline via `todayBorder` so today is clearly marked.

### 4. **Why it’s set up this way**

- **Single foreground color for days:** Avoids the bug where the selected date’s number was not drawn when the theme gave the selected state a different (e.g. white) color.
- **Explicit `currentDate`:** Passing `currentDate: now` to the picker ensures “today” is always identified and styled correctly, including when it’s the initial selection.
- **`dayShape` for all:** Providing a shape for every day (not only when selected) makes the selected day’s grey background paint reliably.

### 5. **Summary table**

| Element        | Property              | Value / behavior |
|----------------|-----------------------|-------------------|
| Day text       | `dayForegroundColor`  | Black87 for all states |
| Selected fill  | `dayBackgroundColor`  | Grey.shade300 when selected |
| Day shape      | `dayShape`            | RoundedRectangleBorder(8) for all days |
| Today text     | `todayForegroundColor`| Blue #1976D2 |
| Today fill     | `todayBackgroundColor`| Light blue #E3F2FD |
| Today outline  | `todayBorder`         | Blue 1.5px |

---

## Data Sources

| Source | Filter | Used for |
|--------|--------|----------|
| `tasks` | `user_id == currentUser` | Filter in code to `createdAt` in current week → completion rate, weekly completed per day, by category, productivity score |
| `categories` | `user_id == currentUser` | Category names for “Tasks by Category” |
| `focus_sessions` | `user_id == currentUser` | Filter in code to `startedAt` in current week → sessions, total time, avg length, interruptions, focus score |

All filtering by week is done in the ViewModel after fetching by `user_id` (no week-based Firestore queries).

---

## ViewModel (AnalyticsViewModel)

- **Auth:** `setUserId(String?)` so streams use the current user.
- **Week helpers:** `weekStart(date)` (Monday 00:00), `weekEnd(date)` (Sunday 23:59:59), `currentWeekLabel()` (e.g. “Mon 3 Feb – Sun 9 Feb”).
- **Task analytics stream:** Fetches tasks and categories, keeps only tasks with `createdAt` in `[weekStart(now), weekEnd(now)]`, then computes:
  - total / completed / completion rate
  - `weeklyCompleted[0..6]` = completed count per weekday (Mon–Sun)
  - tasks by category (with category names)
  - productivity score (0–100)
- **Focus analytics stream:** Fetches focus_sessions, keeps only sessions with `startedAt` in current week, then computes total sessions, total minutes, average length, total interruptions, focus score (0–100).

Scores are heuristic (e.g. productivity: completion rate + weekly trend; focus: time + completion − interruptions). They can be tuned in the ViewModel without changing the UI contract.

---

## UI (Analytics View)

- **Header:** White, “Analytics” title and “Track your productivity journey” subtitle (aligned with app style).
- **Week label:** Pill with calendar icon and current week range (from `AnalyticsViewModel.currentWeekLabel()`).
- **Summary cards:** Two white cards (24px radius, light shadow): Completion % (green icon) and Focus Min (orange icon).
- **Tabs:** Pill-style tabs (black when selected, white label); “Productivity” and “Focus Timer.”
- **Cards:** White content cards (24px radius, same shadow as Focus Timer card), with titles and content for each metric.
- **Charts:** Weekly productivity = bar chart Mon–Sun; Tasks by Category = label + count + horizontal bar.

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/viewmodels/analytics_viewmodel.dart` | Week range, task/focus streams, aggregation, scores |
| `lib/views/analytics_view.dart` | Header, week label, summary cards, tabs, Productivity and Focus Timer tab content |

---

## Notes

- No extra “refresh” action: the week is always the current calendar week, so data effectively refreshes when the week changes.
- Reads only; Analytics does not write to Firestore.
- Uses the same design language as the rest of the app (white header, rounded cards, black/white tabs, grey text).
