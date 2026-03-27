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

    final calendarHeight = MediaQuery.of(context).size.height * 0.42;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [

            /// Calendar
            SizedBox(
              height: calendarHeight,
              child: Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: TableCalendar<Task>(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2030),
                    focusedDay: selectedDay,
                    rowHeight: 36,

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
                      todayDecoration: BoxDecoration(
                        color: primary.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                      defaultTextStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      weekendTextStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      todayTextStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : primary,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedTextStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54),
                      rightChevronIcon: Icon(Icons.chevron_right,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54),
                    ),

                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      weekendStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// Date label
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat('EEEE, dd MMM').format(selectedDay),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),

            /// Task list
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

                  /// ✅ UPDATED EMPTY STATE
                  if (tasksForDay.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 44,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No tasks for this day",
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Select another date or add a task",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: tasksForDay.length,
                    itemBuilder: (context, index) {
                      final task = tasksForDay[index];
                      final date = task.dueDate ?? DateTime.now();

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
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        primary.withOpacity(0.1),
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
                                Icon(Icons.access_time_rounded,
                                    size: 12,
                                    color:
                                        Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('hh:mm a')
                                      .format(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey.shade500,
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
      ),
    );
  }
}