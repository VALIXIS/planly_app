import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Task>('tasks');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text("Calendar"),
      ),

      body: Column(
        children: [
          // 📅 Calendar Card (Modern Container)
          Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TableCalendar<Task>(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: selectedDay,

                selectedDayPredicate: (day) =>
                    isSameDay(day, selectedDay),

                onDaySelected: (selected, focused) {
                  setState(() {
                    selectedDay = selected;
                  });
                },

                eventLoader: (day) {
                  return box.values.where((task) {
                    final due = task.dueDate;
                    if (due == null) return false;
                    return due.year == day.year &&
                        due.month == day.month &&
                        due.day == day.day;
                  }).toList();
                },

                // 🎨 MODERN STYLING
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),

                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 🧾 Selected Date Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE, dd MMM').format(selectedDay),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 📋 Task List
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<Task> box, _) {
                final tasksForDay = box.values.where((task) {
                  final due = task.dueDate;
                  if (due == null) return false;
                  return due.year == selectedDay.year &&
                      due.month == selectedDay.month &&
                      due.day == selectedDay.day;
                }).toList();

                if (tasksForDay.isEmpty) {
                  return Center(
                    child: Text(
                      "No tasks for this day ✨",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tasksForDay.length,
                  itemBuilder: (context, index) {
                    final task = tasksForDay[index];
                    final date =
                        task.dueDate ?? DateTime.now();

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),

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
                                      BorderRadius.circular(20),
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}