import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_session_model.dart';
import '../models/focus_timer_model.dart';
import '../theme/app_colors.dart';
import '../theme/growductive_chrome.dart';
import '../navigation/sidebar_drawer_controller.dart';
import '../viewmodels/focus_timer_viewmodel.dart';

class FocusTimerView extends StatelessWidget {
  const FocusTimerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.chrome.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Consumer<FocusTimerViewModel>(
                      builder: (context, vm, _) {
                        vm.onPromptStartBreak = (breakPhase) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              _showStartBreakDialog(context, vm, breakPhase);
                            }
                          });
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCard(context, vm),
                            const SizedBox(height: 24),
                            _buildSessionsTodaySection(context, vm),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final chrome = context.chrome;
    final navBg = chrome.headerBar;
    final navBlue = chrome.navBlue;
    const menuCircleBg = Color(0xFF0F2E5C); // dark circle for menu button
    const double subtitleFontSize = 12.0;
    const double subtitleLineHeight = 1.2;
    final double subtitleBoxHeight = subtitleFontSize * subtitleLineHeight * 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: chrome.headerShadow.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: menuCircleBg,
                    elevation: 2,
                    shadowColor: menuCircleBg.withValues(alpha: 0.25),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        SidebarDrawerController.scaffoldKey.currentState?.openDrawer();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.menu, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Timer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: navBlue,
                            letterSpacing: -0.5,
                            fontSize: 21,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: subtitleBoxHeight,
                          child: Text(
                            'Concentrate all your thoughts upon the work at hand. — Alenxander.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: navBlue.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                              height: subtitleLineHeight,
                              fontSize: subtitleFontSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: navBg,
                    elevation: 2,
                    shadowColor: navBlue.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showCustomTimersSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          CupertinoIcons.slider_horizontal_3,
                          color: navBlue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCustomTimersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CustomTimersSheet(),
    );
  }

  void _showStartBreakDialog(
    BuildContext context,
    FocusTimerViewModel vm,
    FocusTimerPhase breakPhase,
  ) {
    final isLong = breakPhase == FocusTimerPhase.longBreak;
    final breakLabel = isLong ? 'Long break' : 'Short break';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final chrome = ctx.chrome;
        final navBlue = chrome.navBlue;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: chrome.headerShadow.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Focus complete!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: navBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Start $breakLabel?',
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: navBlue,
                          side: BorderSide(color: chrome.segmentBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Not now',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          vm.start();
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: navBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, FocusTimerViewModel vm) {
    final isFocus = vm.phase == FocusTimerPhase.focus;
    final isShort = vm.phase == FocusTimerPhase.shortBreak;
    final isLong = vm.phase == FocusTimerPhase.longBreak;

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: scheme.outline.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phase selector — same bar design as task_view category / segment
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.chrome.segmentOuter,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _phaseSegment(
                        context: context,
                        label: 'Focus',
                        selected: isFocus,
                        compact: compact,
                        onTap: () =>
                            Provider.of<FocusTimerViewModel>(context, listen: false)
                                .selectPhase(FocusTimerPhase.focus),
                      ),
                    ),
                    Expanded(
                      child: _phaseSegment(
                        context: context,
                        label: 'Short break',
                        selected: isShort,
                        compact: compact,
                        onTap: () =>
                            Provider.of<FocusTimerViewModel>(context, listen: false)
                                .selectPhase(FocusTimerPhase.shortBreak),
                      ),
                    ),
                    Expanded(
                      child: _phaseSegment(
                        context: context,
                        label: 'Long break',
                        selected: isLong,
                        compact: compact,
                        onTap: () =>
                            Provider.of<FocusTimerViewModel>(context, listen: false)
                                .selectPhase(FocusTimerPhase.longBreak),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Time display — scales down on small widths
          LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  vm.formattedTime,
                  style: TextStyle(
                    fontSize: constraints.maxWidth < 320 ? 40 : 52,
                    fontWeight: FontWeight.bold,
                    color: context.chrome.navBlue,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Progress bar placeholder (simple grey bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: vm.currentPhaseDuration > 0
                  ? ((vm.currentPhaseDuration - vm.remainingSeconds) / vm.currentPhaseDuration).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(context.chrome.navBlue),
            ),
          ),
          const SizedBox(height: 24),

          // Start / Reset — same segment-bar style as task_view Tasks/Overdue
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.chrome.segmentOuter,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _actionSegment(
                        context: context,
                        icon: vm.isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: vm.isRunning ? 'Pause' : 'Start',
                        onTap: () {
                          final viewModel =
                              Provider.of<FocusTimerViewModel>(context, listen: false);
                          if (viewModel.isRunning) {
                            viewModel.pause();
                          } else {
                            viewModel.start();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _actionSegment(
                        context: context,
                        icon: Icons.refresh_rounded,
                        label: 'Reset',
                        onTap: () => Provider.of<FocusTimerViewModel>(context, listen: false)
                            .reset(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Divider(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25)),
          const SizedBox(height: 12),

          // Sessions today — completed only (from Firestore)
          StreamBuilder<int>(
            stream: vm.sessionsTodayStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus Sessions Today',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.chrome.navBlue.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.chrome.navBlue,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTodaySection(BuildContext context, FocusTimerViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<FocusSessionModel>>(
          stream: vm.sessionsTodayListStream,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? [];
            final count = sessions.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Sessions today',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.chrome.navBlue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($count)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.chrome.navBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No sessions today',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _buildSessionTile(context, sessions[index]);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSessionTile(BuildContext context, FocusSessionModel session) {
    final displayStatus = getSessionDisplayStatus(session);
    final status = displayStatus == FocusSessionDisplayStatus.completed
        ? 'Completed'
        : displayStatus == FocusSessionDisplayStatus.interrupted
            ? 'Interrupted'
            : 'Incomplete';
    final statusColor = displayStatus == FocusSessionDisplayStatus.completed
        ? const Color(0xFF34C759)
        : displayStatus == FocusSessionDisplayStatus.interrupted
            ? const Color(0xFFFF9500)
            : Colors.grey.shade700;
    final start = session.startedAt;
    final timeStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final durationMin = session.durationSeconds ~/ 60;
    final durationSec = session.durationSeconds % 60;
    final durationStr =
        '${durationMin}m ${durationSec}s';

    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? scheme.outline.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              durationStr,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single segment inside the phase bar (task_view category chip style).
  Widget _phaseSegment({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    final chrome = context.chrome;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? chrome.segmentSelectedFill : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: chrome.segmentBorder, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: chrome.navBlue,
            height: 1.05,
          ),
        ),
      ),
    );
  }

  /// Start/Pause and Reset — identical pill style (task_view selected segment).
  Widget _actionSegment({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final chrome = context.chrome;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: chrome.segmentSelectedFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chrome.segmentBorder, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chrome.navBlue, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: chrome.navBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Bottom sheet: list of custom timers + add new.
class _CustomTimersSheet extends StatelessWidget {
  const _CustomTimersSheet();

  Widget _compactIconAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      iconSize: 19,
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chrome = context.chrome;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: chrome.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Custom Timers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, size: 22, color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<FocusTimerModel>>(
            stream: Provider.of<FocusTimerViewModel>(context, listen: false).customTimersStream,
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index == list.length) {
                    return OutlinedButton.icon(
                      onPressed: () {
                        _showAddTimerDialog(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(
                          color: scheme.outline.withValues(alpha: isDark ? 0.55 : 0.45),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(Icons.add, size: 18, color: scheme.onSurface),
                      label: Text(
                        'Add custom timer',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    );
                  }
                  final timer = list[index];
                  final vm = Provider.of<FocusTimerViewModel>(context, listen: false);
                  final isSelected = vm.selectedTimerId == timer.id;
                  final focusM = timer.focusDurationSeconds ~/ 60;
                  final shortM = timer.shortBreakSeconds ~/ 60;
                  final longM = timer.longBreakSeconds ~/ 60;
                  return Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outline.withValues(alpha: isDark ? 0.45 : 0.35),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                timer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                vm.selectTimer(isSelected ? null : timer.id);
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? AppColors.interactive.withValues(alpha: 0.95)
                                    : const Color(0xFF5B3FD9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                isSelected ? 'Selected' : 'Use',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _compactIconAction(
                              context,
                              icon: Icons.edit_outlined,
                              onPressed: () => _showEditTimerDialog(context, timer),
                            ),
                            _compactIconAction(
                              context,
                              icon: Icons.delete_outline,
                              onPressed: () =>
                                  _confirmDeleteTimer(context, vm, timer.id, timer.name),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$focusM min focus',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$shortM min short break · $longM min long break',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static bool _addTimerLoading = false;

  void _showAddTimerDialog(BuildContext context) {
    _addTimerLoading = false;
    final nameController = TextEditingController();
    final focusController = TextEditingController(text: '25');
    final shortController = TextEditingController(text: '5');
    final longController = TextEditingController(text: '15');
    final scaffoldContext = context;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isLoading = _addTimerLoading;
          return AlertDialog(
            title: const Text('New custom timer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Deep work',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: focusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Focus (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Short break (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: longController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Long break (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final focus = int.tryParse(focusController.text) ?? 25;
                        final short = int.tryParse(shortController.text) ?? 5;
                        final long = int.tryParse(longController.text) ?? 15;
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _addTimerLoading = true;
                        setDialogState(() {});
                        final vm = Provider.of<FocusTimerViewModel>(scaffoldContext, listen: false);
                        String? errorMsg;
                        try {
                          await vm.createCustomTimer(
                            name: name,
                            focusMinutes: focus.clamp(1, 120),
                            shortBreakMinutes: short.clamp(1, 60),
                            longBreakMinutes: long.clamp(1, 60),
                          );
                          if (!ctx.mounted) return;
                          _addTimerLoading = false;
                          setDialogState(() {});
                          Navigator.pop(ctx);
                          if (scaffoldContext.mounted) {
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                              const SnackBar(
                                content: Text('Timer created'),
                                backgroundColor: Colors.black,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e, st) {
                          debugPrint('Create custom timer error: $e');
                          debugPrint('$st');
                          _addTimerLoading = false;
                          if (ctx.mounted) setDialogState(() {});
                          errorMsg = e is FirebaseException
                              ? (e.message ?? e.code)
                              : e.toString();
                        }
                        if (errorMsg != null && scaffoldContext.mounted) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: _addTimerLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _editTimerLoading = false;

  void _showEditTimerDialog(BuildContext context, FocusTimerModel timer) {
    _editTimerLoading = false;
    final nameController = TextEditingController(text: timer.name);
    final focusController = TextEditingController(text: '${timer.focusDurationSeconds ~/ 60}');
    final shortController = TextEditingController(text: '${timer.shortBreakSeconds ~/ 60}');
    final longController = TextEditingController(text: '${timer.longBreakSeconds ~/ 60}');
    final scaffoldContext = context;
    final timerId = timer.id;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isLoading = _editTimerLoading;
          return AlertDialog(
            title: const Text('Edit timer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Deep work',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: focusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Focus (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Short break (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: longController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Long break (minutes)',
                    ),
                    enabled: !isLoading,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final focus = int.tryParse(focusController.text) ?? 25;
                        final short = int.tryParse(shortController.text) ?? 5;
                        final long = int.tryParse(longController.text) ?? 15;
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        _editTimerLoading = true;
                        setDialogState(() {});
                        final vm = Provider.of<FocusTimerViewModel>(scaffoldContext, listen: false);
                        String? errorMsg;
                        try {
                          await vm.updateCustomTimer(
                            timerId,
                            name: name,
                            focusMinutes: focus.clamp(1, 120),
                            shortBreakMinutes: short.clamp(1, 60),
                            longBreakMinutes: long.clamp(1, 60),
                          );
                          if (!ctx.mounted) return;
                          _editTimerLoading = false;
                          setDialogState(() {});
                          Navigator.pop(ctx);
                          if (scaffoldContext.mounted) {
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                              const SnackBar(
                                content: Text('Timer updated'),
                                backgroundColor: Colors.black,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e, st) {
                          debugPrint('Edit timer error: $e');
                          debugPrint('$st');
                          _editTimerLoading = false;
                          if (ctx.mounted) setDialogState(() {});
                          errorMsg = e is FirebaseException
                              ? (e.message ?? e.code)
                              : e.toString();
                        }
                        if (errorMsg != null && scaffoldContext.mounted) {
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: _editTimerLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteTimer(BuildContext context, FocusTimerViewModel vm, String id, String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete timer?'),
        content: Text('Remove "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await vm.deleteCustomTimer(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

