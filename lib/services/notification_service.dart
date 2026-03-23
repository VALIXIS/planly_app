import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// 🔔 NotificationService — Android only
/// Handles scheduling and cancelling local notifications.
class NotificationService {
  // Singleton — only one instance ever exists
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Call once in main() before runApp()
  Future<void> init() async {
    // ✅ Initialize timezone database
    tz.initializeTimeZones();

    // ✅ Android init — uses your app launcher icon
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // ✅ Request POST_NOTIFICATIONS permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a notification for a task
  /// [id]            — unique int (use task's Hive key)
  /// [title]         — notification title
  /// [body]          — notification subtitle
  /// [scheduledTime] — exact DateTime to fire
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    // Don't schedule notifications in the past — they'd fire immediately
    if (scheduledTime.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'planly_tasks',       // Channel ID — must be unique per app
      'Task Reminders',     // Channel name shown in Android settings
      channelDescription: 'Reminders for your Planly tasks',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      // Convert DateTime to timezone-aware TZDateTime
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      // ✅ Fires even when device is in low-power mode
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification by its ID
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel every scheduled notification (e.g. on data wipe)
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}