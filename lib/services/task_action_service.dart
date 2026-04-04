import 'package:hive/hive.dart';

import '../features/tasks/models/task_model.dart';
import 'notification_service.dart';

class TaskActionService {
  TaskActionService._();

  static Task cloneTask(
    Task task, {
    DateTime? dueDate,
    bool? isCompleted,
  }) {
    return Task(
      title: task.title,
      category: task.category,
      dueDate: dueDate ?? task.dueDate,
      isCompleted: isCompleted ?? task.isCompleted,
      description: task.description,
      priority: task.priority,
      recurrenceRule: task.recurrenceRule,
      reminderTime: null,
      reminderMinutesBefore: task.reminderMinutesBefore,
      reminderEnabled: task.reminderEnabled,
    );
  }

  static DateTime? nextRecurringDueDate(Task task, {DateTime? now}) {
    final rule = task.recurrenceRule?.toLowerCase().trim();
    final dueDate = task.dueDate;
    final currentTime = now ?? DateTime.now();

    if (rule == null || rule.isEmpty || dueDate == null) return null;

    if (rule == 'daily') {
      var candidate = dueDate.add(const Duration(days: 1));
      while (!candidate.isAfter(currentTime)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    if (rule.startsWith('days:')) {
      final weekdays = rule
          .substring(5)
          .split(',')
          .map((day) => int.tryParse(day.trim()))
          .whereType<int>()
          .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
          .toSet();
      if (weekdays.isEmpty) return null;

      var candidate = dueDate.add(const Duration(days: 1));
      for (var i = 0; i < 14; i++) {
        if (weekdays.contains(candidate.weekday) &&
            candidate.isAfter(currentTime)) {
          return candidate;
        }
        candidate = candidate.add(const Duration(days: 1));
      }
    }

    return null;
  }

  static Future<void> scheduleReminderForTask(Task task) async {
    final key = task.key;
    final dueDate = task.dueDate;
    if (key is! int || !task.reminderEnabled || dueDate == null) return;

    final reminderAt = task.reminderMinutesBefore != null &&
            task.reminderMinutesBefore! > 0
        ? dueDate.subtract(Duration(minutes: task.reminderMinutesBefore!))
        : dueDate;

    if (!reminderAt.isAfter(DateTime.now())) return;

    await NotificationService().scheduleNotification(
      id: key,
      title: task.title,
      body: task.description?.trim().isNotEmpty == true
          ? task.description!.trim()
          : 'Your task is due now!',
      scheduledTime: reminderAt,
    );
  }

  static Future<Task?> createNextRecurringTask(Task completedTask) async {
    final nextDueDate = nextRecurringDueDate(completedTask);
    if (nextDueDate == null) return null;

    final box = Hive.box<Task>('tasks');
    final alreadyExists = box.values.any((task) {
      final dueDate = task.dueDate;
      return !task.isCompleted &&
          task.title == completedTask.title &&
          task.category == completedTask.category &&
          task.priority == completedTask.priority &&
          task.recurrenceRule == completedTask.recurrenceRule &&
          dueDate != null &&
          dueDate.isAtSameMomentAs(nextDueDate);
    });

    if (alreadyExists) return null;

    final nextTask = cloneTask(
      completedTask,
      dueDate: nextDueDate,
      isCompleted: false,
    );
    await box.add(nextTask);
    await scheduleReminderForTask(nextTask);
    return nextTask;
  }

  static Future<bool> setTaskCompletion(Task task, bool complete) async {
    if (task.isCompleted == complete) return false;

    task.isCompleted = complete;
    await task.save();

    final key = task.key;
    if (key is int) {
      if (complete) {
        await NotificationService().cancelNotification(key);
        await createNextRecurringTask(task);
      } else {
        await scheduleReminderForTask(task);
      }
    }

    return true;
  }
}
