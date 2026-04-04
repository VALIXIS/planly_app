import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'focus_mode_screen.dart';
import 'package:flutter/services.dart';
import '../../../services/app_state_service.dart';
import '../../../services/task_action_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import 'add_task_screen.dart';
import '../../../services/notification_service.dart';
import 'daily_reflection_screen.dart';
import 'widgets/home_group_header.dart';

// ─────────────────────────────────────────────────────
// Group header widget
enum FilterType { all, today, upcoming, pending, completed }

class _TaskListRow {
  final String? headerLabel;
  final int? headerCount;
  final Color? headerColor;
  final IconData? headerIcon;
  final Task? task;

  const _TaskListRow.header({
    required this.headerLabel,
    required this.headerCount,
    required this.headerColor,
    required this.headerIcon,
  }) : task = null;

  const _TaskListRow.task(this.task)
      : headerLabel = null,
        headerCount = null,
        headerColor = null,
        headerIcon = null;

  bool get isHeader => task == null;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen> {
            // Group header icons for visual interest (moved above usage)
            IconData? _groupHeaderIcon(String group) {
              switch (group) {
                case "Overdue":
                  return Icons.warning_amber_rounded;
                case "Now":
                  return Icons.flash_on_rounded;
                case "Later Today":
                  return Icons.schedule_rounded;
                case "Tomorrow":
                  return Icons.wb_sunny_rounded;
                case "This Week":
                  return Icons.calendar_today_rounded;
                case "Later":
                  return Icons.upcoming_rounded;
                case "Anytime":
                  return Icons.all_inclusive_rounded;
                default:
                  return null;
              }
            }
        // Show a different quote than splash screen, but based on time and day
        final List<List<String>> _quotesBySlot = [
          [
            "Every morning brings new potential.",
            "Let today be the start of something new.",
            "Opportunities are born every morning.",
            "Wake up and chase your dreams.",
            "A positive morning leads to a productive day.",
            "Start your day with intention.",
            "The sun rises for you today.",
            "Make your morning count.",
            "Embrace the possibilities of today.",
            "A new day, a new chance.",
            "Let gratitude be your morning mantra.",
            "Today is yours to shape.",
            "Begin with a smile and purpose.",
            "Let your actions set the tone.",
            "Make your morning meaningful.",
          ],
          [
            "Keep building your momentum.",
            "Let the afternoon fuel your progress.",
            "Stay focused and finish strong.",
            "Every step forward is a win.",
            "Let your work speak for itself.",
            "Push through, you're halfway there.",
            "Let your passion drive your afternoon.",
            "Stay determined, stay productive.",
            "Let your goals guide your actions.",
            "Every effort counts.",
            "Make the most of your afternoon.",
            "Stay inspired, keep going.",
            "Let your energy shine through.",
            "Progress is progress, no matter how small.",
            "Your afternoon matters.",
          ],
          [
            "Reflect, relax, and recharge.",
            "Let the evening bring you peace.",
            "Celebrate your wins, big or small.",
            "Rest is part of the process.",
            "Let gratitude end your day.",
            "Prepare for tomorrow with intention.",
            "Let go of what you can't control.",
            "Find joy in your evening routine.",
            "Rest well, you've earned it.",
            "Let your mind unwind.",
            "Evenings are for reflection.",
            "Recharge for a new day ahead.",
            "Let calmness fill your night.",
            "End your day with hope.",
            "Peaceful evenings, productive tomorrows.",
          ],
        ];

        String get _todayQuote {
          final hour = DateTime.now().hour;
          int slot;
          if (hour < 12) {
            slot = 0;
          } else if (hour < 17) {
            slot = 1;
          } else {
            slot = 2;
          }
          final quotes = _quotesBySlot[slot];
          // Offset by +1 day from splash so it's always different
          final dayIndex = (DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays + 1) % quotes.length;
          return quotes[dayIndex];
        }

        void _exitSelectionMode() {
          setState(() {
            _isSelectionMode = false;
            _selectedKeys.clear();
          });
        }

        String _dateStamp(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

        Future<void> _setTaskCompletion(Task task, bool complete) async {
          final changed =
              await TaskActionService.setTaskCompletion(task, complete);
          if (changed && complete) {
            _confettiController.play();
          }
        }

        Future<void> _bulkComplete(bool complete) async {
          final box = Hive.box<Task>('tasks');
          final selectedTasks = _selectedKeys
              .map((key) => box.get(key))
              .whereType<Task>()
              .toList();

          for (final task in selectedTasks) {
            await _setTaskCompletion(task, complete);
          }

          if (mounted) _exitSelectionMode();
        }

        Future<void> _bulkDelete() async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Delete Selected Tasks'),
              content: Text(
                'Delete ${_selectedKeys.length} selected task(s)? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirmed != true) return;

          final box = Hive.box<Task>('tasks');
          final selectedTasks = _selectedKeys
              .map((key) => box.get(key))
              .whereType<Task>()
              .toList();

          for (final task in selectedTasks) {
            final key = task.key;
            if (key is int) {
              await NotificationService().cancelNotification(key);
            }
            await task.delete();
          }

          if (mounted) {
            _exitSelectionMode();
            AppStateService.rootScaffoldMessengerKey.currentState
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('${selectedTasks.length} task(s) deleted'),
                ),
              );
          }
        }
      int _streak = 0;
      String? _lastStreakAwardDate;
      String? _lastReflectionDate;
      bool _isReflectionOpen = false;

