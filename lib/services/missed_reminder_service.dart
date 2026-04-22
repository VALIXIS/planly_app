import 'package:hive/hive.dart';

import '../features/tasks/models/task_model.dart';

class MissedReminderItem {
  final int taskId;
  final String taskTitle;
  final DateTime dueAt;

  const MissedReminderItem({
    required this.taskId,
    required this.taskTitle,
    required this.dueAt,
  });
}

class MissedReminderService {
  MissedReminderService._();

  static List<MissedReminderItem> collectMissedReminders({
    DateTime? now,
    Duration lookback = const Duration(days: 3),
  }) {
    final current = now ?? DateTime.now();
    final earliest = current.subtract(lookback);

    final tasks = Hive.box<Task>('tasks').values;

    final items = tasks
        .where((task) => !task.isCompleted)
        .map((task) {
          final key = task.key;
          final due = task.dueDate;
          if (key is! int || due == null || !task.reminderEnabled) {
            return null;
          }

          if (due.isBefore(earliest) || !due.isBefore(current)) {
            return null;
          }

          return MissedReminderItem(
            taskId: key,
            taskTitle: task.title,
            dueAt: due,
          );
        })
        .whereType<MissedReminderItem>()
        .toList();

    items.sort((a, b) => b.dueAt.compareTo(a.dueAt));
    return items;
  }
}
