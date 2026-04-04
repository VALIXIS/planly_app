import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/tasks/models/task_model.dart';

/// Handles scheduling, snoozing, and cancelling local task reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<Box<Task>> _taskBox() async {
    if (Hive.isBoxOpen('tasks')) {
      return Hive.box<Task>('tasks');
    }

    return Hive.openBox<Task>('tasks');
  }

  Future<void> snoozeNotification(int id, {int minutes = 5}) async {
    await _plugin.zonedSchedule(
      id,
      'Snoozed Task',
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

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final id = response.id ?? 0;

        if (response.actionId == 'snooze') {
          await snoozeNotification(id, minutes: 5);
          return;
        }

        if (response.actionId == 'done') {
          final box = await _taskBox();
          final task = box.get(id);
          if (task != null && !task.isCompleted) {
            task.isCompleted = true;
            await task.save();
          }
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final box = await _taskBox();
    final task = box.get(id);
    final heading = switch (task?.priority) {
      'High' => 'High Priority',
      'Low' => 'Low Priority',
      _ => 'Reminder',
    };
    final expandedBody = [
      body,
      if (task?.category?.isNotEmpty == true) 'Category: ${task!.category}',
    ].join('\n');

    final androidDetails = AndroidNotificationDetails(
      'planly_tasks',
      'Task Reminders',
      channelDescription: 'Reminders for your Planly tasks',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: const Color(0xFF7C4DFF),
      styleInformation: BigTextStyleInformation(
        expandedBody,
        contentTitle: '$heading: $title',
        summaryText: 'Don\'t forget your task!',
      ),
      actions: const <AndroidNotificationAction>[
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

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
