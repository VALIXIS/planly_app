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

enum FilterType { all, today, upcoming, pending, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FilterType selectedFilter = FilterType.all;
  String searchQuery = "";

  // 🎉 Confetti controller
  late ConfettiController _confettiController;

  // 🔥 Streak — stored in Hive settings box
  int _streak = 0;
  DateTime? _lastCompletedDate;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _loadStreak();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Load streak from Hive
  void _loadStreak() {
    final settings = Hive.box('settings');
    _streak = settings.get('streak', defaultValue: 0) as int;
    final lastDateStr =
        settings.get('lastCompletedDate', defaultValue: '') as String;
    if (lastDateStr.isNotEmpty) {
      _lastCompletedDate = DateTime.tryParse(lastDateStr);
    }
  }

  // Update streak when all today's tasks are done
  void _checkAndUpdateStreak(List<Task> todayTasks) {
    if (todayTasks.isEmpty) return;
    final allDone = todayTasks.every((t) => t.isCompleted);
    if (!allDone) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Already counted today
    if (_lastCompletedDate != null &&
        isSameDay(_lastCompletedDate!, todayDate)) return;

    final yesterday =
        todayDate.subtract(const Duration(days: 1));

    // If completed yesterday → continue streak, else reset
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

    // 🎉 Fire confetti!
    _confettiController.play();
  }

  final List<String> categories = [
    "Work",
    "Personal",
    "Shopping",
    "Others",
  ];

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

  // ── Smart greeting based on time of day ────────
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchFill = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Task> box, _) {
          final allTasks = box.values.toList();
          final now = DateTime.now();

          // ── Task counts for chips & summary ────────────
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

          final pendingCount =
              allTasks.where((t) => !t.isCompleted).length;

          final completedCount =
              allTasks.where((t) => t.isCompleted).length;

          // ── Filter by type ──────────────────────────────
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

          // ── Search filter ───────────────────────────────
          if (searchQuery.isNotEmpty) {
            tasks = tasks
                .where((task) => task.title
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();
          }

          // ── Priority sort helper ────────────────────────
          const priorityOrder = {"High": 0, "Medium": 1, "Low": 2};
          void sortGroup(List<Task> group) {
            group.sort((a, b) {
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              return (priorityOrder[a.priority] ?? 1)
                  .compareTo(priorityOrder[b.priority] ?? 1);
            });
          }

          // ── Group tasks by category ─────────────────────
          // Always group by category regardless of filter
          final Map<String, List<Task>> groupedByCategory = {};

          for (final cat in categories) {
            final catTasks =
                tasks.where((t) => t.category == cat).toList();
            if (catTasks.isNotEmpty) {
              sortGroup(catTasks);
              groupedByCategory[cat] = catTasks;
            }
          }

          // Tasks with no category or unknown category → "Others"
          final uncategorized = tasks
              .where((t) =>
                  t.category == null ||
                  !categories.contains(t.category))
              .toList();
          if (uncategorized.isNotEmpty) {
            sortGroup(uncategorized);
            groupedByCategory["Others"] =
                (groupedByCategory["Others"] ?? []) + uncategorized;
          }

          final bool isEmpty = groupedByCategory.isEmpty;

          // 🔥 Check streak + confetti after every build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final todayTasks = allTasks.where((task) {
              final due = task.dueDate;
              if (due == null) return false;
              return due.year == now.year &&
                  due.month == now.month &&
                  due.day == now.day;
            }).toList();
            _checkAndUpdateStreak(todayTasks);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // 🎉 Confetti widget — anchored to top center
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

              // 👋 Greeting row + streak + focus mode button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting + summary
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingCount == 0
                                ? "All caught up! Great job."
                                : "$pendingCount pending · $completedCount completed",
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 🔥 Streak badge
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text(
                            _streak == 0
                                ? "Complete all tasks today to start a streak!"
                                : "$_streak day streak! Keep it up!",
                          ),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _streak > 0
                              ? Colors.orange.withOpacity(0.15)
                              : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _streak > 0
                                ? Colors.orange.withOpacity(0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: _streak > 0
                                  ? Colors.orange
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$_streak",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _streak > 0
                                    ? Colors.orange
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // 🎯 Focus mode button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FocusModeScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_strong_rounded,
                                size: 16, color: primary),
                            const SizedBox(width: 4),
                            Text(
                              "Focus",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔍 Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: "Search tasks...",
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: searchFill,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 🔥 Filter chips — horizontal scroll with counts
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip("All", FilterType.all, primary, isDark,
                          count: allTasks.length),
                      const SizedBox(width: 6),
                      _filterChip("Today", FilterType.today, primary, isDark,
                          count: todayCount),
                      const SizedBox(width: 6),
                      _filterChip("Upcoming", FilterType.upcoming, primary, isDark,
                          count: upcomingCount),
                      const SizedBox(width: 6),
                      _filterChip("Pending", FilterType.pending, primary, isDark,
                          count: pendingCount),
                      const SizedBox(width: 6),
                      _filterChip("Done", FilterType.completed, primary, isDark,
                          count: completedCount),
                    ],
                  ),
                ),
              ),

              // 📋 Category-grouped task list
              Expanded(
                child: isEmpty
                    ? _emptyState(context)
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: groupedByCategory.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 14),

                              // Category header
                              Row(
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Task count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${entry.value.length}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Tasks in this category
                              ...entry.value.map(
                                  (task) => _buildTaskItem(task, primary)),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
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
  // Task card — colored left border, no tint
  // ─────────────────────────────────────────────
  Widget _buildTaskItem(Task task, Color primary) {
    final date = task.dueDate;
    final isOverdue = date != null &&
        !task.isCompleted &&
        date.isBefore(DateTime.now());

    return Dismissible(
      key: Key(task.key.toString()),
      direction: DismissDirection.endToStart,
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

        await NotificationService()
            .cancelNotification(task.key as int);
        await task.delete();

        rootScaffoldMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text("Task deleted"),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: "UNDO",
                onPressed: () async {
                  await box.add(deletedTask);
                },
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
        duration: const Duration(milliseconds: 250),
        opacity: task.isCompleted ? 0.55 : 1.0,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ✅ Colored left border only
                Container(
                  width: 4,
                  color: getPriorityColor(task.priority),
                ),

                Expanded(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTaskScreen(task: task),
                        ),
                      );
                    },

                    // Checkbox with haptic + scale animation
                    leading: GestureDetector(
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
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
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
                                  DateFormat('dd MMM · hh:mm a')
                                      .format(date),
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
    );
  }

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────
  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text("No tasks yet",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Tap + to add your first task",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Filter chip with count badge
  // ─────────────────────────────────────────────
  Widget _filterChip(
      String label, FilterType type, Color primary, bool isDark,
      {int count = 0}) {
    final isSelected = selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : isDark
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : Colors.black87,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : primary.withOpacity(0.15),
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