      void _checkAndUpdateStreak(List<Task> todayTasks) {
        if (todayTasks.isEmpty || todayTasks.any((task) => !task.isCompleted)) {
          return;
        }

        final todayStamp = _dateStamp(DateTime.now());
        if (_lastStreakAwardDate == todayStamp) return;

        _lastStreakAwardDate = todayStamp;
        _streak += 1;
        Hive.box('settings')
          ..put('taskStreakCount', _streak)
          ..put('lastStreakAwardDate', todayStamp);

        if (mounted) {
          setState(() {});
        }
      }

      void _maybeShowReflection(double pct, int completed, int total) {
        if (!mounted || total == 0 || completed < total || _isReflectionOpen) {
          return;
        }

        final todayStamp = _dateStamp(DateTime.now());
        if (_lastReflectionDate == todayStamp) return;

        _isReflectionOpen = true;
        _lastReflectionDate = todayStamp;
        Hive.box('settings').put('lastReflectionDate', todayStamp);

        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => DailyReflectionScreen(
                  pct: pct,
                  completed: completed,
                  total: total,
                  onContinue: () => Navigator.pop(context),
                ),
              ),
            )
            .whenComplete(() {
              _isReflectionOpen = false;
            });
      }
    late ConfettiController _confettiController;
    // Example categories, adjust as needed
    final List<String> categories = ["Work", "Personal", "Shopping", "Others"];

    Task? _getSuggestedTask(List<Task> tasks) {
      final pendingTasks = tasks.where((task) => !task.isCompleted).toList();
      if (pendingTasks.isEmpty) {
        return null;
      }

      const priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
      pendingTasks.sort((a, b) {
        final aDue = a.dueDate;
        final bDue = b.dueDate;
        if (aDue != null && bDue != null) {
          final dueComparison = aDue.compareTo(bDue);
          if (dueComparison != 0) return dueComparison;
        } else if (aDue != null) {
          return -1;
        } else if (bDue != null) {
          return 1;
        }

        return (priorityOrder[a.priority] ?? 1).compareTo(
          priorityOrder[b.priority] ?? 1,
        );
      });

      return pendingTasks.first;
    }
  FilterType selectedFilter = FilterType.all;
  String searchQuery = "";

  // ── Multi-select state ─────────────────────────
  bool _isSelectionMode = false;
  final Set<dynamic> _selectedKeys = {};
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    final settings = Hive.box('settings');
    _streak = settings.get('taskStreakCount', defaultValue: 0) as int;
    _lastStreakAwardDate = settings.get('lastStreakAwardDate') as String?;
    _lastReflectionDate = settings.get('lastReflectionDate') as String?;
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // ...existing code...
  // (All other methods, including build, etc., remain here inside the class)

