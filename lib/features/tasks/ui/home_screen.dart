import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Planly"),
      ),

      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Task> box, _) {
          final tasks = box.values.toList();
          final completed = tasks.where((t) => t.isCompleted).length;
          final progress =
              tasks.isEmpty ? 0.0 : completed / tasks.length;

          return Column(
            children: [
              // 💎 Progress Card
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Progress",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$completed / ${tasks.length} tasks completed",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: const Color(0xFFEDE7F6),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              // 📋 Task List
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          "No tasks yet ✨",
                          style:
                              Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final date =
                              task.dueDate ?? DateTime.now();

                          return Dismissible(
                            key: Key(task.key.toString()),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              final deletedTask = task;
                              box.deleteAt(index);

                              final messenger =
                                  ScaffoldMessenger.of(context);

                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text("Task deleted"),
                                    duration:
                                        const Duration(seconds: 2),
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
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),

                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6),
                              child: ListTile(
                                // ✅ NEW: TAP TO EDIT
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddTaskScreen(task: task),
                                    ),
                                  );
                                },

                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10),

                                // ✅ Checkbox
                                leading: GestureDetector(
                                  onTap: () {
                                    task.isCompleted =
                                        !task.isCompleted;
                                    task.save();
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(6),
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
                                        width: 1.8,
                                      ),
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(Icons.check,
                                            size: 16,
                                            color: Colors.white)
                                        : null,
                                  ),
                                ),

                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),

                                subtitle: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      // 🏷 Category
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  20),
                                        ),
                                        child: Text(
                                          task.category ?? "General",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // 📅 Date
                                      Text(
                                        DateFormat('dd MMM')
                                            .format(date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
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
        onPressed: () async {
          final Task? newTask = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddTaskScreen()),
          );

          if (newTask != null) {
            box.add(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}