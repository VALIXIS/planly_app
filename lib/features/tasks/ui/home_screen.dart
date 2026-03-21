import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'add_task_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('tasks');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),

      appBar: AppBar(
        title: const Text("Planly"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box box, _) {
          int completed =
              box.values.where((t) => t['isDone'] == true).length;

          return Column(
            children: [
              // 💎 Progress Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD1C4E9),
                      Color(0xFFB39DDB),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Progress",
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$completed / ${box.length} tasks completed",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: box.length == 0
                          ? 0
                          : completed / box.length,
                      backgroundColor: Colors.white30,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ],
                ),
              ),

              // 📋 Task List
              Expanded(
                child: box.isEmpty
                    ? const Center(child: Text("No tasks yet ✨"))
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: box.length,
                        itemBuilder: (context, index) {
                          var task = box.getAt(index);
                          DateTime date =
                              DateTime.tryParse(task['date']) ??
                                  DateTime.now();

                          return Dismissible(
                            key: Key(task['title'] + task['date']),
                            direction: DismissDirection.endToStart,

                            onDismissed: (_) {
                              var deletedTask = task;

                              // ✅ remove immediately
                              box.deleteAt(index);

                              final messenger =
                                  ScaffoldMessenger.of(context);

                              // 🔥 FINAL FIX (post frame)
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                messenger.hideCurrentSnackBar();

                                messenger.showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text("Task deleted"),
                                    duration:
                                        const Duration(seconds: 2),
                                    behavior:
                                        SnackBarBehavior.floating,
                                    margin:
                                        const EdgeInsets.all(12),
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
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade300,
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(
                                  right: 20),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),

                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: task['isDone']
                                    ? const Color(0xFFEDE7F6)
                                    : const Color(0xFFF8F6FF),
                                borderRadius:
                                    BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(0.04),
                                    blurRadius: 8,
                                    offset:
                                        const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      task['isDone'] =
                                          !task['isDone'];
                                      box.putAt(index, task);
                                    },
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                        color: task['isDone']
                                            ? const Color(
                                                0xFF9575CD)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: task['isDone']
                                              ? const Color(
                                                  0xFF9575CD)
                                              : Colors.grey
                                                  .shade400,
                                          width: 2,
                                        ),
                                      ),
                                      child: task['isDone']
                                          ? const Icon(
                                              Icons.check,
                                              size: 18,
                                              color:
                                                  Colors.white)
                                          : null,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          task['title'],
                                          style: TextStyle(
                                            decoration: task[
                                                    'isDone']
                                                ? TextDecoration
                                                    .lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      horizontal:
                                                          10,
                                                      vertical:
                                                          4),
                                              decoration:
                                                  BoxDecoration(
                                                color: const Color(
                                                        0xFFB39DDB)
                                                    .withOpacity(
                                                        0.2),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            20),
                                              ),
                                              child: Text(
                                                task['category'] ??
                                                    "General",
                                                style:
                                                    const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(
                                                      0xFF7E57C2),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                                width: 10),
                                            Text(
                                              DateFormat(
                                                      'dd MMM')
                                                  .format(date),
                                              style:
                                                  const TextStyle(
                                                      fontSize:
                                                          12,
                                                      color: Colors
                                                          .grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
        backgroundColor: const Color(0xFFB39DDB),
        onPressed: () async {
          final newTask = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
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