// The closing brace for _HomeScreenState should be at the very end of all its methods, before the helper widget classes.

// ─────────────────────────────────────────────────────
// Reusable widgets and painters moved to top-level scope


  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return const Color(0xFFE57373);
      case "Low":
        return const Color(0xFF64B5F6);
      default:
        return const Color(0xFFFFB74D);
    }
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  Map<String, List<Task>> _buildSmartGroups(List<Task> tasks, DateTime now) {
    final groups = <String, List<Task>>{
      "Overdue": [],
      "Now": [],
      "Later Today": [],
      "Tomorrow": [],
      "This Week": [],
      "Later": [],
      "Anytime": [],
    };
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dayAfterTomorrow = DateTime(now.year, now.month, now.day + 2);
    final nextWeek = now.add(const Duration(days: 7));
    final threeHoursLater = now.add(const Duration(hours: 3));

    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) {
        groups["Anytime"]!.add(task);
        continue;
      }
      if (due.isBefore(now) && !task.isCompleted) {
        groups["Overdue"]!.add(task);
      } else if (!due.isBefore(now) &&
          due.isBefore(threeHoursLater) &&
          isSameDay(due, now)) {
        groups["Now"]!.add(task);
      } else if (isSameDay(due, now)) {
        groups["Later Today"]!.add(task);
      } else if (due.isAfter(tomorrow.subtract(const Duration(seconds: 1))) &&
          due.isBefore(dayAfterTomorrow)) {
        groups["Tomorrow"]!.add(task);
      } else if (due.isAfter(dayAfterTomorrow) && due.isBefore(nextWeek)) {
        groups["This Week"]!.add(task);
      } else if (due.isAfter(nextWeek)) {
        groups["Later"]!.add(task);
      }
    }
    return groups;
  }

  Color _groupHeaderColor(String groupName, Color primary) {
    switch (groupName) {
      case "Overdue":
        return Colors.red.shade400;
      case "Now":
        return Colors.orange.shade600;
      case "Later Today":
        return primary;
      default:
        return primary;
    }
  }

  List<_TaskListRow> _buildTaskRows(
    Map<String, List<Task>> displayGroups,
    bool useSmartFlow,
    Color primary,
  ) {
    final rows = <_TaskListRow>[];

    for (final entry in displayGroups.entries) {
      if (entry.value.isEmpty) continue;

      rows.add(
        _TaskListRow.header(
          headerLabel: entry.key,
          headerCount: entry.value.length,
          headerColor:
              useSmartFlow ? _groupHeaderColor(entry.key, primary) : primary,
          headerIcon: _groupHeaderIcon(entry.key),
        ),
      );

      for (final task in entry.value) {
        rows.add(_TaskListRow.task(task));
      }
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final box = Hive.box<Task>('tasks');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final overlayStyle = (isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<Task> box, _) {
          // ...existing code...
              final allTasks = box.values.toList();
              final now = DateTime.now();
              final suggestedTask = _getSuggestedTask(allTasks);

              int todayCount = 0;
              int upcomingCount = 0;
              int pendingCount = 0;
              int completedCount = 0;
              final todayTasks = <Task>[];
              final query = searchQuery.trim().toLowerCase();
              final tasks = <Task>[];

              for (final task in allTasks) {
                final due = task.dueDate;
                final isToday = due != null && isSameDay(due, now);
                final matchesSearch =
                    query.isEmpty || task.title.toLowerCase().contains(query);

                if (isToday) {
                  todayCount += 1;
                  todayTasks.add(task);
                }

                if (due != null && due.isAfter(now)) {
                  upcomingCount += 1;
                }

                if (task.isCompleted) {
                  completedCount += 1;
                } else {
                  pendingCount += 1;
                }

                if (!matchesSearch) continue;

                final includeTask = switch (selectedFilter) {
                  FilterType.all => true,
                  FilterType.today => isToday,
                  FilterType.upcoming => due != null && due.isAfter(now),
                  FilterType.pending => !task.isCompleted,
                  FilterType.completed => task.isCompleted,
                };

                if (includeTask) {
                  tasks.add(task);
                }
              }

              final todayCompleted = todayTasks.where((t) => t.isCompleted).length;
              final todayTotal = todayTasks.length;
              final reflectionPct = todayTotal == 0
                  ? 0.0
                  : todayCompleted / todayTotal;
              final todayStamp = _dateStamp(now);

              const priorityOrder = {"High": 0, "Medium": 1, "Low": 2};
              void sortGroup(List<Task> group) {
                group.sort((a, b) {
                  if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
                  return (priorityOrder[a.priority] ?? 1).compareTo(
                    priorityOrder[b.priority] ?? 1,
                  );
                });
              }

              Map<String, List<Task>> displayGroups = {};
              bool useSmartFlow =
                  selectedFilter == FilterType.all ||
                  selectedFilter == FilterType.today;

              if (useSmartFlow) {
                displayGroups = _buildSmartGroups(tasks, now);
                for (final g in displayGroups.values) {
                  sortGroup(g);
                }
              } else {
                for (final cat in categories) {
                  final catTasks = tasks.where((t) => t.category == cat).toList();
                  if (catTasks.isNotEmpty) {
                    sortGroup(catTasks);
                    displayGroups[cat] = catTasks;
                  }
                }
                final uncategorized = tasks
                    .where(
                      (t) => t.category == null || !categories.contains(t.category),
                    )
                    .toList();
                if (uncategorized.isNotEmpty) {
                  sortGroup(uncategorized);
                  displayGroups["Others"] =
                      (displayGroups["Others"] ?? []) + uncategorized;
                }
              }

              final taskRows = _buildTaskRows(displayGroups, useSmartFlow, primary);
              final bool isEmpty = taskRows.isEmpty;

              if (todayTotal > 0 &&
                  todayCompleted == todayTotal &&
                  (_lastStreakAwardDate != todayStamp ||
                      _lastReflectionDate != todayStamp)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkAndUpdateStreak(todayTasks);
                  _maybeShowReflection(
                    reflectionPct,
                    todayCompleted,
                    todayTotal,
                  );
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🎉 Confetti
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      numberOfParticles: 30,
                      gravity: 0.3,
                      colors: [
                        primary,
                        Colors.pink,
                        Colors.orange,
                        Colors.green,
                        Colors.blue,
                      ],
                    ),
                  ),
                  if (_isSelectionMode)
                    _buildSelectionBar(isDark, primary)
                  else ...[
                    // Compact header card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.85),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getGreeting(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        // Underline
                                        Container(
                                          margin: const EdgeInsets.only(top: 4, bottom: 10),
                                          height: 2,
                                          width: 48,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white54 : Colors.black26,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (Hive.box('settings').get('showHomeQuote', defaultValue: true) as bool) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                                        child: Text(
                                          _todayQuote,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.white : Colors.black87,
                                            letterSpacing: -0.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // 🔥 Streak badge
                              Column(
                                children: [
                                  _HeaderBadge(
                                    isDark: isDark,
                                    color: _streak > 0 ? Colors.orange : Colors.grey.shade400,
                                    bgColor: _streak > 0
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
                                    borderColor: _streak > 0
                                        ? Colors.orange.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                    icon: Icons.local_fire_department_rounded,
                                    label: "$_streak",
                                  ),
                                  const SizedBox(height: 6),
                                  // 🎯 Focus mode badge
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const FocusModeScreen(),
                                      ),
                                    ),
                                    child: _HeaderBadge(
                                      isDark: isDark,
                                      color: primary,
                                      bgColor: primary.withValues(alpha: 0.1),
                                      borderColor:
                                          primary.withValues(alpha: 0.2),
                                      icon: Icons.center_focus_strong_rounded,
                                      label: "Focus",
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // (Optional) Remove quote card for more space, or keep as needed
                    // 💡 Smart suggestion card
                    if (suggestedTask != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FocusModeScreen(),
                            ),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 3,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Suggested Task",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        suggestedTask.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (suggestedTask.dueDate != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            DateFormat(
                                              'dd MMM · hh:mm a',
                                            ).format(suggestedTask.dueDate!),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                  color: primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  // 🔥 Filter chips row with search icon
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 12, right: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip(
                                  "All",
                                  FilterType.all,
                                  primary,
                                  isDark,
                                  count: allTasks.length,
                                ),
                                const SizedBox(width: 6),
                                _filterChip(
                                  "Today",
                                  FilterType.today,
                                  primary,
                                  isDark,
                                  count: todayCount,
                                ),
                                const SizedBox(width: 6),
                                _filterChip(
                                  "Upcoming",
                                  FilterType.upcoming,
                                  primary,
                                  isDark,
                                  count: upcomingCount,
                                ),
                                const SizedBox(width: 6),
                                _filterChip(
                                  "Pending",
                                  FilterType.pending,
                                  primary,
                                  isDark,
                                  count: pendingCount,
                                ),
                                const SizedBox(width: 6),
                                _filterChip(
                                  "Done",
                                  FilterType.completed,
                                  primary,
                                  isDark,
                                  count: completedCount,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search_rounded, size: 24),
                          color: isDark ? Colors.white70 : Colors.black54,
                          tooltip: "Search tasks",
                          onPressed: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                String tempQuery = searchQuery;
                                return AlertDialog(
                                  title: const Text("Search Tasks"),
                                  content: TextField(
                                    autofocus: true,
                                    decoration: const InputDecoration(hintText: "Type to search..."),
                                    onChanged: (val) => tempQuery = val,
                                    controller: TextEditingController(text: searchQuery),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, null),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, tempQuery),
                                      child: const Text("Search"),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (result != null) setState(() => searchQuery = result);
                          },
                        ),
                      ],
                    ),
                  ),
                  // 🔥 Filter chips (removed duplicate row)
                  // 📋 Task list
                  Expanded(
                    child: isEmpty
                        ? _emptyState(context)
                        : ListView.builder(
                            key: ValueKey(
                              '${selectedFilter.name}-$searchQuery',
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                            cacheExtent: 800,
                            itemCount: taskRows.length,
                            itemBuilder: (context, index) {
                              final row = taskRows[index];
                              if (row.isHeader) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 16, 0, 8),
                                  child: Row(
                                    children: [
                                      if (row.headerIcon != null) ...[
                                        Icon(
                                          row.headerIcon,
                                          color: row.headerColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      HomeGroupHeader(
                                        label: row.headerLabel!,
                                        count: row.headerCount!,
                                        color: row.headerColor!,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return RepaintBoundary(
                                child: _buildTaskItem(
                                  row.task!,
                                  primary,
                                  isDark,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                );
              },
              child: const Icon(Icons.add),
            ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  // ─────────────────────────────────────────────
  // Selection mode top bar
  // ─────────────────────────────────────────────
  Widget _buildSelectionBar(bool isDark, Color primary) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _exitSelectionMode,
            tooltip: "Exit selection",
          ),
          Text(
            "${_selectedKeys.length} selected",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          if (_selectedKeys.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.check_circle_outline_rounded, color: primary),
              tooltip: "Mark as complete",
              onPressed: () => _bulkComplete(true),
            ),
            IconButton(
              icon: Icon(Icons.radio_button_unchecked_rounded, color: primary),
              tooltip: "Mark as pending",
              onPressed: () => _bulkComplete(false),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade400,
              ),
              tooltip: "Delete selected",
              onPressed: _bulkDelete,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Task card with multi-select support
  // ─────────────────────────────────────────────
  Widget _buildTaskItem(Task task, Color primary, bool isDark) {
    final date = task.dueDate;
    final isOverdue =
        date != null && !task.isCompleted && date.isBefore(DateTime.now());
    final isSelected = _selectedKeys.contains(task.key);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isSelectionMode = true;
          _selectedKeys.add(task.key);
        });
      },
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedKeys.remove(task.key);
                  if (_selectedKeys.isEmpty) _exitSelectionMode();
                } else {
                  _selectedKeys.add(task.key);
                }
              });
            }
          : null,
      child: Dismissible(
        key: Key(task.key.toString()),
        direction: _isSelectionMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        confirmDismiss: (_) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text("Delete Task"),
              content: Text('Are you sure you want to delete "${task.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text(
                    "Delete",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
          return confirmed ?? false;
        },
        onDismissed: (_) async {
          final box = Hive.box<Task>('tasks');
          final deletedTask = Task(
            title: task.title,
            category: task.category,
            dueDate: task.dueDate,
            isCompleted: task.isCompleted,
            description: task.description,
            priority: task.priority,
            recurrenceRule: task.recurrenceRule,
            reminderTime: task.reminderTime,
            reminderMinutesBefore: task.reminderMinutesBefore,
            reminderEnabled: task.reminderEnabled,
          );
          await NotificationService().cancelNotification(task.key as int);
          await task.delete();
          AppStateService.rootScaffoldMessengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text("Task deleted"),
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: "UNDO",
                  onPressed: () async => await box.add(deletedTask),
                ),
              ),
            );
        },
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: Opacity(
          opacity: task.isCompleted ? 0.55 : 1.0,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: task.isCompleted ? 2 : 4),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: isSelected
                  ? (isDark
                        ? primary.withValues(alpha: 0.18)
                        : primary.withValues(alpha: 0.08))
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: isSelected
                    ? BorderSide(color: primary.withValues(alpha: 0.4), width: 1.5)
                    : BorderSide.none,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: getPriorityColor(task.priority),
                      width: 4,
                    ),
                  ),
                ),
                child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        onTap: _isSelectionMode
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTaskScreen(task: task),
                                  ),
                                );
                              },
                        leading: _isSelectionMode
                            ? AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: isSelected
                                      ? primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? primary
                                        : Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              )
                            : GestureDetector(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  await _setTaskCompletion(
                                    task,
                                    !task.isCompleted,
                                  );
                                },
                                child: AnimatedScale(
                                  scale: task.isCompleted ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: task.isCompleted
                                          ? primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: task.isCompleted
                                            ? primary
                                            : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 11,
                                      color: isOverdue
                                          ? Colors.red.shade400
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      DateFormat(
                                        'dd MMM · hh:mm a',
                                      ).format(date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOverdue
                                            ? Colors.red.shade400
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              if (task.description != null &&
                                  task.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    task.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _emptyTitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Start your day strong";
    if (hour < 17) return "Keep the momentum going";
    return "Wrap up your tasks";
  }

  String _emptySubtitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Add your tasks and conquer the day.";
    if (hour < 17) return "You're doing great — keep going.";
    return "Finish strong and rest well tonight.";
  }

  Widget _emptyState(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Center(
        key: ValueKey(selectedFilter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _emptyTitle(),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _emptySubtitle(),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    String label,
    FilterType type,
    Color primary,
    bool isDark, {
    int count = 0,
  }) {
    final isSelected = selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : (isDark ? const Color(0xFF2A2A2A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 🎨 Decorative soft shapes painter
// ─────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────

class _HeaderBadge extends StatelessWidget {
  final bool isDark;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;
  final String label;

  const _HeaderBadge({
    required this.isDark,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

