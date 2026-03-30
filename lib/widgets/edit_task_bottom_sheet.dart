import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import '../theme/app_colors.dart';
import '../theme/growductive_chrome.dart';
import '../viewmodels/scheduled_task_viewmodel.dart';
import '../viewmodels/task_viewmodel.dart';
import 'add_task_bottom_sheet.dart';
import 'glass_sheet.dart';

int _minutesBetween(TimeOfDay start, TimeOfDay end) {
  final startM = start.hour * 60 + start.minute;
  final endM = end.hour * 60 + end.minute;
  return endM - startM;
}

/// Glass bottom sheet for editing a task — matches [AddTaskBottomSheet] chrome styling.
class EditTaskBottomSheet {
  EditTaskBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required TaskViewModel taskVM,
    required ScheduledTaskViewModel scheduledTaskVM,
    required TaskModel task,
    void Function(DateTime taskDate)? onTaskDateChanged,
  }) async {
    final pageContext = context;
    final messenger = ScaffoldMessenger.of(context);

    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final int initialDuration = (task.startTime != null &&
            task.endTime != null &&
            task.endTime! > task.startTime!)
        ? (task.endTime! - task.startTime!)
        : task.duration;
    final durationController = TextEditingController(text: initialDuration.toString());
    int urgency = task.urgency;
    int importance = task.importance;
    String? selectedCategoryId =
        task.categoryId.isEmpty ? null : task.categoryId;
    TimeOfDay? startTimeOfDay = task.startTime != null
        ? TimeOfDay(hour: task.startTime! ~/ 60, minute: task.startTime! % 60)
        : null;
    TimeOfDay? endTimeOfDay = task.endTime != null
        ? TimeOfDay(hour: task.endTime! ~/ 60, minute: task.endTime! % 60)
        : null;
    String? editDialogError;
    var taskDate = DateTime(task.taskDate.year, task.taskDate.month, task.taskDate.day);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        final maxH =
            (MediaQuery.sizeOf(sheetContext).height * 0.92 - viewInsets.bottom).clamp(280.0, 900.0);

        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GlassSheet(
              blurSigma: 18,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: StatefulBuilder(
                  builder: (context, setSheetState) {
                    final theme = Theme.of(context);
                    final scheme = theme.colorScheme;
                    final isDark = theme.brightness == Brightness.dark;
                    final chrome = context.chrome;
                    final accent = chrome.navBlue;
                    final borderRadius = BorderRadius.circular(14);
                    final borderColor =
                        isDark ? scheme.outline.withValues(alpha: 0.55) : AppColors.borderSubtle;
                    final outlineBorder = OutlineInputBorder(
                      borderRadius: borderRadius,
                      borderSide: BorderSide(color: borderColor),
                    );
                    final focusBorder = OutlineInputBorder(
                      borderRadius: borderRadius,
                      borderSide: BorderSide(color: accent, width: 2),
                    );
                    final fieldFill = isDark
                        ? scheme.surfaceContainerHighest
                        : Colors.white.withValues(alpha: 0.78);
                    final fieldTextStyle = TextStyle(color: scheme.onSurface, fontSize: 16);
                    final labelStyle = TextStyle(color: scheme.onSurfaceVariant);
                    final hintStyle =
                        TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.75));
                    final compactDeco = InputDecoration(
                      filled: true,
                      fillColor: fieldFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: outlineBorder,
                      enabledBorder: outlineBorder,
                      focusedBorder: focusBorder,
                      labelStyle: labelStyle,
                      floatingLabelStyle: labelStyle,
                      hintStyle: hintStyle,
                    );
                    final inactiveSlider = isDark
                        ? scheme.outline.withValues(alpha: 0.35)
                        : AppColors.borderSubtle;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Edit Task',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      'Update details — scroll if needed',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.25,
                                        color: Colors.white.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                buildTaskFormSheetSection(
                                  accentColor: accent,
                                  context: context,
                                  title: 'About',
                                  subtitle: 'Title is required. Description is optional.',
                                  icon: Icons.edit_note_rounded,
                                  children: [
                                    TextField(
                                      controller: titleController,
                                      style: fieldTextStyle,
                                      decoration: compactDeco.copyWith(
                                        labelText: 'Task title',
                                        hintText: 'What do you need to do?',
                                      ),
                                      autofocus: true,
                                      textInputAction: TextInputAction.next,
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: descriptionController,
                                      style: fieldTextStyle,
                                      decoration: compactDeco.copyWith(
                                        labelText: 'Notes',
                                        hintText: 'Extra context (optional)',
                                        alignLabelWithHint: true,
                                      ),
                                      minLines: 2,
                                      maxLines: 4,
                                    ),
                                  ],
                                ),
                                buildTaskFormSheetSection(
                                  accentColor: accent,
                                  context: context,
                                  title: 'Schedule',
                                  subtitle:
                                      'Change the day, duration, and optional start/end for your calendar.',
                                  icon: Icons.event_available_rounded,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: sheetContext,
                                            initialDate: taskDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                                          );
                                          if (picked != null) {
                                            setSheetState(() {
                                              editDialogError = null;
                                              taskDate = DateTime(picked.year, picked.month, picked.day);
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: InputDecorator(
                                          decoration: compactDeco.copyWith(
                                            labelText: 'Task date',
                                            prefixIcon: Icon(
                                              Icons.calendar_today_outlined,
                                              size: 22,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                          child: Text(
                                            MaterialLocalizations.of(context).formatFullDate(taskDate),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: durationController,
                                      onChanged: (_) => setSheetState(() => editDialogError = null),
                                      style: fieldTextStyle,
                                      decoration: compactDeco.copyWith(
                                        labelText: 'Duration',
                                        hintText: 'Minutes',
                                        suffixText: 'min',
                                        suffixStyle: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime: startTimeOfDay ??
                                                      const TimeOfDay(hour: 9, minute: 0),
                                                );
                                                if (picked != null) {
                                                  setSheetState(() {
                                                    editDialogError = null;
                                                    startTimeOfDay = picked;
                                                    if (endTimeOfDay != null) {
                                                      final mins = _minutesBetween(picked, endTimeOfDay!);
                                                      if (mins > 0) durationController.text = mins.toString();
                                                    }
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                                                decoration: BoxDecoration(
                                                  color: fieldFill,
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: borderColor),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Start',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        letterSpacing: 0.3,
                                                        color: scheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      startTimeOfDay != null
                                                          ? startTimeOfDay!.format(context)
                                                          : 'Tap to set',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: startTimeOfDay != null
                                                            ? scheme.onSurface
                                                            : scheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () async {
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime: endTimeOfDay ??
                                                      startTimeOfDay ??
                                                      const TimeOfDay(hour: 10, minute: 0),
                                                );
                                                if (picked != null) {
                                                  setSheetState(() {
                                                    editDialogError = null;
                                                    endTimeOfDay = picked;
                                                    if (startTimeOfDay != null) {
                                                      final mins = _minutesBetween(startTimeOfDay!, picked);
                                                      if (mins > 0) durationController.text = mins.toString();
                                                    }
                                                  });
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                                                decoration: BoxDecoration(
                                                  color: fieldFill,
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: borderColor),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'End',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        letterSpacing: 0.3,
                                                        color: scheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      endTimeOfDay != null
                                                          ? endTimeOfDay!.format(context)
                                                          : 'Tap to set',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: endTimeOfDay != null
                                                            ? scheme.onSurface
                                                            : scheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (startTimeOfDay != null || endTimeOfDay != null) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => setSheetState(() {
                                            startTimeOfDay = null;
                                            endTimeOfDay = null;
                                          }),
                                          child: const Text('Clear times'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                buildTaskFormSheetSection(
                                  accentColor: accent,
                                  context: context,
                                  title: 'Category',
                                  subtitle: 'Organize tasks by area of life.',
                                  icon: Icons.folder_outlined,
                                  children: [
                                    StreamBuilder<List<CategoryModel>>(
                                      stream: taskVM.categoriesStream,
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 20),
                                              child: CircularProgressIndicator(color: accent),
                                            ),
                                          );
                                        }
                                        final categories = snapshot.data!;
                                        return DropdownButtonFormField<String>(
                                          // ignore: deprecated_member_use
                                          value: selectedCategoryId,
                                          dropdownColor: scheme.surfaceContainerHigh,
                                          style: fieldTextStyle,
                                          iconEnabledColor: scheme.onSurfaceVariant,
                                          decoration: compactDeco.copyWith(labelText: 'Select category'),
                                          items: categories.map((category) {
                                            return DropdownMenuItem<String>(
                                              value: category.id,
                                              child: Text(
                                                category.name,
                                                style: TextStyle(color: scheme.onSurface),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            setSheetState(() => selectedCategoryId = value);
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                buildTaskFormSheetSection(
                                  accentColor: accent,
                                  context: context,
                                  title: 'Priority',
                                  subtitle: 'Adjust if this task should stand out in your list.',
                                  icon: Icons.bolt_rounded,
                                  children: [
                                    Text(
                                      'Urgency',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: accent,
                                              inactiveTrackColor: inactiveSlider,
                                              thumbColor: accent,
                                              overlayColor: accent.withValues(alpha: 0.12),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: urgency.toDouble(),
                                              min: 1,
                                              max: 5,
                                              divisions: 4,
                                              label: urgency.toString(),
                                              onChanged: (value) =>
                                                  setSheetState(() => urgency = value.toInt()),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: fieldFill,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: borderColor),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$urgency',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Importance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderThemeData(
                                              activeTrackColor: AppColors.jade,
                                              inactiveTrackColor: inactiveSlider,
                                              thumbColor: AppColors.jade,
                                              overlayColor: AppColors.jade.withValues(alpha: 0.12),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: importance.toDouble(),
                                              min: 1,
                                              max: 5,
                                              divisions: 4,
                                              label: importance.toString(),
                                              onChanged: (value) =>
                                                  setSheetState(() => importance = value.toInt()),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: fieldFill,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: borderColor),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$importance',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? scheme.outline.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            color: isDark
                                ? scheme.surfaceContainerHigh.withValues(alpha: 0.88)
                                : Colors.white.withValues(alpha: 0.28),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (editDialogError != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.coral.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded,
                                            color: AppColors.coral, size: 22),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            editDialogError!,
                                            style: TextStyle(
                                              color: scheme.error,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SafeArea(
                                top: false,
                                minimum: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(sheetContext),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: BorderSide(color: borderColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (titleController.text.trim().isEmpty ||
                                                selectedCategoryId == null) {
                                              var errorMsg = 'Please enter a task title';
                                              if (selectedCategoryId == null) {
                                                errorMsg = 'Please select a category';
                                              }
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(errorMsg),
                                                  backgroundColor: AppColors.coral,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                              return;
                                            }
                                            final int? startM = startTimeOfDay != null
                                                ? startTimeOfDay!.hour * 60 + startTimeOfDay!.minute
                                                : null;
                                            final int? endM = endTimeOfDay != null
                                                ? endTimeOfDay!.hour * 60 + endTimeOfDay!.minute
                                                : null;
                                            if (startM != null && endM != null) {
                                              if (endM <= startM) {
                                                setSheetState(() => editDialogError =
                                                    'End time must be after start time.');
                                                return;
                                              }
                                              final durationMins = int.tryParse(durationController.text);
                                              final expectedDuration = endM - startM;
                                              if (durationMins == null ||
                                                  durationMins != expectedDuration) {
                                                setSheetState(() => editDialogError =
                                                    'Duration must match start–end time ($expectedDuration min). Adjust times or duration.');
                                                return;
                                              }
                                            }
                                            final duration = int.tryParse(durationController.text) ?? 30;
                                            final taskDay = DateTime(
                                              taskDate.year,
                                              taskDate.month,
                                              taskDate.day,
                                            );
                                            final navigator = Navigator.of(sheetContext);
                                            await taskVM.updateTask(
                                              id: task.id,
                                              title: titleController.text.trim(),
                                              description: descriptionController.text.trim(),
                                              urgency: urgency,
                                              importance: importance,
                                              duration: duration,
                                              categoryId: selectedCategoryId!,
                                              startTime: startM,
                                              endTime: endM,
                                              taskDate: taskDay,
                                            );
                                            if (!sheetContext.mounted) return;
                                            navigator.pop();
                                            if (!pageContext.mounted) return;
                                            onTaskDateChanged?.call(taskDay);
                                            if (startM != null && endM != null) {
                                              try {
                                                await scheduledTaskVM.updateOrCreateScheduledTasksForTask(
                                                  taskId: task.id,
                                                  startTimeMinutes: startM,
                                                  endTimeMinutes: endM,
                                                  scheduleDate: taskDay,
                                                  taskName: titleController.text.trim(),
                                                );
                                                if (!pageContext.mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: const Text('Task updated'),
                                                    backgroundColor: accent,
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!pageContext.mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text('Task updated; calendar sync failed: $e'),
                                                    backgroundColor: AppColors.softGold,
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            } else {
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: const Text('Task updated'),
                                                  backgroundColor: accent,
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: const Text(
                                            'Update Task',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
