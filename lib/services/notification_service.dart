import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import '../features/tasks/models/task_model.dart';
import 'package:flutter/material.dart';
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

  /// Snooze a notification by rescheduling it for [minutes] later
  Future<void> snoozeNotification(int id, {int minutes = 5}) async {
    await _plugin.zonedSchedule(
      id,
      '🔔 Snoozed Task',
      'This is your snoozed reminder!',
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planly_tasks',
          'Task Reminders',
          channelDescription: 'Reminders for your Planly tasks',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Call once in main() before runApp()
  Future<void> init() async {
    // ✅ Initialize timezone database
    tz.initializeTimeZones();

    // ✅ Android init — uses your app launcher icon
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification action buttons
        if (response.actionId == 'snooze') {
          final id = response.id ?? 0;
          await NotificationService().snoozeNotification(id, minutes: 5);
        } else if (response.actionId == 'done') {
          final id = response.id ?? 0;
          // Mark the corresponding task as done in Hive
          final box = await Hive.openBox<Task>('tasks');
          final task = box.get(id);
          if (task != null && !task.isCompleted) {
            task.isCompleted = true;
            await task.save();
          }
        }
      },
    );

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

    // Fetch the task for premium info
    final box = await Hive.openBox<Task>('tasks');
    final task = box.get(id);
    String emoji = '🔔';
    if (task != null) {
      if (task.priority == 'High') emoji = '🔥';
      else if (task.priority == 'Low') emoji = '🧊';
      else emoji = '🔔';
    }

    // Accent color (fallback to violet)
    final accentColor = const Color(0xFF7C4DFF);

    final androidDetails = AndroidNotificationDetails(
      'planly_tasks',
      'Task Reminders',
      channelDescription: 'Reminders for your Planly tasks',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: accentColor,
      styleInformation: BigTextStyleInformation(
        body +
          (task != null && task.category != null ? '\nCategory: ${task.category}' : '') +
          (task != null && task.priority.isNotEmpty ? '\nPriority: ${task.priority}' : ''),
        contentTitle: '$emoji $title',
        summaryText: 'Don\'t forget your task!',
      ),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'snooze',
          'Snooze 5 min',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'done',
          'Mark as Done',
          showsUserInterface: true,
        ),
      ],
      onlyAlertOnce: true,
    );
  /// Snooze a notification by rescheduling it for [minutes] later
  Future<void> snoozeNotification(int id, {int minutes = 5}) async {
    await _plugin.zonedSchedule(
      id,
      '🔔 Snoozed Task',
      'This is your snoozed reminder!',
      tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planly_tasks',
          'Task Reminders',
          channelDescription: 'Reminders for your Planly tasks',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

    final details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      '🔔 $title',
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
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