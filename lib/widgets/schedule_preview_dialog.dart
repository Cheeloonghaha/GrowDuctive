import 'package:flutter/material.dart';
import '../services/smart_schedule_service.dart';
import '../theme/growductive_chrome.dart';
import '../viewmodels/scheduled_task_viewmodel.dart';
import '../viewmodels/task_viewmodel.dart';

/// Shows the proposed schedule from SmartScheduleService and lets the user
/// Confirm (apply to calendar) or Cancel.
void showSchedulePreviewDialog({
  required BuildContext context,
  required SmartScheduleResult result,
  required DateTime selectedDate,
  required ScheduledTaskViewModel scheduledVM,
  required TaskViewModel taskVM,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => _SchedulePreviewDialog(
      result: result,
      selectedDate: selectedDate,
      scheduledVM: scheduledVM,
      taskVM: taskVM,
    ),
  );
}

class _SchedulePreviewDialog extends StatefulWidget {
  final SmartScheduleResult result;
  final DateTime selectedDate;
  final ScheduledTaskViewModel scheduledVM;
  final TaskViewModel taskVM;

  const _SchedulePreviewDialog({
    required this.result,
    required this.selectedDate,
    required this.scheduledVM,
    required this.taskVM,
  });

  @override
  State<_SchedulePreviewDialog> createState() => _SchedulePreviewDialogState();
}

class _SchedulePreviewDialogState extends State<_SchedulePreviewDialog> {
  bool _isApplying = false;
  String? _error;

  static String _minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _onConfirm() async {
    if (widget.result.slots.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isApplying = true;
      _error = null;
    });
    try {
      final taskIds = <String>{};
      for (final slot in widget.result.slots) {
        if (slot.isBreak) continue;
        await widget.scheduledVM.createOrUpdateScheduledTaskForDate(
          taskId: slot.taskId,
          dateOnly: DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
          ),
          startTimeMinutes: slot.startMinutes,
          endTimeMinutes: slot.endMinutes,
          taskName: slot.taskTitle,
        );
        taskIds.add(slot.taskId);
      }
      for (final id in taskIds) {
        await widget.taskVM.setTaskScheduled(id, true);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final slots = result.slots;
    final scheme = Theme.of(context).colorScheme;
    final chrome = context.chrome;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: chrome.headerBar,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: chrome.segmentBorder.withValues(alpha: 0.55),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: chrome.navBlue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Generated Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: chrome.navBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: chrome.navBlue, size: 24),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.overflowMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: chrome.navBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.overflowMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurface,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (slots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No slots to show.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      ...slots.map((slot) {
                        final timeStr =
                            '${_minutesToTime(slot.startMinutes)} – ${_minutesToTime(slot.endMinutes)}';
                        final timeColor =
                            slot.isBreak ? scheme.onSurfaceVariant : scheme.onSurface;
                        final titleColor = slot.isBreak
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: timeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  slot.taskTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: titleColor,
                                    fontStyle: slot.isBreak ? FontStyle.italic : null,
                                    fontWeight:
                                        slot.isBreak ? FontWeight.w500 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isApplying ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: chrome.navBlue),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isApplying || slots.isEmpty
                        ? null
                        : _onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: chrome.navBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isApplying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Confirm',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
