import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'focus_mode_screen.dart';
import 'package:flutter/services.dart';
import '../../../main.dart' show rootScaffoldMessengerKey;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import 'add_task_screen.dart';
import '../../../services/notification_service.dart';
import 'daily_reflection_screen.dart';

enum FilterType { all, today, upcoming, pending, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FilterType selectedFilter = FilterType.all;
  String searchQuery = "";
  Task? _getSuggestedTask(List<Task> tasks) {
    final now = DateTime.now();

    // Only pending tasks
    final pending = tasks.where((t) => !t.isCompleted).toList();
    if (pending.isEmpty) return null;

    // Sort logic
    pending.sort((a, b) {
      final aDue = a.dueDate;
      final bDue = b.dueDate;

      // Overdue first
      final aOverdue = aDue != null && aDue.isBefore(now);
      final bOverdue = bDue != null && bDue.isBefore(now);

      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }

      // Today first
      if (aDue != null && bDue != null) {
        final aToday = isSameDay(aDue, now);
        final bToday = isSameDay(bDue, now);

        if (aToday != bToday) {
          return aToday ? -1 : 1;
        }

        // Earlier time first
        return aDue.compareTo(bDue);
      }

      // Priority fallback
      const priorityOrder = {"High": 0, "Medium": 1, "Low": 2};
      return (priorityOrder[a.priority] ?? 1).compareTo(
        priorityOrder[b.priority] ?? 1,
      );
    });

