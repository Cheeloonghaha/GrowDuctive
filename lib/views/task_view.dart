import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodels/task_viewmodel.dart';
import '../viewmodels/scheduled_task_viewmodel.dart';
import '../viewmodels/user_preferences_viewmodel.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/user_preferences_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/growductive_chrome.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_header.dart';
import '../widgets/calendar_week_strip.dart';
import '../widgets/glass_sheet.dart';
import '../navigation/sidebar_drawer_controller.dart';

/// Duration in minutes between [start] and [end] (end - start). Assumes same day.
int _minutesBetween(TimeOfDay start, TimeOfDay end) {
  final startM = start.hour * 60 + start.minute;
  final endM = end.hour * 60 + end.minute;
  return endM - startM;
}

class TaskScreen extends StatefulWidget {
  /// When true (default), shows bottom nav. Set to false when embedded in main shell.
  final bool showBottomNav;

  const TaskScreen({super.key, this.showBottomNav = true});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  int _selectedNavIndex = 1; // Tasks is now at index 1
  String _sortBy = 'date'; // 'date', 'urgency', 'importance', 'duration', 'priority'
  int _taskListPageIndex = 0; // 0 = Tasks (Active + Completed), 1 = Overdue
  bool _completedSectionExpanded = true; // expand/collapse Completed section
  DateTime _selectedDate = DateTime.now(); // date used to filter tasks by taskDate

  // Cache streams so setState() (e.g. changing _selectedDate) doesn't recreate
  // Firestore listeners on every rebuild.
  String? _cachedTaskUserId;
  String? _cachedPrefsUserId;
  Stream<List<TaskModel>>? _tasksStream;
  Stream<List<CategoryModel>>? _categoriesStream;
  Stream<UserPreferencesModel?>? _preferencesStream;

