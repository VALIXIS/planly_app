import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

/// Service for tracking Pomodoro focus sessions and daily focus habit stats.
class FocusStatsService {
  static const String _todayMinutesKey = 'focus_today_minutes';
  static const String _todaySessionsKey = 'focus_today_sessions';
  static const String _totalMinutesKey = 'focus_total_minutes';
  static const String _totalSessionsKey = 'focus_total_sessions';
  static const String _lastActiveDateKey = 'focus_last_active_date';
  static const String _streakKey = 'focus_daily_streak';
  static const String _historyKey = 'focus_daily_history';

  static Box<dynamic> get _box => Hive.box('settings');

  static String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Today's accumulated focus minutes.
  static int get todayFocusMinutes {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final lastDateStr = _box.get(_lastActiveDateKey) as String?;
    if (lastDateStr != todayStr) {
      return 0;
    }
    return (_box.get(_todayMinutesKey, defaultValue: 0) as num).toInt();
  }

  /// Today's completed focus sessions count.
  static int get todayCompletedSessions {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final lastDateStr = _box.get(_lastActiveDateKey) as String?;
    if (lastDateStr != todayStr) {
      return 0;
    }
    return (_box.get(_todaySessionsKey, defaultValue: 0) as num).toInt();
  }

  /// All-time total focus minutes.
  static int get totalFocusMinutes {
    return (_box.get(_totalMinutesKey, defaultValue: 0) as num).toInt();
  }

  /// All-time total completed focus sessions.
  static int get totalSessions {
    return (_box.get(_totalSessionsKey, defaultValue: 0) as num).toInt();
  }

  /// Current daily streak in days.
  static int get dailyStreak {
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final lastDateStr = _box.get(_lastActiveDateKey) as String?;
    if (lastDateStr == null) return 0;
    if (lastDateStr != todayStr) {
      try {
        final lastDate = DateFormat('yyyy-MM-dd').parse(lastDateStr);
        final differenceInDays = now.difference(lastDate).inDays;
        if (differenceInDays > 1) {
          return 0;
        }
      } catch (_) {}
    }
    return (_box.get(_streakKey, defaultValue: 0) as num).toInt();
  }

  /// Records a completed focus session, updating daily minutes, session count,
  /// habit streak, and historical analytics.
  static Future<void> recordCompletedSession({required int minutes}) async {
    if (minutes <= 0) return;

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final lastDateStr = _box.get(_lastActiveDateKey) as String?;

    var currentTodayMins = 0;
    var currentTodaySessions = 0;
    var currentStreak = dailyStreak;

    if (lastDateStr == todayStr) {
      currentTodayMins = (_box.get(_todayMinutesKey, defaultValue: 0) as num).toInt();
      currentTodaySessions = (_box.get(_todaySessionsKey, defaultValue: 0) as num).toInt();
    }

    final currentTotalMins = totalFocusMinutes;
    final currentTotalSessions = totalSessions;

    // Update daily streak if this is the first session today
    var nextStreak = currentStreak;
    if (currentTodaySessions == 0) {
      nextStreak = currentStreak + 1;
    }

    await _box.put(_todayMinutesKey, currentTodayMins + minutes);
    await _box.put(_todaySessionsKey, currentTodaySessions + 1);
    await _box.put(_totalMinutesKey, currentTotalMins + minutes);
    await _box.put(_totalSessionsKey, currentTotalSessions + 1);
    await _box.put(_streakKey, nextStreak);
    await _box.put(_lastActiveDateKey, todayStr);

    // Update history map
    final rawHistory = _box.get(_historyKey, defaultValue: <dynamic, dynamic>{});
    final history = Map<String, int>.from(
      (rawHistory as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
    history[todayStr] = (history[todayStr] ?? 0) + minutes;
    await _box.put(_historyKey, history);
  }

  /// Returns recent 7-day focus minutes history.
  static Map<String, int> getRecentWeeklyHistory() {
    final rawHistory = _box.get(_historyKey, defaultValue: <dynamic, dynamic>{});
    final history = Map<String, int>.from(
      (rawHistory as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );

    final result = <String, int>{};
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _formatDate(date);
      result[dateStr] = history[dateStr] ?? 0;
    }
    return result;
  }
}
