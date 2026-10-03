import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';

/// Service for calculating 90-day task completion history, habit heatmap data,
/// and consecutive day streaks.
class HabitStatsService {
  HabitStatsService._();

  static const String _completionHistoryKey = 'task_completion_history';
  static const String _streakKey = 'taskStreakCount';

  static Box<dynamic> get _settingsBox => Hive.box('settings');

  static String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Records a completed task title for a specific date (defaults to today).
  static Future<void> recordTaskCompletion(String title, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = _formatDate(targetDate);

    final rawHistory = _settingsBox.get(_completionHistoryKey, defaultValue: <dynamic, dynamic>{});
    final history = Map<String, List<String>>.from(
      (rawHistory as Map).map((k, v) => MapEntry(
            k.toString(),
            (v as List).map((e) => e.toString()).toList(),
          )),
    );

    final list = history[dateStr] ?? <String>[];
    if (!list.contains(title)) {
      list.add(title);
    }
    history[dateStr] = list;

    await _settingsBox.put(_completionHistoryKey, history);
  }

  /// Removes a task completion record if a task is uncompleted.
  static Future<void> unrecordTaskCompletion(String title, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = _formatDate(targetDate);

    final rawHistory = _settingsBox.get(_completionHistoryKey, defaultValue: <dynamic, dynamic>{});
    final history = Map<String, List<String>>.from(
      (rawHistory as Map).map((k, v) => MapEntry(
            k.toString(),
            (v as List).map((e) => e.toString()).toList(),
          )),
    );

    if (history.containsKey(dateStr)) {
      history[dateStr]!.remove(title);
      await _settingsBox.put(_completionHistoryKey, history);
    }
  }

  /// Returns task completion history aggregated over the last [days] days.
  /// Combines explicit completion logs with completed tasks found in Hive.
  static Map<DateTime, List<String>> getCompletionData({int days = 90}) {
    final now = DateTime.now();
    final today = _normalizeDate(now);
    final startDate = today.subtract(Duration(days: days));

    final result = <DateTime, List<String>>{};

    // Initialize all dates in range with empty list
    for (var i = 0; i <= days; i++) {
      final d = startDate.add(Duration(days: i));
      result[d] = <String>[];
    }

    // 1. Read persistent history from settings box
    final rawHistory = _settingsBox.get(_completionHistoryKey, defaultValue: <dynamic, dynamic>{});
    if (rawHistory is Map) {
      rawHistory.forEach((k, v) {
        try {
          final parsedDate = DateFormat('yyyy-MM-dd').parse(k.toString());
          final normalized = _normalizeDate(parsedDate);
          if (result.containsKey(normalized) && v is List) {
            final titles = v.map((e) => e.toString()).toList();
            for (final title in titles) {
              if (!result[normalized]!.contains(title)) {
                result[normalized]!.add(title);
              }
            }
          }
        } catch (_) {}
      });
    }

    // 2. Scan tasks in Hive box to include any completed tasks with due dates
    if (Hive.isBoxOpen('tasks')) {
      final taskBox = Hive.box<Task>('tasks');
      for (final task in taskBox.values) {
        if (task.isCompleted) {
          final target = task.dueDate != null
              ? _normalizeDate(task.dueDate!)
              : today;

          if (result.containsKey(target)) {
            if (!result[target]!.contains(task.title)) {
              result[target]!.add(task.title);
            }
          }
        }
      }
    }

    return result;
  }

  /// Calculates the current consecutive completion streak in days.
  static int getCurrentStreak() {
    final data = getCompletionData(days: 90);
    final today = _normalizeDate(DateTime.now());

    int streak = 0;
    var checkDate = today;

    // If today has no completed tasks yet, check if streak from yesterday is still alive
    if ((data[today]?.isEmpty ?? true)) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (data[yesterday]?.isNotEmpty ?? false) {
        checkDate = yesterday;
      } else {
        // Fallback to persisted streak count if available
        final persisted = _settingsBox.get(_streakKey, defaultValue: 0);
        return (persisted as num).toInt();
      }
    }

    while (data[checkDate]?.isNotEmpty ?? false) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // If persisted streak is higher, respect it
    final persisted = _settingsBox.get(_streakKey, defaultValue: 0) as num;
    if (persisted.toInt() > streak) {
      return persisted.toInt();
    }

    return streak;
  }

  /// Total number of tasks completed in the last 90 days.
  static int getTotalCompletedTasksInLast90Days() {
    final data = getCompletionData(days: 90);
    int total = 0;
    for (final tasks in data.values) {
      total += tasks.length;
    }
    return total;
  }
}