  @override
  Widget build(BuildContext context) {
    final taskVM = Provider.of<TaskViewModel>(context, listen: false);
    final prefsVM = Provider.of<UserPreferencesViewModel>(context, listen: false);

    final taskUid = taskVM.userId;
    final prefsUid = prefsVM.userId;
    if (_tasksStream == null ||
        _categoriesStream == null ||
        _preferencesStream == null ||
        _cachedTaskUserId != taskUid ||
        _cachedPrefsUserId != prefsUid) {
      _cachedTaskUserId = taskUid;
      _cachedPrefsUserId = prefsUid;
      _tasksStream = taskVM.tasksStream;
      _categoriesStream = taskVM.categoriesStream;
      _preferencesStream = prefsVM.preferencesStream;
    }

    final baseTheme = Theme.of(context);
    final compactTheme = baseTheme.copyWith(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    const fabEdge = FabLayout.edge;
    // Same FAB anchor as `calendar_view.dart`: `fabEdge` from right/bottom + safe inset.
    // When this screen shows its own bottom bar, lift the FAB above it (not used in MainShell).
    final fabBottom = widget.showBottomNav
        ? fabEdge + bottomPad + 72.0
        : fabEdge + bottomPad;

    return Theme(
      data: compactTheme,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Scaffold(
            backgroundColor: context.chrome.scaffoldBackground,
            body: SafeArea(
              child: Column(
                children: [
                  // HEADER SECTION (floating card)
                  _buildHeader(),
                  const SizedBox(height: 10),
                  // BODY SECTION
                  Expanded(
                    child: _buildBody(taskVM),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: widget.showBottomNav ? _buildFooter() : null,
          ),
          Positioned(
            right: fabEdge,
            bottom: fabBottom,
            child: _buildAddButton(context, taskVM),
          ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final chrome = context.chrome;
    final navBg = chrome.headerBar;
    final navBlue = chrome.navBlue;
    const menuCircleBg = Color(0xFF0F2E5C); // dark circle for menu button
    const double subtitleFontSize = 12.0;
    const double subtitleLineHeight = 1.2;
    final double subtitleBoxHeight = subtitleFontSize * subtitleLineHeight * 2;

    // Floating card like bottom nav: inset + shadow so it reads as elevated.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      children: [
                        Text(
                          'Tasks',
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
                            _monthYearLabel(_selectedDate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: navBlue.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w500,
                              fontSize: subtitleFontSize,
                              height: subtitleLineHeight,
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
                      onTap: _showDatePicker,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: navBlue,
                          size: 20,
                        ),
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
  }

  String _monthYearLabel(DateTime d) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: todayOnly.subtract(const Duration(days: 365)),
      lastDate: todayOnly.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  // ==================== BODY ====================
  Widget _buildBody(TaskViewModel taskVM) {
    return StreamBuilder<UserPreferencesModel?>(
      stream: _preferencesStream,
      builder: (context, prefSnap) {
        final weekStartsOn =
            prefSnap.data?.weekStartsOn ?? UserPreferencesModel.weekMonday;

        return StreamBuilder<List<TaskModel>>(
          stream: _tasksStream,
          builder: (context, taskSnapshot) {
            if (taskSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      "Error loading tasks",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 16),
              );
            }

            final allTasks = taskSnapshot.data ?? [];
            final weekStart = CalendarWeekStrip.weekStartContaining(
              _selectedDate,
              weekStartsOn,
            );

            final weekCounts = List.generate(7, (i) {
              final d = weekStart.add(Duration(days: i));
              final dayOnly = DateTime(d.year, d.month, d.day);
              return allTasks.where((t) => _isSameDay(t.taskDate, dayOnly)).length;
            });

            // Filter tasks by category
            return StreamBuilder<List<CategoryModel>>(
              stream: _categoriesStream,
              builder: (context, categorySnapshot) {
                final chrome = context.chrome;
                final categories = categorySnapshot.data ?? [];
                final categoryMap = {for (var c in categories) c.id: c.name};

                // Filter by category
                List<TaskModel> filteredTasks = allTasks;
                if (_selectedCategory != 'All') {
                  final selectedCategoryId = categories
                      .firstWhere(
                        (c) => c.name == _selectedCategory,
                        orElse: () => CategoryModel(id: '', name: ''),
                      )
                      .id;
                  filteredTasks = allTasks
                      .where((t) => t.categoryId == selectedCategoryId)
                      .toList();
                }

                // Overdue section: all overdue (not completed) tasks, not filtered by date
                final overdueTasks = _sortTasks(
                  filteredTasks.where((t) => t.overdue && !t.isCompleted).toList(),
                );

                // For Tasks tab:
                // - Active tasks: by creation day (created_at)
                // - Completed tasks: by completion day (completed_at)
                final tasksForSelectedDay = filteredTasks
                    .where((t) => _isSameDay(t.taskDate, _selectedDate))
                    .toList();

                final activeTasks = _sortTasks(
                  tasksForSelectedDay
                      .where((t) => !t.isCompleted && !t.overdue)
                      .toList(),
                );

                // Fallback to createdAt for legacy tasks that may not have completedAt populated.
                final completedTasks = _sortTasks(
                  filteredTasks
                      .where(
                        (t) => t.isCompleted &&
                            _isSameDay(t.completedAt ?? t.taskDate, _selectedDate),
                      )
                      .toList(),
                );

                final categoriesRow = categorySnapshot.hasData
                    ? SizedBox(
                        height: 38,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: chrome.segmentOuter,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: ['All', ...categories.map((c) => c.name)].length,
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, index) {
                                    final allNames = ['All', ...categories.map((c) => c.name)];
                                    final category = allNames[index];
                                    final isSelected = _selectedCategory == category;
                                    return _CategoryChip(
                                      category: category,
                                      isSelected: isSelected,
                                      isLast: index == allNames.length - 1,
                                      onTap: () =>
                                          setState(() => _selectedCategory = category),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showMoreMenu(context, taskVM, categories),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: chrome.segmentOuter,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'More',
                                      style: TextStyle(
                                        color: chrome.navBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Icons.arrow_drop_down,
                                        color: chrome.navBlue, size: 17),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(height: 38);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Surface-backed week strip + category picker, kept in-place via
                    // spacing compensation (see constants below).
                    Container(
                      color: chrome.scaffoldBackground,
                      child: Builder(
                        builder: (context) {
                          final navBlue = chrome.navBlue;
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                    onSurface: navBlue,
                                    primary: navBlue,
                                  ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: AppSpacing.md - AppSpacing.sm),
                                  CalendarWeekStrip(
                                    weekStart: weekStart,
                                    selectedDate: _selectedDate,
                                    onDaySelected: (d) => setState(() {
                                      _selectedDate =
                                          DateTime(d.year, d.month, d.day);
                                    }),
                                    onWeekShift: (delta) {
                                      final shifted = _selectedDate.add(
                                        Duration(days: 7 * delta),
                                      );
                                      setState(() {
                                        _selectedDate = DateTime(
                                          shifted.year,
                                          shifted.month,
                                          shifted.day,
                                        );
                                      });
                                    },
                                    taskCountsForWeek: weekCounts,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  categoriesRow,
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildTaskListSegmentControl(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _taskListPageIndex == 0
                          ? _buildTasksPage(
                              context,
                              taskVM,
                              activeTasks,
                              completedTasks,
                              categoryMap,
                            )
                          : _buildOverduePage(
                              context,
                              taskVM,
                              overdueTasks,
                              completedTasks,
                              categoryMap,
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTaskListSegmentControl() {
    final chrome = context.chrome;
    final outerBg = chrome.segmentOuter;
    final selectedBg = chrome.segmentSelectedFill;
    final selectedBorder = chrome.segmentBorder;
    final navBlue = chrome.navBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: outerBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _taskListPageIndex = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _taskListPageIndex == 0 ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: _taskListPageIndex == 0
                        ? Border.all(color: selectedBorder, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    'Tasks',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _taskListPageIndex == 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: navBlue,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _taskListPageIndex = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _taskListPageIndex == 1 ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: _taskListPageIndex == 1
                        ? Border.all(color: selectedBorder, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    'Overdue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _taskListPageIndex == 1
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: navBlue,
                      height: 1.0,
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

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildTasksPage(
    BuildContext context,
    TaskViewModel taskVM,
    List<TaskModel> activeTasks,
    List<TaskModel> completedTasks,
    Map<String, String> categoryMap,
  ) {
    if (activeTasks.isEmpty && completedTasks.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No tasks',
        message: "Tap 'Add Task' to create one",
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (activeTasks.isNotEmpty) ...[
            _buildSectionHeader('Tasks', activeTasks.length),
            const SizedBox(height: 12),
            ...activeTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTaskCard(context, taskVM, task, categoryMap),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (completedTasks.isNotEmpty) ...[
            _buildCompletedSectionHeader(completedTasks.length),
            if (_completedSectionExpanded) ...[
              const SizedBox(height: 12),
              ...completedTasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTaskCard(context, taskVM, task, categoryMap),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildOverduePage(
    BuildContext context,
    TaskViewModel taskVM,
    List<TaskModel> overdueTasks,
    List<TaskModel> completedTasks,
    Map<String, String> categoryMap,
  ) {
    if (overdueTasks.isEmpty && completedTasks.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No overdue or completed tasks',
        message: 'Complete tasks by their creation day to avoid overdue',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (overdueTasks.isNotEmpty) ...[
            _buildSectionHeader('Overdue', overdueTasks.length),
            const SizedBox(height: 12),
            ...overdueTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTaskCard(context, taskVM, task, categoryMap),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (completedTasks.isNotEmpty) ...[
            _buildCompletedSectionHeader(completedTasks.length),
            if (_completedSectionExpanded) ...[
              const SizedBox(height: 12),
              ...completedTasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildTaskCard(context, taskVM, task, categoryMap),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedSectionHeader(int count) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _completedSectionExpanded = !_completedSectionExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        child: Row(
          children: [
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const Spacer(),
            Icon(
              _completedSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 24,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return AppSectionHeader(title: title, badgeCount: count);
  }

  // Show More menu for category management
  void _showMoreMenu(BuildContext context, TaskViewModel vm, List<CategoryModel> categories) {
    final sheetBg = Theme.of(context).colorScheme.surfaceContainerHigh;
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMoreMenuOption(
                  ctx,
                  icon: Icons.filter_list_rounded,
                  label: 'Filter by',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSortDialog();
                  },
                ),
                const SizedBox(height: 8),
                _buildMoreMenuOption(
                  ctx,
                  icon: Icons.add_circle_outline,
                  label: 'Add Category',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddCategoryDialog(context, vm, null);
                  },
                ),
                _buildMoreMenuOption(
                  ctx,
                  icon: Icons.edit_outlined,
                  label: 'Edit Category',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditCategoryListDialog(context, vm, categories);
                  },
                ),
                _buildMoreMenuOption(
                  ctx,
                  icon: Icons.delete_outline,
                  label: 'Delete Category',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteCategoryListDialog(context, vm, categories);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = isDestructive ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: fg,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(CupertinoIcons.home, 'Home', 0),
              _buildNavItem(CupertinoIcons.checkmark_circle, 'Tasks', 1),
              _buildNavItem(CupertinoIcons.timer, 'Focus', 2),
              _buildNavItem(CupertinoIcons.chart_bar, 'Analytics', 3),
              _buildNavItem(CupertinoIcons.person, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        // TODO: Navigate to different pages
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, TaskViewModel taskVM) {
    // Match `CalendarSpeedDial` main FAB (calendar_view): navBlue fill, navBg icon, faded border.
    // Position comes from parent `Stack` + `Positioned` (same as calendar).
    final chrome = context.chrome;
    final navBlue = chrome.navBlue;
    final navBg = chrome.headerBar;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              onSurface: navBlue,
              primary: navBlue,
              surface: navBg,
            ),
      ),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return FloatingActionButton(
            heroTag: 'task_screen_add_fab',
            elevation: 6,
            onPressed: () => _showAddTaskDialog(context, taskVM),
            tooltip: 'Add task',
            backgroundColor: scheme.onSurface,
            shape: CircleBorder(
              side: BorderSide(
                color: scheme.surface.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.add_rounded,
              color: scheme.surface,
              size: 26,
            ),
          );
        },
      ),
    );
  }

  /// Full-width task card (consistent size, padding, and chip row for every task).
  Widget _buildTaskCard(
    BuildContext context,
    TaskViewModel vm,
    TaskModel task,
    Map<String, String> categoryMap,
  ) {
    final categoryName = categoryMap[task.categoryId] ?? 'Unknown';
    final pastel = AppColors.categoryPastelFor(task.categoryId);
    final onPastel = AppColors.categoryOnPastel(task.categoryId);
    final urgencyAccent = task.urgency >= 4 ? AppColors.softGold : AppColors.interactive;
    final importanceAccent =
        task.importance >= 4 ? AppColors.softGold : AppColors.interactive;
    const titleSize = 13.0;
    const pad = 12.0;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final cardBg = isDark ? scheme.surfaceContainerHigh : AppColors.surface;
    final cardBorder = task.overdue
        ? AppColors.coral
        : (isDark
            ? scheme.outline.withValues(alpha: 0.38)
            : AppColors.borderSubtle);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showViewTaskDialog(
          context,
          vm,
          task,
          categoryName: categoryName,
          categoryPastel: pastel,
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: cardBorder,
              width: task.overdue ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
                blurRadius: isDark ? 12 : 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!task.isCompleted) {
                          HapticFeedback.mediumImpact();
                        } else {
                          HapticFeedback.selectionClick();
                        }
                        vm.toggleComplete(
                          task.id,
                          task.isCompleted,
                          taskCreatedAt: task.createdAt,
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: task.isCompleted ? AppColors.jade : AppColors.borderSubtle,
                            width: 2,
                          ),
                          color: task.isCompleted ? AppColors.jade : Colors.transparent,
                        ),
                        child: task.isCompleted
                            ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: task.isCompleted
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _showEditTaskDialog(context, vm, task),
                          icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant, size: 20),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _confirmDelete(context, vm, task),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.coral.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Category
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pastel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: onPastel,
                        ),
                      ),
                    ),
                    // Urgency
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded, size: 12, color: urgencyAccent),
                          const SizedBox(width: 4),
                          Text(
                            'U${task.urgency}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: urgencyAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Importance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: importanceAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: importanceAccent),
                          const SizedBox(width: 4),
                          Text(
                            'I${task.importance}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: importanceAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.duration} min',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // View task details dialog - improved information layout
  void _showViewTaskDialog(
    BuildContext context,
    TaskViewModel vm,
    TaskModel task, {
    required String categoryName,
    required Color categoryPastel,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Category-accent color used across border + stripe.
    final borderColor = Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22),
      categoryPastel,
    );
    final titleColor = scheme.onSurface;
    final bodyColor = scheme.onSurface.withValues(alpha: 0.72);

    String prettyDuration(int minutes) {
      if (minutes <= 0) return '0m';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (h <= 0) return '${m}m';
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 3.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Category stripe for stronger emphasis.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  color: borderColor,
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: borderColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: borderColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.task_alt, color: borderColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Task Details",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.close,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Category chip
                            Text(
                              task.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                height: 1.15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: categoryPastel.withValues(
                                      alpha: isDark ? 0.22 : 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: borderColor.withValues(alpha: 0.95),
                                      width: 1.25,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sell_outlined,
                                        size: 16,
                                        color: borderColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        categoryName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: titleColor,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusPill(context, task),
                              ],
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                task.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: bodyColor,
                                  height: 1.45,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),

                            // Metrics
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildDetailMetric(
                                  context,
                                  label: 'Duration',
                                  value: prettyDuration(task.duration),
                                  icon: Icons.timer_outlined,
                                  accent: borderColor,
                                ),
                                _buildDetailMetric(
                                  context,
                                  label: 'Urgency',
                                  value: '${task.urgency}/5',
                                  icon: Icons.flag_outlined,
                                  accent: borderColor,
                                ),
                                _buildDetailMetric(
                                  context,
                                  label: 'Importance',
                                  value: '${task.importance}/5',
                                  icon: Icons.star_outline,
                                  accent: borderColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
              
                    // Action Buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showEditTaskDialog(context, vm, task);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                foregroundColor: scheme.onSurface,
                                side: BorderSide(
                                  color: borderColor.withValues(alpha: 0.65),
                                  width: 1.25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Edit",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                vm.toggleComplete(
                                  task.id,
                                  task.isCompleted,
                                  taskCreatedAt: task.createdAt,
                                );
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: borderColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                task.isCompleted ? "Reopen" : "Complete",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, TaskModel task) {
    final scheme = Theme.of(context).colorScheme;
    final label = task.isCompleted
        ? 'Completed'
        : (task.overdue ? 'Overdue' : 'Active');
    final icon = task.isCompleted
        ? Icons.check_circle
        : (task.overdue ? Icons.warning_amber_rounded : Icons.radio_button_unchecked);
    final Color accent = task.isCompleted
        ? Colors.green
        : (task.overdue ? Colors.red : scheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  // Confirm delete dialog - Redesigned to match consistent design
  void _confirmDelete(BuildContext context, TaskViewModel vm, TaskModel task) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Delete Task",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Are you sure you want to delete '${task.title}'?",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "This action cannot be undone.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final dialogContext = context;
                            final prefs = await Provider.of<UserPreferencesViewModel>(dialogContext, listen: false)
                                .fetchPreferences();
                            try {
                              await vm.deleteTask(task.id, userPrefs: prefs);
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: const Text('Task deleted'),
                                  backgroundColor: Colors.black,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Could not delete task: $e'),
                                  backgroundColor: Colors.red.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show dialog to edit task - Redesigned to match Add Task dialog
  void _showEditTaskDialog(BuildContext parentContext, TaskViewModel vm, TaskModel task) {
    final navigator = Navigator.of(parentContext);
    final messenger = ScaffoldMessenger.of(parentContext);
    final scheduledVM = Provider.of<ScheduledTaskViewModel>(parentContext, listen: false);

    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final int initialDuration = (task.startTime != null && task.endTime != null && task.endTime! > task.startTime!)
        ? (task.endTime! - task.startTime!)
        : task.duration;
    final durationController = TextEditingController(text: initialDuration.toString());
    int urgency = task.urgency;
    int importance = task.importance;
    String selectedCategoryId = task.categoryId;
    TimeOfDay? startTimeOfDay = task.startTime != null
        ? TimeOfDay(hour: task.startTime! ~/ 60, minute: task.startTime! % 60)
        : null;
    TimeOfDay? endTimeOfDay = task.endTime != null
        ? TimeOfDay(hour: task.endTime! ~/ 60, minute: task.endTime! % 60)
        : null;
    String? editDialogError;

    showDialog(
      context: parentContext,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                      const Icon(Icons.edit, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Edit Task",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Task Title
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: "Task Title",
                            hintText: "Enter task title",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextField(
                          controller: descriptionController,
                          decoration: InputDecoration(
                            labelText: "Description (Optional)",
                            hintText: "Enter task description",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Duration
                        TextField(
                          controller: durationController,
                          onChanged: (_) => setState(() => editDialogError = null),
                          decoration: InputDecoration(
                            labelText: "Duration (minutes)",
                            hintText: "e.g., 30",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // Start time (optional)
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (picked != null) {
                              setState(() {
                                editDialogError = null;
                                startTimeOfDay = picked;
                                if (endTimeOfDay != null) {
                                  final mins = _minutesBetween(picked, endTimeOfDay!);
                                  if (mins > 0) durationController.text = mins.toString();
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Start time (optional)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            child: Text(
                              startTimeOfDay != null
                                  ? startTimeOfDay!.format(context)
                                  : "Not set",
                              style: TextStyle(
                                fontSize: 16,
                                color: startTimeOfDay != null ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        if (startTimeOfDay != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  startTimeOfDay = null;
                                  // When clearing start time, we no longer auto-sync duration from times
                                  // so leave durationController as-is.
                                });
                              },
                              child: const Text('Clear start time'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // End time (optional)
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTimeOfDay ?? startTimeOfDay ?? const TimeOfDay(hour: 10, minute: 0),
                            );
                            if (picked != null) {
                              setState(() {
                                editDialogError = null;
                                endTimeOfDay = picked;
                                if (startTimeOfDay != null) {
                                  final mins = _minutesBetween(startTimeOfDay!, picked);
                                  if (mins > 0) durationController.text = mins.toString();
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "End time (optional)",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            child: Text(
                              endTimeOfDay != null
                                  ? endTimeOfDay!.format(context)
                                  : "Not set",
                              style: TextStyle(
                                fontSize: 16,
                                color: endTimeOfDay != null ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        if (endTimeOfDay != null) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  endTimeOfDay = null;
                                  // When clearing end time, keep duration as typed.
                                });
                              },
                              child: const Text('Clear end time'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Category Dropdown
                        StreamBuilder<List<CategoryModel>>(
                          stream: vm.categoriesStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final categories = snapshot.data!;
                            return DropdownButtonFormField<String>(
                              value: selectedCategoryId.isEmpty ? null : selectedCategoryId,
                              decoration: InputDecoration(
                                labelText: "Category",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              items: categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category.id,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedCategoryId = value ?? '';
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Urgency Slider
                        Text(
                          "Urgency Level",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: Colors.black,
                                  inactiveTrackColor: Colors.grey[300],
                                  thumbColor: Colors.black,
                                  overlayColor: Colors.black.withOpacity(0.1),
                                ),
                                child: Slider(
                                  value: urgency.toDouble(),
                                  min: 1,
                                  max: 5,
                                  divisions: 4,
                                  label: urgency.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      urgency = value.toInt();
                                    });
                                  },
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  urgency.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Importance Slider
                        Text(
                          "Importance Level",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: Colors.black,
                                  inactiveTrackColor: Colors.grey[300],
                                  thumbColor: Colors.black,
                                  overlayColor: Colors.black.withOpacity(0.1),
                                ),
                                child: Slider(
                                  value: importance.toDouble(),
                                  min: 1,
                                  max: 5,
                                  divisions: 4,
                                  label: importance.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      importance = value.toInt();
                                    });
                                  },
                                ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Text(
                                  importance.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (editDialogError != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              editDialogError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty || selectedCategoryId.isEmpty) {
                              String errorMsg = "Please enter a task title";
                              if (selectedCategoryId.isEmpty) {
                                errorMsg = "Please select a category";
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(errorMsg),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final startM = startTimeOfDay != null
                                ? startTimeOfDay!.hour * 60 + startTimeOfDay!.minute
                                : null;
                            final endM = endTimeOfDay != null
                                ? endTimeOfDay!.hour * 60 + endTimeOfDay!.minute
                                : null;
                            if (startM != null && endM != null) {
                              if (endM <= startM) {
                                setState(() => editDialogError = 'End time must be after start time.');
                                return;
                              }
                              final durationMins = int.tryParse(durationController.text);
                              final expectedDuration = endM - startM;
                              if (durationMins == null || durationMins != expectedDuration) {
                                setState(() => editDialogError =
                                    'Duration must match start–end time ($expectedDuration min). Adjust times or duration.');
                                return;
                              }
                            }
                            await vm.updateTask(
                              id: task.id,
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              urgency: urgency,
                              importance: importance,
                              duration: int.tryParse(durationController.text) ?? 30,
                              categoryId: selectedCategoryId,
                              startTime: startM,
                              endTime: endM,
                            );
                            if (startM != null && endM != null) {
                              try {
                                await scheduledVM.updateOrCreateScheduledTasksForTask(
                                  taskId: task.id,
                                  startTimeMinutes: startM,
                                  endTimeMinutes: endM,
                                  scheduleDate: task.taskDate,
                                  taskName: titleController.text.trim(),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Task updated; calendar sync failed: $e'),
                                    backgroundColor: Colors.orange,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text("Task updated successfully!"),
                                backgroundColor: Colors.black,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Update Task",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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

  /// Grouped “bento” block inside the add-task sheet (spacing + soft glass card).
  Widget _buildAddTaskSheetSection({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final cardFill = isDark
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.52);
    final cardBorder = isDark
        ? scheme.outline.withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.72);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cardFill,
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.interactive.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: AppColors.interactive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  /// Add task in a glassmorphism bottom sheet (blur + frosted panel).
  void _showAddTaskDialog(BuildContext context, TaskViewModel vm) {
    final taskScreen = this;
    final pageContext = context;
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    int urgency = 3;
    int importance = 3;
    String? selectedCategoryId;
    TimeOfDay? startTimeOfDay;
    TimeOfDay? endTimeOfDay;
    String? addDialogError;
    var taskDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        final maxH = (MediaQuery.sizeOf(sheetContext).height * 0.92 - viewInsets.bottom).clamp(280.0, 900.0);

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
                    final borderRadius = BorderRadius.circular(14);
                    final borderColor =
                        isDark ? scheme.outline.withValues(alpha: 0.55) : AppColors.borderSubtle;
                    final outlineBorder = OutlineInputBorder(
                      borderRadius: borderRadius,
                      borderSide: BorderSide(color: borderColor),
                    );
                    final focusBorder = OutlineInputBorder(
                      borderRadius: borderRadius,
                      borderSide: BorderSide(color: scheme.primary, width: 2),
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
                          decoration: const BoxDecoration(
                            color: AppColors.interactive,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.add_task_rounded, color: Colors.white, size: 26),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Add New Task',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    Text(
                                      'A few quick sections — scroll if needed',
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
                                _buildAddTaskSheetSection(
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
                                _buildAddTaskSheetSection(
                                  context: context,
                                  title: 'Schedule',
                                  subtitle:
                                      'Choose the day and how long it takes. Set both start and end time to place it on your calendar.',
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
                                              addDialogError = null;
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
                                      onChanged: (_) => setSheetState(() => addDialogError = null),
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
                                                  initialTime: startTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
                                                );
                                                if (picked != null) {
                                                  setSheetState(() {
                                                    addDialogError = null;
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
                                                    addDialogError = null;
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
                                _buildAddTaskSheetSection(
                                  context: context,
                                  title: 'Category',
                                  subtitle: 'Organize tasks by area of life.',
                                  icon: Icons.folder_outlined,
                                  children: [
                                    StreamBuilder<List<CategoryModel>>(
                                      stream: vm.categoriesStream,
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(vertical: 20),
                                              child: CircularProgressIndicator(color: AppColors.interactive),
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
                                _buildAddTaskSheetSection(
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
                                              activeTrackColor: AppColors.interactive,
                                              inactiveTrackColor: inactiveSlider,
                                              thumbColor: AppColors.interactive,
                                              overlayColor: AppColors.interactive.withValues(alpha: 0.12),
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
                        if (addDialogError != null)
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
                                  const Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      addDialogError!,
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
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: scheme.onSurface,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                  onPressed: () async {
                                    if (titleController.text.trim().isEmpty || selectedCategoryId == null) {
                                      var errorMsg = 'Please enter a task title';
                                      if (selectedCategoryId == null) errorMsg = 'Please select a category';
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
                                        setSheetState(() => addDialogError = 'End time must be after start time.');
                                        return;
                                      }
                                      final durationMins = int.tryParse(durationController.text);
                                      final expectedDuration = endM - startM;
                                      if (durationMins == null || durationMins != expectedDuration) {
                                        setSheetState(() => addDialogError =
                                            'Duration must match start–end time ($expectedDuration min). Set start and end time again or adjust duration.');
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
                                    final scheduledVM = Provider.of<ScheduledTaskViewModel>(sheetContext, listen: false);
                                    final taskId = await vm.addTask(
                                      title: titleController.text.trim(),
                                      description: descriptionController.text.trim(),
                                      urgency: urgency,
                                      importance: importance,
                                      duration: duration,
                                      categoryId: selectedCategoryId!,
                                      taskDate: taskDay,
                                      startTime: startM,
                                      endTime: endM,
                                    );
                                    if (!sheetContext.mounted) return;
                                    navigator.pop();
                                    if (!pageContext.mounted) return;
                                    if (taskId != null && taskScreen.mounted) {
                                      taskScreen.setState(() {
                                        _selectedDate = taskDay;
                                      });
                                    }
                                    if (taskId != null && startM != null && endM != null) {
                                      try {
                                        await scheduledVM.addScheduledTask(
                                          taskId: taskId,
                                          scheduleDate: taskDay,
                                          startTimeMinutes: startM,
                                          endTimeMinutes: endM,
                                          taskName: titleController.text.trim(),
                                        );
                                        if (!pageContext.mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text('Task added and added to calendar!'),
                                            backgroundColor: AppColors.interactive,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        );
                                      } catch (_) {
                                        if (!pageContext.mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text('Task added (calendar schedule failed).'),
                                            backgroundColor: AppColors.softGold,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text('Task added successfully!'),
                                          backgroundColor: AppColors.interactive,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.interactive,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: const Text(
                                    'Add Task',
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




  // Show dialog to add custom category - Redesigned
  void _showAddCategoryDialog(
    BuildContext context,
    TaskViewModel vm,
    Function(String)? onCategoryAdded,
  ) {
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.add_circle, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Add Category",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: "Category Name",
                    hintText: "e.g., Bakery",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (categoryController.text.trim().isNotEmpty) {
                            final categoryId = await vm.addCategory(categoryController.text.trim());
                            if (categoryId != null) {
                              Navigator.pop(context);
                              onCategoryAdded?.call(categoryId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Category '${categoryController.text.trim()}' added!"),
                                  backgroundColor: Colors.black,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please enter a category name")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Add",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  // Show list of categories to edit
  void _showEditCategoryListDialog(BuildContext context, TaskViewModel vm, List<CategoryModel> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No categories to edit")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.edit, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Edit Category",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Category List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showRenameCategoryDialog(context, vm, category);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show list of categories to delete
  void _showDeleteCategoryListDialog(BuildContext context, TaskViewModel vm, List<CategoryModel> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No categories to delete")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Delete Category",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Category List
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      title: Text(category.name),
                      trailing: const Icon(Icons.delete_outline, color: Colors.red),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteCategory(context, vm, category);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Rename category dialog
  void _showRenameCategoryDialog(BuildContext context, TaskViewModel vm, CategoryModel category) {
    final controller = TextEditingController(text: category.name);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Rename Category",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: "Category Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        vm.updateCategory(category.id, controller.text.trim());
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Category renamed successfully!"),
                            backgroundColor: Colors.black,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Rename", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Confirm delete category dialog - Redesigned to match consistent design
  void _confirmDeleteCategory(BuildContext context, TaskViewModel vm, CategoryModel category) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Delete Category",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Are you sure you want to delete '${category.name}'?",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "This action cannot be undone. Categories with existing tasks cannot be deleted.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await vm.deleteCategory(category.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("Category deleted"),
                                  backgroundColor: Colors.black,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sort tasks based on selected sort option
  List<TaskModel> _sortTasks(List<TaskModel> tasks) {
    final sortedTasks = List<TaskModel>.from(tasks);
    
    switch (_sortBy) {
      case 'urgency':
        sortedTasks.sort((a, b) => b.urgency.compareTo(a.urgency));
        break;
      case 'importance':
        sortedTasks.sort((a, b) => b.importance.compareTo(a.importance));
        break;
      case 'priority':
        int score(TaskModel t) => t.urgency + t.importance;
        sortedTasks.sort((a, b) => score(b).compareTo(score(a)));
        break;
      case 'duration':
        sortedTasks.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      case 'date':
      default:
        sortedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return sortedTasks;
  }

  // Get label for current sort option
  String _getSortLabel() {
    switch (_sortBy) {
      case 'urgency':
        return 'Urgency';
      case 'importance':
        return 'Importance';
      case 'priority':
        return 'Priority';
      case 'duration':
        return 'Duration';
      case 'date':
      default:
        return 'Date';
    }
  }

  // Show sort dialog
  void _showSortDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                    const Icon(Icons.sort, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Sort Tasks",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              // Sort Options
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildSortOption('date', 'Date Created', Icons.calendar_today_outlined),
                    _buildSortOption('priority', 'Priority (U+I)', Icons.bolt_outlined),
                    _buildSortOption('urgency', 'Urgency', Icons.flag_outlined),
                    _buildSortOption('importance', 'Importance', Icons.star_outline),
                    _buildSortOption('duration', 'Duration', Icons.access_time_outlined),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build sort option item
  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: isSelected ? Colors.grey[100] : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.grey[800],
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Colors.black,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Category Chip Widget with Hover Animation
class _CategoryChip extends StatefulWidget {
  final String category;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.chrome;
    final selectedBg = chrome.segmentSelectedFill;
    final selectedBorder = chrome.segmentBorder;
    const unselectedBg = Colors.transparent; // unselected = just text on outer pill
    final navBlue = chrome.navBlue;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _animationController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _animationController.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _animationController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            margin: EdgeInsets.only(
              right: !widget.isLast ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: widget.isSelected ? selectedBg : unselectedBg,
              borderRadius: BorderRadius.circular(16),
              border: widget.isSelected
                  ? Border.all(color: selectedBorder, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center, // Center align the content
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: navBlue,
                fontSize: 13,
                fontWeight: widget.isSelected 
                    ? FontWeight.w600 
                    : (_isHovered ? FontWeight.w600 : FontWeight.w500),
                height: 1.0, // Consistent line height
              ),
              textAlign: TextAlign.center,
              child: Text(
                widget.category,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
