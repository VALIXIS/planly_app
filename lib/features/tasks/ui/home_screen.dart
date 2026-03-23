import 'package:flutter/material.dart';
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

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;
      case "Low":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');
    // Detect dark mode so we can adjust card/tile colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchFill = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ℹ️ AppBar is now handled by MainScreen (includes theme toggle)
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Task> box, _) {
          final allTasks = box.values.toList();
          final now = DateTime.now();

          // ── Filter logic ──────────────────────────────
          List<Task> tasks = [];
          if (selectedFilter == FilterType.all) {
            tasks = allTasks;
          } else if (selectedFilter == FilterType.today) {
            tasks = allTasks.where((task) {
              final due = task.dueDate;
              if (due == null) return false;
              return due.year == now.year &&
                  due.month == now.month &&
                  due.day == now.day;
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

          // ── Search filter ─────────────────────────────
          if (searchQuery.isNotEmpty) {
            tasks = tasks
                .where((task) => task.title
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();
          }

          final completed = tasks.where((t) => t.isCompleted).length;
          final progress =
              tasks.isEmpty ? 0.0 : completed / tasks.length;

          return Column(
            children: [
              // 🔍 Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: (value) =>
                      setState(() => searchQuery = value),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Search tasks...",
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: searchFill,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 📊 Progress card
              Card(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tasks Overview",
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        "$completed / ${tasks.length} tasks completed",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: isDark
                            ? Colors.white12
                            : const Color(0xFFEDE7F6),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              // 🔥 Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      filterChip("All", FilterType.all),
                      const SizedBox(width: 6),
                      filterChip("Today", FilterType.today),
                      const SizedBox(width: 6),
                      filterChip("Upcoming", FilterType.upcoming),
                      const SizedBox(width: 6),
                      filterChip("Pending", FilterType.pending),
                      const SizedBox(width: 6),
                      filterChip("Done", FilterType.completed),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 📋 Task list
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text("No tasks ✨",
                            style: Theme.of(context).textTheme.bodyMedium),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final date = task.dueDate ?? DateTime.now();

                          return Dismissible(
                            key: Key(task.key.toString()),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) async {
                              final deletedTask = task;

                              // 🔔 Cancel notification on delete
                              await NotificationService()
                                  .cancelNotification(
                                      task.key as int);

                              box.deleteAt(index);

                              final messenger =
                                  ScaffoldMessenger.of(context);
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text("Task deleted"),
                                    action: SnackBarAction(
                                      label: "UNDO",
                                      onPressed: () {
                                        box.add(deletedTask);
                                      },
                                    ),
                                  ),
                                );
                              });
                            },
                            background: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            child: Card(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddTaskScreen(task: task),
                                    ),
                                  );
                                },

                                // ✅ Checkbox
                                leading: GestureDetector(
                                  onTap: () {
                                    task.isCompleted = !task.isCompleted;
                                    task.save();
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(5),
                                      color: task.isCompleted
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: task.isCompleted
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(Icons.check,
                                            size: 14,
                                            color: Colors.white)
                                        : null,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // 🔥 Priority badge
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: getPriorityColor(
                                                      task.priority)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      10),
                                            ),
                                            child: Text(
                                              task.priority.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: getPriorityColor(
                                                    task.priority),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // 📅 Date + time
                                          Icon(
                                              Icons
                                                  .access_time_rounded,
                                              size: 11,
                                              color: Colors.grey
                                                  .shade500),
                                          const SizedBox(width: 3),
                                          Text(
                                            DateFormat('dd MMM · hh:mm a')
                                                .format(date),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (task.description != null &&
                                          task.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 2),
                                          child: Text(
                                            task.description!,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // ✅ AddTaskScreen now saves directly to Hive — no need to box.add() here
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget filterChip(String label, FilterType type) {
    final isSelected = selectedFilter == type;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Colors.white
                : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}