    return pending.first;
  }

  void _maybeShowReflection(
    double pct,
    int completed,
    int total,
    List<Task> todayTasks,
  ) {
    final settings = Hive.box('settings');

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final lastShown = settings.get('lastReflectionDate', defaultValue: '');

    if (lastShown == todayStr) return;
    if (total == 0) return;

    settings.put('lastReflectionDate', todayStr);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyReflectionScreen(
            pct: pct,
            completed: completed,
            total: total,
            onContinue: () {
              Navigator.pop(context);

              final pending = todayTasks.where((t) => !t.isCompleted).toList();

              if (pending.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FocusModeScreen()),
                );
              }
            },
          ),
        ),
      );
    });
  }

  // ── Multi-select state ─────────────────────────
  bool _isSelectionMode = false;
  final Set<dynamic> _selectedKeys = {};

  late ConfettiController _confettiController;
  int _streak = 0;
  DateTime? _lastCompletedDate;

  final List<String> _quotes = [
    "Small steps every day lead to big results.",
    "Done is better than perfect.",
    "Focus on progress, not perfection.",
    "You don't have to be great to start, but you have to start to be great.",
    "One task at a time. That's all it takes.",
    "Your future self is watching. Make them proud.",
    "Discipline is choosing what you want most over what you want now.",
    "The secret of getting ahead is getting started.",
    "Productivity is never an accident. It's the result of commitment.",
    "Every completed task is a step closer to your goal.",
    "Work hard in silence. Let results make the noise.",
    "Don't count the days. Make the days count.",
    "Success is the sum of small efforts repeated daily.",
    "Push yourself, because no one else is going to do it for you.",
    "Great things never come from comfort zones.",
  ];

  String get _todayQuote {
    final dayIndex =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays %
        _quotes.length;
    return _quotes[dayIndex];
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadStreak();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _loadStreak() {
    final settings = Hive.box('settings');
    _streak = settings.get('streak', defaultValue: 0) as int;
    final lastDateStr =
        settings.get('lastCompletedDate', defaultValue: '') as String;
    if (lastDateStr.isNotEmpty) {
      _lastCompletedDate = DateTime.tryParse(lastDateStr);
    }
  }

  void _checkAndUpdateStreak(List<Task> todayTasks) {
    if (todayTasks.isEmpty) return;
    final allDone = todayTasks.every((t) => t.isCompleted);
    if (!allDone) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_lastCompletedDate != null && isSameDay(_lastCompletedDate!, todayDate))
      return;

    final yesterday = todayDate.subtract(const Duration(days: 1));
    if (_lastCompletedDate != null &&
        isSameDay(_lastCompletedDate!, yesterday)) {
      _streak++;
    } else {
      _streak = 1;
    }

    _lastCompletedDate = todayDate;
    final settings = Hive.box('settings');
    settings.put('streak', _streak);
    settings.put('lastCompletedDate', todayDate.toIso8601String());
    _confettiController.play();
  }

  // ── Exit selection mode ────────────────────────
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedKeys.clear();
    });
  }

  // ── Bulk complete ──────────────────────────────
  void _bulkComplete(bool markDone) {
    final box = Hive.box<Task>('tasks');
    for (final key in _selectedKeys) {
      final task = box.get(key);
      if (task != null) {
        task.isCompleted = markDone;
        task.save();
      }
    }
    _exitSelectionMode();
  }

  // ── Bulk delete ────────────────────────────────
  Future<void> _bulkDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Selected Tasks"),
        content: Text(
          "Delete ${_selectedKeys.length} selected task${_selectedKeys.length > 1 ? 's' : ''}? This cannot be undone.",
        ),
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
    if (confirmed != true) return;

    final box = Hive.box<Task>('tasks');
    for (final key in _selectedKeys) {
      final task = box.get(key);
      if (task != null) {
        await NotificationService().cancelNotification(key as int);
        await task.delete();
      }
    }
    _exitSelectionMode();
  }

  final List<String> categories = ["Work", "Personal", "Shopping", "Others"];

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

  // ── Daily reflection message ───────────────────
  String _reflectionMessage(double pct) {
    if (pct >= 1.0) {
      return "You crushed it today. Every single task — done. That's not luck, that's discipline.";
    } else if (pct >= 0.7) {
      return "Strong day. You tackled the hard stuff and kept moving. Tomorrow starts with momentum.";
    } else if (pct >= 0.4) {
      return "Solid effort. Progress isn't always perfect — it's consistent. You showed up.";
    } else {
      return "Not every day is a sprint. Rest, reset, and come back stronger. You've got this.";
    }
  }

  String _reflectionLabel(double pct) {
    if (pct >= 1.0) return "Excellent Day";
    if (pct >= 0.7) return "Great Progress";
    if (pct >= 0.4) return "Good Effort";
    return "Keep Going";
  }

  Color _reflectionColor(double pct) {
    if (pct >= 1.0) return const Color(0xFF4CAF50);
    if (pct >= 0.7) return const Color(0xFF26A69A);
    if (pct >= 0.4) return const Color(0xFF42A5F5);
    return const Color(0xFFFF7043);
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Task> box, _) {
          final allTasks = box.values.toList();
          final suggestedTask = _getSuggestedTask(allTasks);
          final now = DateTime.now();

          // ── Counts ────────────────────────────────
          final todayCount = allTasks.where((t) {
            final due = t.dueDate;
            if (due == null) return false;
            return isSameDay(due, now);
          }).length;
          final upcomingCount = allTasks.where((t) {
            final due = t.dueDate;
            if (due == null) return false;
            return due.isAfter(now);
          }).length;
          final pendingCount = allTasks.where((t) => !t.isCompleted).length;
          final completedCount = allTasks.where((t) => t.isCompleted).length;

          // ── Today's tasks for reflection card ─────
          final todayTasks = allTasks.where((t) {
            final due = t.dueDate;
            if (due == null) return false;
            return isSameDay(due, now);
          }).toList();
          final todayCompleted = todayTasks.where((t) => t.isCompleted).length;
          final todayTotal = todayTasks.length;
          final reflectionPct = todayTotal == 0
              ? 0.0
              : todayCompleted / todayTotal;

          // ── Filter ────────────────────────────────
          List<Task> tasks = [];
          if (selectedFilter == FilterType.all) {
            tasks = allTasks;
          } else if (selectedFilter == FilterType.today) {
            tasks = allTasks.where((task) {
              final due = task.dueDate;
              if (due == null) return false;
              return isSameDay(due, now);
            }).toList();
          } else if (selectedFilter == FilterType.upcoming) {
            tasks = allTasks.where((task) {
              final due = task.dueDate;
              if (due == null) return false;
              return due.isAfter(now);
            }).toList();
          } else if (selectedFilter == FilterType.pending) {
            tasks = allTasks.where((t) => !t.isCompleted).toList();
          } else if (selectedFilter == FilterType.completed) {
            tasks = allTasks.where((t) => t.isCompleted).toList();
          }

          if (searchQuery.isNotEmpty) {
            tasks = tasks
                .where(
                  (task) => task.title.toLowerCase().contains(
                    searchQuery.toLowerCase(),
                  ),
                )
                .toList();
          }

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
            for (final g in displayGroups.values) sortGroup(g);
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

          final bool isEmpty = displayGroups.values.every((g) => g.isEmpty);

          // Show reflection card only for all/today filters
          // and only when there are today tasks
          final bool showReflection =
              (selectedFilter == FilterType.all ||
                  selectedFilter == FilterType.today) &&
              todayTotal > 0;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndUpdateStreak(todayTasks);

            _maybeShowReflection(
              reflectionPct,
              todayCompleted,
              todayTotal,
              todayTasks,
            );
          });

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

              // ─────────────────────────────────────
              // 🔲 Selection mode AppBar OR normal header
              // ─────────────────────────────────────
              if (_isSelectionMode)
                _buildSelectionBar(isDark, primary)
              else ...[
                // Normal header with soft shapes
                ClipRect(
                  child: SizedBox(
                    height: 90,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SoftShapesPainter(
                              color: primary,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _streak == 0
                                            ? "Complete all tasks today to start a streak!"
                                            : "$_streak day streak! Keep it up!",
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: _HeaderBadge(
                                  isDark: isDark,
                                  color: _streak > 0
                                      ? Colors.orange
                                      : Colors.grey.shade400,
                                  bgColor: _streak > 0
                                      ? Colors.orange.withOpacity(0.12)
                                      : (isDark
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.grey.shade100),
                                  borderColor: _streak > 0
                                      ? Colors.orange.withOpacity(0.3)
                                      : Colors.transparent,
                                  icon: Icons.local_fire_department_rounded,
                                  label: "$_streak",
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                  bgColor: primary.withOpacity(0.1),
                                  borderColor: primary.withOpacity(0.2),
                                  icon: Icons.center_focus_strong_rounded,
                                  label: "Focus",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Quote card
                ValueListenableBuilder(
                  valueListenable: Hive.box(
                    'settings',
                  ).listenable(keys: ['showHomeQuote']),
                  builder: (context, settingsBox, _) {
                    final showQuote =
                        (settingsBox as dynamic).get(
                              'showHomeQuote',
                              defaultValue: true,
                            )
                            as bool;
                    if (!showQuote) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _todayQuote,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (!_isSelectionMode && suggestedTask != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FocusModeScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primary.withOpacity(0.25),
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
                                color: primary.withOpacity(0.6),
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

              // 🔍 Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search tasks...",
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primary.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 🔥 Filter chips
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 12),
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

              // 📋 Task list
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: isEmpty
                      ? _emptyState(context)
                      : ListView(
                          key: ValueKey(
                            selectedFilter.toString() + searchQuery,
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                          children: [
                            ...displayGroups.entries
                                .where((e) => e.value.isNotEmpty)
                                .map((entry) {
                                  final headerColor = useSmartFlow
                                      ? _groupHeaderColor(entry.key, primary)
                                      : primary;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      _GroupHeader(
                                        label: entry.key,
                                        count: entry.value.length,
                                        color: headerColor,
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 8),
                                      ...entry.value.map(
                                        (task) => _buildTaskItem(
                                          task,
                                          primary,
                                          isDark,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: _isSelectionMode
          ? null // Hide FAB in selection mode
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }

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
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close / back
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _exitSelectionMode,
            tooltip: "Exit selection",
          ),

          // Count
          Text(
            "${_selectedKeys.length} selected",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const Spacer(),

          // Mark complete
          if (_selectedKeys.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.check_circle_outline_rounded, color: primary),
              tooltip: "Mark as complete",
              onPressed: () => _bulkComplete(true),
            ),

            // Mark pending
            IconButton(
              icon: Icon(Icons.radio_button_unchecked_rounded, color: primary),
              tooltip: "Mark as pending",
              onPressed: () => _bulkComplete(false),
            ),

            // Delete
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
  // Daily Reflection Card
  // ─────────────────────────────────────────────
  Widget _buildReflectionCard({
    required bool isDark,
    required Color primary,
    required int completed,
    required int total,
    required double pct,
  }) {
    final color = _reflectionColor(pct);
    final label = _reflectionLabel(pct);
    final message = _reflectionMessage(pct);
    final percent = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "Daily Reflection",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress bar ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$completed of $total tasks completed",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "$percent%",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Animated progress bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 7,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          color: color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Message ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
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

  // ─────────────────────────────────────────────
  // Task card — with multi-select support
  // ─────────────────────────────────────────────
  Widget _buildTaskItem(Task task, Color primary, bool isDark) {
    final date = task.dueDate;
    final isOverdue =
        date != null && !task.isCompleted && date.isBefore(DateTime.now());
    final isSelected = _selectedKeys.contains(task.key);

    return GestureDetector(
      // Long press → enter selection mode
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() {
          _isSelectionMode = true;
          _selectedKeys.add(task.key);
        });
      },
      // Tap in selection mode → toggle selection
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
        // Disable swipe in selection mode
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
          );
          await NotificationService().cancelNotification(task.key as int);
          await task.delete();
          rootScaffoldMessengerKey.currentState
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
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.isCompleted ? 0.55 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(vertical: task.isCompleted ? 2 : 4),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              // Highlight selected cards
              color: isSelected
                  ? (isDark
                        ? primary.withOpacity(0.18)
                        : primary.withOpacity(0.08))
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: isSelected
                    ? BorderSide(color: primary.withOpacity(0.4), width: 1.5)
                    : BorderSide.none,
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(width: 4, color: getPriorityColor(task.priority)),
                    Expanded(
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

                        // Selection checkbox OR normal checkbox
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
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  task.isCompleted = !task.isCompleted;
                                  task.save();
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
                  ],
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
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08)),
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
                      ? Colors.white.withOpacity(0.25)
                      : primary.withOpacity(0.12),
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
// 🎨 Soft shapes painter
// ─────────────────────────────────────────────────────
class _SoftShapesPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  _SoftShapesPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = color.withOpacity(isDark ? 0.08 : 0.10);
    canvas.drawCircle(Offset(size.width + 10, -10), 90, paint);
    paint.color = color.withOpacity(isDark ? 0.05 : 0.07);
    canvas.drawCircle(Offset(size.width - 40, 65), 55, paint);
    paint.color = color.withOpacity(isDark ? 0.04 : 0.05);
    canvas.drawCircle(Offset(-18, size.height * 0.65), 42, paint);
    paint.color = color.withOpacity(isDark ? 0.07 : 0.09);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.2), 16, paint);
  }

  @override
  bool shouldRepaint(_SoftShapesPainter old) =>
      old.color != color || old.isDark != isDark;
}

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

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _GroupHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(isDark ? 1.0 : 0.85),
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(isDark ? 0.9 : 0.75),
            ),
          ),
        ),
      ],
    );
  }
}
