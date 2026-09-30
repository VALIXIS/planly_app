import 'package:hive/hive.dart';

import '../features/tasks/models/task_model.dart';
import 'notification_service.dart';

class TaskActionService {
  TaskActionService._();

  static const Duration _minimumNextDelay = Duration(minutes: 1);

  static DateTime? _buildReminderTime(Task task) {
    final dueDate = task.dueDate;
    if (dueDate == null) return null;

    if (task.reminderMinutesBefore != null && task.reminderMinutesBefore! > 0) {
      return dueDate.subtract(Duration(minutes: task.reminderMinutesBefore!));
    }

    return dueDate;
  }

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
      skipMissedRecurrences: task.skipMissedRecurrences,
      subtasks: task.subtasks
          ?.map(
            (s) => TaskSubtask(
              title: s.title,
              minutes: s.minutes,
              isCompleted: false,
            ),
          )
          .toList(),
    );
  }

  static DateTime _safeFutureFromNow() {
    return DateTime.now().add(_minimumNextDelay);
  }

  static int? _parseIntervalDays(String rule) {
    if (!rule.startsWith('interval:')) return null;
    final raw = rule.substring('interval:'.length).trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static DateTime _addMonthsPreservingClock(DateTime source, int monthsToAdd) {
    final totalMonths = source.month + monthsToAdd;
    final targetYear = source.year + ((totalMonths - 1) ~/ 12);
    final targetMonth = ((totalMonths - 1) % 12) + 1;

    final firstOfNextMonth = targetMonth == 12
        ? DateTime(targetYear + 1, 1, 1)
        : DateTime(targetYear, targetMonth + 1, 1);
    final lastDayOfTargetMonth =
        firstOfNextMonth.subtract(const Duration(days: 1)).day;
    final targetDay = source.day <= lastDayOfTargetMonth
        ? source.day
        : lastDayOfTargetMonth;

    return DateTime(
      targetYear,
      targetMonth,
      targetDay,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }

  static DateTime? nextRecurringDueDate(Task task, {DateTime? now}) {
    final rule = task.recurrenceRule?.toLowerCase().trim();
    final dueDate = task.dueDate;
    final currentTime = now ?? DateTime.now();
    final skipMissed = task.skipMissedRecurrences;

    if (rule == null || rule.isEmpty || dueDate == null) return null;

    DateTime? firstCandidate;
    DateTime Function(DateTime current)? advance;

    if (rule == 'daily') {
      firstCandidate = dueDate.add(const Duration(days: 1));
      advance = (current) => current.add(const Duration(days: 1));
    } else if (rule == 'weekly') {
      firstCandidate = dueDate.add(const Duration(days: 7));
      advance = (current) => current.add(const Duration(days: 7));
    } else if (rule == 'monthly') {
      firstCandidate = _addMonthsPreservingClock(dueDate, 1);
      advance = (current) => _addMonthsPreservingClock(current, 1);
    } else {
      final intervalDays = _parseIntervalDays(rule);
      if (intervalDays != null) {
        final interval = Duration(days: intervalDays);
        firstCandidate = dueDate.add(interval);
        advance = (current) => current.add(interval);
      }
    }

    if (firstCandidate != null && advance != null) {
      if (!skipMissed) {
        return firstCandidate.isAfter(currentTime)
            ? firstCandidate
            : _safeFutureFromNow();
      }

      var candidate = firstCandidate;
      while (!candidate.isAfter(currentTime)) {
        candidate = advance(candidate);
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
      for (var i = 0; i < 400; i++) {
        if (weekdays.contains(candidate.weekday) &&
            (skipMissed || candidate.isAfter(currentTime))) {
          return candidate;
        }
        candidate = candidate.add(const Duration(days: 1));
      }

      if (!skipMissed) {
        return _safeFutureFromNow();
      }
    }

    return null;
  }

  static Future<void> scheduleReminderForTask(Task task) async {
    final key = task.key;
    if (key is! int || !task.reminderEnabled) return;

    final reminderAt = _buildReminderTime(task);
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      await NotificationService().cancelNotification(key);
      return;
    }

    await NotificationService().cancelNotification(key);

    await NotificationService().scheduleNotification(
      id: key,
      title: task.title,
      body: task.description?.trim().isNotEmpty == true
          ? task.description!.trim()
          : 'Your task is due now!',
      scheduledTime: reminderAt,
    );
  }

  static Future<void> resyncAllUpcomingReminders() async {
    final box = Hive.box<Task>('tasks');

    for (final task in box.values) {
      final key = task.key;
      if (key is! int) continue;

      final shouldHaveReminder =
          task.reminderEnabled && !task.isCompleted && task.dueDate != null;

      if (!shouldHaveReminder) {
        await NotificationService().cancelNotification(key);
        continue;
      }

      await scheduleReminderForTask(task);
    }
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
