# Smart Task Organizer (Smart Scheduler)

## Overview

The Smart Task Organizer is GrowDuctive’s **rule-based scheduler**. Given a date and a list of tasks, it generates a proposed schedule (time blocks) by:

- **Ordering tasks** using an Eisenhower-style priority + a numeric score (importance/urgency + overdue boost).
- **Fitting tasks into a day window** (default 08:00–22:00), snapping boundaries to 15-minute increments.
- **Avoiding overlaps** with already-occupied blocks on the calendar (e.g., already scheduled tasks).
- **Inserting breaks** according to user preferences (break length + “break after N minutes” behavior).

It returns **proposed slots** for preview (tasks + breaks). Nothing is persisted until the user confirms.

---

## Key data used by the organizer

From `TaskModel` (`lib/models/task_model.dart`):

- `importance` (1–5)
- `urgency` (1–5)
- `duration` (minutes; clamped to 1..1440)
- `overdue` (bool; if true, gets a score boost)
- `createdAt` (tie-break)

From the calendar (passed in as `existingBlocks`):

- `ExistingBlock(startMinutes, endMinutes)` = an occupied range the scheduler must not overlap.

From user preferences (`UserPreferencesModel`, optional):

- `breakDurationMinutes`
- `breakAfterTaskMinutes` (0 = after every task)

---

## Algorithms (what actually runs)

### 1. Eisenhower quadrant (primary ordering)

Each task is first grouped into an Eisenhower-style quadrant based on thresholds:

- **Quadrant 1** (Do first): importance ≥ 4 AND urgency ≥ 4
- **Quadrant 2** (Schedule): importance ≥ 4 AND urgency < 4
- **Quadrant 3** (Quick / delegate): importance < 4 AND urgency ≥ 4
- **Quadrant 4** (Lowest): importance < 4 AND urgency < 4

Lower quadrant number is scheduled earlier (1 → 4).

### 2. Numeric priority score (secondary ordering)

Within the same quadrant, tasks are sorted by a numeric score (higher first):

`score = importance + urgency + overdueBonus`

Where:

- `overdueBonus = 10` if `task.overdue == true`, else 0

### 3. Tie-breakers (deterministic order)

If quadrant and score are equal, sort by:

1. **Shorter duration first** (`duration` ascending) to reduce fragmentation
2. **Older tasks first** (`createdAt` ascending)

This makes scheduling stable and predictable for the same inputs.

### 4. Time snapping (15-minute grid)

The scheduler aligns time to a fixed step:

- `snapMinutes` default = **15**
- `snapTo(x) = x` if divisible by 15, else round up to next multiple of 15
- Task duration is clamped to 1..1440, then snapped the same way.

This keeps blocks aligned to a clean calendar grid.

### 5. Slot fitting with “cursor” placement

The algorithm maintains a moving cursor `current` (minutes from midnight), starting at `dayStartMinutes`.

For each task in sorted order:

- `start = snapTo(current)`
- `end = start + snappedDuration`
- Then it tries to **shift the block forward** if it overlaps any `existingBlocks`.
  - If the candidate `[start, end)` overlaps an existing block, it moves `start` to `snapTo(overlappingBlock.end)` and recomputes `end`.
  - It repeats until it finds a non-overlapping window or it runs out of day.

If the task cannot fit (past day end), it is counted as overflow and skipped.

### 6. Break insertion (two modes)

After scheduling a task, the scheduler may insert a break slot:

- Break length is `breakDurationMinutes` (default 10).
- Break frequency depends on `breakAfterTaskMinutes`:
  - If `breakAfterTaskMinutes <= 0`: **insert a break after every task** (legacy behavior).
  - Else: accumulate scheduled task minutes since the last break; insert a break once the total reaches/exceeds `breakAfterTaskMinutes`.
- Breaks are only inserted if the break fits before `dayEndMinutes`.

Breaks are returned as `ProposedSlot(isBreak: true)` for the preview UI; they are **not** intended to be saved as scheduled tasks.

### 7. Overflow

If some tasks cannot be placed, the result sets:

- `hasOverflow = true`
- `overflowMessage = "Not all tasks fit. N task(s) not scheduled. Consider moving them to another day."`

The partial schedule is still usable and can be confirmed.

---

## Range scheduling (selected time window)

In addition to full-day scheduling, the organizer supports scheduling inside a specific time window:

- `generateScheduleForRange(...)` takes `rangeStartMinutes` and `rangeEndMinutes`
- It builds a config from preferences and overrides the day window to that range
- It still avoids `existingBlocks`, snaps to the grid, and applies the same ordering + break rules

If the range end is not after the start, it returns an empty schedule.

---

## Configuration

`SmartScheduleConfig` (`lib/services/smart_schedule_service.dart`) controls behavior:

| Parameter | Default | Meaning |
|---|---:|---|
| `dayStartMinutes` | 480 | 08:00 |
| `dayEndMinutes` | 1320 | 22:00 |
| `snapMinutes` | 15 | time grid |
| `breakDurationMinutes` | 10 | break length |
| `breakAfterTaskMinutes` | 0 | 0 = break after every task; otherwise break after N task minutes |

`SmartScheduleConfig.fromPreferences(prefs)` reads break settings from user preferences when available.

---

## Outputs (what the UI previews)

The scheduler returns `SmartScheduleResult`:

- `slots`: list of `ProposedSlot` (tasks + breaks)
- `hasOverflow`: true/false
- `overflowMessage`: nullable string

Each `ProposedSlot` contains:

- `date` (date-only)
- `startMinutes`, `endMinutes`
- `taskId`, `taskTitle`
- `isBreak` (true for breaks; false for tasks)

---

## Where it lives in the code

- `lib/services/smart_schedule_service.dart`
  - `SmartScheduleService.generateSchedule(...)`
  - `SmartScheduleService.generateScheduleForRange(...)`
  - `ProposedSlot`, `ExistingBlock`, `SmartScheduleConfig`, `SmartScheduleResult`
