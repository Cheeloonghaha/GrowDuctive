import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/analytics_viewmodel.dart';

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildHeader(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWeekLabel(context),
                    const SizedBox(height: 16),
                    _buildSummaryCards(context),
                    const SizedBox(height: 20),
                    _buildTabsContent(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Track your productivity journey',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekLabel(BuildContext context) {
    return Consumer<AnalyticsViewModel>(
      builder: (context, vm, _) {
        final isCurrent = vm.isCurrentWeek;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 14,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => vm.previousWeek(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: compact ? 16 : 18,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showWeekPicker(context, vm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: compact ? 16 : 18,
                            color: Colors.grey[700],
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Flexible(
                            child: Text(
                              vm.selectedWeekLabel,
                              style: TextStyle(
                                fontSize: compact ? 13 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            SizedBox(width: compact ? 6 : 8),
                            if (compact)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'This week',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                  GestureDetector(
                    onTap: vm.canGoToNextWeek ? () => vm.nextWeek() : null,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: compact ? 16 : 18,
                        color:
                            vm.canGoToNextWeek ? Colors.grey[700] : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWeekPicker(BuildContext context, AnalyticsViewModel vm) {
    final now = DateTime.now();
    // Maximum selectable date = end of current week (no future weeks)
    final endOfCurrentWeek = AnalyticsViewModel.weekEnd(now);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenH = MediaQuery.of(ctx).size.height;
            final maxDialogH = screenH * 0.78;
            final calendarH = (screenH * 0.42).clamp(260.0, 360.0);
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogH),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Week',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Theme(
                        data: Theme.of(ctx).copyWith(
                          datePickerTheme: DatePickerThemeData(
                            dayForegroundColor:
                                const WidgetStatePropertyAll(Colors.black87),
                            dayBackgroundColor: WidgetStateProperty.resolveWith(
                                (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.grey.shade300;
                              }
                              return null;
                            }),
                            dayShape:
                                WidgetStateProperty.resolveWith<OutlinedBorder?>(
                                    (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return RoundedRectangleBorder(
                                  borderRadius:
                                      const BorderRadius.all(Radius.circular(8)),
                                  side: const BorderSide(
                                      color: Color(0xFF616161), width: 2),
                                );
                              }
                              return const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              );
                            }),
                            todayForegroundColor:
                                const WidgetStatePropertyAll(Color(0xFF1976D2)),
                            todayBackgroundColor:
                                const WidgetStatePropertyAll(Color(0xFFE3F2FD)),
                            todayBorder: const BorderSide(
                                color: Color(0xFF1976D2), width: 1.5),
                          ),
                        ),
                        child: SizedBox(
                          height: calendarH,
                          child: CalendarDatePicker(
                            initialDate:
                                vm.selectedWeek.isBefore(now) ? vm.selectedWeek : now,
                            currentDate: now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: endOfCurrentWeek,
                            onDateChanged: (date) {
                              Navigator.of(ctx).pop();
                              vm.selectWeek(date);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                vm.goToCurrentWeek();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('This Week'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer<AnalyticsViewModel>(
      builder: (context, vm, _) {
        if (vm.userId == null || vm.userId!.isEmpty) {
          return const SizedBox.shrink();
        }
        return Row(
          children: [
            Expanded(
              child: StreamBuilder<TaskAnalytics>(
                stream: vm.taskAnalyticsStream,
                builder: (context, snap) {
                  final analytics = snap.data ?? TaskAnalytics.empty;
                  final pct = (analytics.completionRate * 100).round();
                  return _summaryCard(
                    context,
                    label: '$pct% Completion',
                    icon: Icons.check_circle_rounded,
                    iconBgColor: const Color(0xFF34C759).withOpacity(0.15),
                    iconColor: const Color(0xFF34C759),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<FocusAnalytics>(
                stream: vm.focusAnalyticsStream,
                builder: (context, snap) {
                  final analytics = snap.data ?? FocusAnalytics.empty;
                  return _summaryCard(
                    context,
                    label: '${analytics.totalFocusMinutes} Focus Min',
                    icon: Icons.timer_outlined,
                    iconBgColor: const Color(0xFFFF9500).withOpacity(0.15),
                    iconColor: const Color(0xFFFF9500),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsContent(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(999),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[800],
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Productivity'),
                Tab(text: 'Focus Timer'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 900,
            child: TabBarView(
              children: [
                _ProductivityTab(),
                _FocusTimerTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductivityTab extends StatefulWidget {
  @override
  State<_ProductivityTab> createState() => _ProductivityTabState();
}

class _ProductivityTabState extends State<_ProductivityTab> {
  @override
  void initState() {
    super.initState();
    // Trigger refresh when tab is first viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AnalyticsViewModel>();
      // Force refresh by triggering week change (no-op if same week)
      vm.selectWeek(vm.selectedWeek);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    if (vm.userId == null || vm.userId!.isEmpty) {
      return const Center(child: Text('Sign in to see productivity insights'));
    }
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _taskCompletionCard(context),
          const SizedBox(height: 16),
          _weeklyProductivityCard(context),
          const SizedBox(height: 16),
          _tasksByCategoryCard(context),
          const SizedBox(height: 16),
          _productivityScoreCard(context),
        ],
      ),
    );
  }

  Widget _taskCompletionCard(BuildContext context) {
    return StreamBuilder<TaskAnalytics>(
      stream: context.read<AnalyticsViewModel>().taskAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? TaskAnalytics.empty;
        final total = a.totalTasks;
        final completed = a.completedTasks;
        final progress = total > 0 ? completed / total : 0.0;
        return _whiteCard(
          context,
          title: 'Task Completion Rate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed $completed/$total',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You've completed $completed out of $total total tasks",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _weeklyProductivityCard(BuildContext context) {
    return StreamBuilder<TaskAnalytics>(
      stream: context.read<AnalyticsViewModel>().taskAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? TaskAnalytics.empty;
        final week = a.weeklyCompleted;
        final maxVal = week.isEmpty ? 1 : week.reduce((x, y) => x > y ? x : y);
        final maxHeight = 80.0;
        const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return _whiteCard(
          context,
          title: 'Weekly Productivity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: maxHeight + 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final val = i < week.length ? week[i] : 0;
                    final h = maxVal > 0 ? (val / maxVal) * maxHeight : 0.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: h.clamp(4.0, maxHeight),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i < labels.length ? labels[i] : '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tasksByCategoryCard(BuildContext context) {
    return StreamBuilder<TaskAnalytics>(
      stream: context.read<AnalyticsViewModel>().taskAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? TaskAnalytics.empty;
        final list = a.tasksByCategory;
        final maxCount = list.isEmpty ? 1 : list.map((c) => c.count).reduce((x, y) => x > y ? x : y);
        return _whiteCard(
          context,
          title: 'Tasks by Category',
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No tasks by category yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                )
              : Column(
                  children: list
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    c.categoryName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${c.count}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: maxCount > 0 ? (c.count / maxCount).clamp(0.0, 1.0) : 0,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _productivityScoreCard(BuildContext context) {
    return StreamBuilder<TaskAnalytics>(
      stream: context.read<AnalyticsViewModel>().taskAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? TaskAnalytics.empty;
        return _whiteCard(
          context,
          title: 'Productivity Score',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${a.productivityScore}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _whiteCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FocusTimerTab extends StatefulWidget {
  @override
  State<_FocusTimerTab> createState() => _FocusTimerTabState();
}

class _FocusTimerTabState extends State<_FocusTimerTab> {
  @override
  void initState() {
    super.initState();
    // Trigger refresh when tab is first viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AnalyticsViewModel>();
      // Force refresh by triggering week change (no-op if same week)
      vm.selectWeek(vm.selectedWeek);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    if (vm.userId == null || vm.userId!.isEmpty) {
      return const Center(child: Text('Sign in to see focus insights'));
    }
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _focusStatCard(context, 'Total Focus Sessions', (FocusAnalytics a) => '${a.totalSessions}'),
          const SizedBox(height: 16),
          _focusStatCard(context, 'Total Focus Time', (FocusAnalytics a) => '${a.totalFocusMinutes} min'),
          const SizedBox(height: 16),
          _focusStatCard(context, 'Average Focus Length', (FocusAnalytics a) => '${a.averageFocusLengthMinutes.toStringAsFixed(1)} min'),
          const SizedBox(height: 16),
          _focusStatCard(context, 'Total Interruptions', (FocusAnalytics a) => '${a.totalInterruptions}'),
          const SizedBox(height: 16),
          _focusScoreCard(context),
        ],
      ),
    );
  }

  Widget _focusStatCard(BuildContext context, String title, String Function(FocusAnalytics) value) {
    return StreamBuilder<FocusAnalytics>(
      stream: context.read<AnalyticsViewModel>().focusAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? FocusAnalytics.empty;
        return _whiteCard(
          context,
          title: title,
          child: Text(
            value(a),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }

  Widget _focusScoreCard(BuildContext context) {
    return StreamBuilder<FocusAnalytics>(
      stream: context.read<AnalyticsViewModel>().focusAnalyticsStream,
      builder: (context, snap) {
        final a = snap.data ?? FocusAnalytics.empty;
        return _whiteCard(
          context,
          title: 'Focus Score',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${a.focusScore}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _whiteCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
