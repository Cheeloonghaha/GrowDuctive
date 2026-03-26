import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../navigation/sidebar_drawer_controller.dart';

/// Task / focus timer bar palette (category row + segment pills).
const _axOuter = Color(0xFFD6E6FF);
const _axFill = Color(0xFFEAF3FF);
const _axBorder = Color(0xFFB6D3FF);
const _axBlue = Color(0xFF103A8A);

/// Standard analytics typography: section titles larger than body values.
const double _kTitleCard = 18;
const double _kDialogTitle = 20;
const double _kStatLineTitle = 14;
const double _kStatLineValue = 12;
const double _kBody = 13;
const double _kCaption = 11;
const double _kTab = 14;
const double _kWeekDate = 14;
const double _kScoreHero = 40;
const double _kScoreDenom = 20;
/// Focus Timer tab: metric values (larger + bolder than body for scanability).
const double _kFocusMetricValue = 24;

class AnalyticsView extends StatelessWidget {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base,
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
    final theme = Theme.of(context);
    // Must match `MainShell` bottom-nav colors for consistent look.
    const navBg = Color(0xFFEAF3FF); // light blue header background
    const navBlue = Color(0xFF103A8A); // darker blue for title
    const menuCircleBg = Color(0xFF0F2E5C); // dark circle for menu button
    const double subtitleFontSize = 12.0;
    const double subtitleLineHeight = 1.2;
    final double subtitleBoxHeight = subtitleFontSize * subtitleLineHeight * 2;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: navBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF132A5D).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Analytics',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: navBlue,
                          fontSize: 21,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: subtitleBoxHeight,
                        child: Text(
                          'Torture the data, and it will confess to anything. — Ronald Coase',
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
              ],
            ),
          ),
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
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _axOuter,
                borderRadius: BorderRadius.circular(25),
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
                        color: _axBlue,
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
                            color: _axBlue,
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Flexible(
                            child: Text(
                              vm.selectedWeekLabel,
                              style: TextStyle(
                                fontSize: compact ? _kBody : _kWeekDate,
                                fontWeight: FontWeight.w600,
                                color: _axBlue,
                              ),
                              maxLines: 2,
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
                                  color: _axBorder.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _axFill,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _axBorder, width: 1),
                                ),
                                child: const Text(
                                  'This week',
                                  style: TextStyle(
                                    fontSize: _kCaption,
                                    fontWeight: FontWeight.w600,
                                    color: _axBlue,
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
                        color: vm.canGoToNextWeek
                            ? _axBlue
                            : _axBlue.withValues(alpha: 0.35),
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
                          fontSize: _kDialogTitle,
                          fontWeight: FontWeight.bold,
                          color: _axBlue,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Theme(
                        data: Theme.of(ctx).copyWith(
                          datePickerTheme: DatePickerThemeData(
                            dayForegroundColor:
                                const WidgetStatePropertyAll(_axBlue),
                            dayBackgroundColor: WidgetStateProperty.resolveWith(
                                (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return _axFill;
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
                                      color: _axBorder, width: 2),
                                );
                              }
                              return const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              );
                            }),
                            todayForegroundColor:
                                const WidgetStatePropertyAll(_axBlue),
                            todayBackgroundColor:
                                const WidgetStatePropertyAll(_axFill),
                            todayBorder: const BorderSide(
                                color: _axBlue, width: 1.5),
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
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _axBlue,
                                side: const BorderSide(color: _axBorder, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                                backgroundColor: _axBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'This week',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                    title: 'Completion rate',
                    value: '$pct%',
                    icon: Icons.check_circle_rounded,
                    iconBgColor: _axFill,
                    iconColor: _axBlue,
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
                    title: 'Focus time',
                    value: '${analytics.totalFocusMinutes} min',
                    icon: Icons.timer_outlined,
                    iconBgColor: _axFill,
                    iconColor: _axBlue,
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
    required String title,
    required String value,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: _axBorder, width: 1),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: _kStatLineTitle,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: _axBlue,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _kStatLineValue,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: _axBlue.withValues(alpha: 0.88),
                  ),
                  maxLines: 2,
                ),
              ],
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
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _axOuter,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              padding: EdgeInsets.zero,
              indicatorPadding: EdgeInsets.zero,
              indicator: BoxDecoration(
                color: _axFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _axBorder, width: 2),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: _axBlue,
              unselectedLabelColor: _axBlue,
              labelStyle: const TextStyle(
                fontSize: _kTab,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: _kTab,
                fontWeight: FontWeight.w500,
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
      return Center(
        child: Text(
          'Sign in to see productivity insights',
          style: TextStyle(
            fontSize: _kBody,
            fontWeight: FontWeight.w500,
            color: _axBlue.withValues(alpha: 0.75),
          ),
          textAlign: TextAlign.center,
        ),
      );
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
                  fontSize: _kBody,
                  fontWeight: FontWeight.w600,
                  color: _axBlue,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: _axOuter,
                  valueColor: const AlwaysStoppedAnimation<Color>(_axBlue),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You've completed $completed out of $total total tasks",
                style: TextStyle(
                  fontSize: _kCaption,
                  color: _axBlue.withValues(alpha: 0.55),
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
                                color: _axBlue.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              i < labels.length ? labels[i] : '',
                              style: TextStyle(
                                fontSize: _kCaption,
                                color: _axBlue.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
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
                    style: TextStyle(
                      fontSize: _kBody,
                      color: _axBlue.withValues(alpha: 0.55),
                    ),
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
                                      fontSize: _kBody,
                                      fontWeight: FontWeight.w600,
                                      color: _axBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${c.count}',
                                  style: const TextStyle(
                                    fontSize: _kBody,
                                    color: _axBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: maxCount > 0 ? (c.count / maxCount).clamp(0.0, 1.0) : 0,
                                      minHeight: 8,
                                      backgroundColor: _axOuter,
                                      valueColor: const AlwaysStoppedAnimation<Color>(_axBlue),
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
                  fontSize: _kScoreHero,
                  fontWeight: FontWeight.bold,
                  color: _axBlue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: _kScoreDenom,
                  fontWeight: FontWeight.w500,
                  color: _axBlue.withValues(alpha: 0.45),
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
              fontSize: _kTitleCard,
              fontWeight: FontWeight.w600,
              color: _axBlue,
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
      return Center(
        child: Text(
          'Sign in to see focus insights',
          style: TextStyle(
            fontSize: _kBody,
            fontWeight: FontWeight.w500,
            color: _axBlue.withValues(alpha: 0.75),
          ),
          textAlign: TextAlign.center,
        ),
      );
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
              fontSize: _kFocusMetricValue,
              fontWeight: FontWeight.bold,
              height: 1.25,
              letterSpacing: -0.3,
              color: _axBlue,
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
                  fontSize: _kScoreHero,
                  fontWeight: FontWeight.bold,
                  color: _axBlue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: _kScoreDenom,
                  fontWeight: FontWeight.w500,
                  color: _axBlue.withValues(alpha: 0.45),
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
              fontSize: _kTitleCard,
              fontWeight: FontWeight.w600,
              color: _axBlue,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
