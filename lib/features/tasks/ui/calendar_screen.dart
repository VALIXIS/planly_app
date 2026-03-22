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
    final box = Hive.box<Task>('tasks'); // ✅ typed Hive box

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        title: const Text("Calendar"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 💜 Calendar
          TableCalendar<Task>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: selectedDay,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
              });
            },
            eventLoader: (day) {
              // ✅ Return only typed Task objects
              return box.values.where((task) {
                final due = task.dueDate;
                if (due == null) return false;
                return due.year == day.year &&
                    due.month == day.month &&
                    due.day == day.day;
              }).toList();
            },
            calendarStyle: const CalendarStyle(
              todayDecoration:
                  BoxDecoration(color: Color(0xFFB39DDB), shape: BoxShape.circle),
              selectedDecoration:
                  BoxDecoration(color: Color(0xFF9575CD), shape: BoxShape.circle),
              markerDecoration:
                  BoxDecoration(color: Color(0xFF7E57C2), shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),

          const SizedBox(height: 10),

          // 📋 Task list for selected day
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
                  return const Center(child: Text("No tasks for this day ✨"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasksForDay.length,
                  itemBuilder: (context, index) {
                    final task = tasksForDay[index];
                    final date = task.dueDate ?? DateTime.now();

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(task.title),
                        subtitle: Text(
                          "${task.category ?? "General"} | ${DateFormat('dd-MM-yyyy').format(date)}",
                          style: const TextStyle(color: Colors.grey),
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