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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ℹ️ No AppBar here — handled by MainScreen
      body: Column(
        children: [
          // 📅 Calendar card
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
                  setState(() => selectedDay = selected);
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
                calendarStyle: CalendarStyle(
                  // Today circle
                  todayDecoration: BoxDecoration(
                    color: primary.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  // Selected day circle
                  selectedDecoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  // Task dot marker
                  markerDecoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                  // Dark mode text adjustments
                  defaultTextStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  todayTextStyle: TextStyle(
                    color: isDark ? Colors.white : primary,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left,
                      color: isDark ? Colors.white70 : Colors.black54),
                  rightChevronIcon: Icon(Icons.chevron_right,
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 🗓 Selected date label
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

          // 📋 Tasks for selected day
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
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tasksForDay.length,
                  itemBuilder: (context, index) {
                    final task = tasksForDay[index];
                    final date = task.dueDate ?? DateTime.now();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
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
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              // 🏷 Category badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  task.category ?? "General",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // ⏰ Time
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('hh:mm a').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
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