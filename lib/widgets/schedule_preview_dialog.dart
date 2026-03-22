import 'package:flutter/material.dart';
import '../services/smart_schedule_service.dart';
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Generated Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
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
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.overflowMessage!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (slots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No slots to show.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...slots.map((slot) {
                        final timeStr =
                            '${_minutesToTime(slot.startMinutes)} – ${_minutesToTime(slot.endMinutes)}';
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
                                    fontWeight: FontWeight.w500,
                                    color: slot.isBreak ? Colors.grey.shade600 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  slot.taskTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: slot.isBreak ? Colors.grey : Colors.black87,
                                    fontStyle: slot.isBreak ? FontStyle.italic : null,
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
                        style: const TextStyle(color: Colors.red, fontSize: 13),
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
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isApplying || slots.isEmpty
                        ? null
                        : _onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: _isApplying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm'),
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
