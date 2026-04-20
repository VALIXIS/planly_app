import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/tasks/models/task_model.dart';

/// Handles scheduling, snoozing, and cancelling local task reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const String _notificationIcon = '@drawable/ic_planly_notification';
  static const Duration _minimumScheduleDelay = Duration(seconds: 5);

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

  Future<Box<Task>> _taskBox() async {
    if (Hive.isBoxOpen('tasks')) {
      return Hive.box<Task>('tasks');
    }

    return Hive.openBox<Task>('tasks');
  }

  Future<void> _configureLocalTimezone() async {
    tz.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (error) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
  }

  tz.TZDateTime _scheduleAt(DateTime scheduledTime) {
    final now = tz.TZDateTime.now(tz.local);
    final requestedTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final minTime = now.add(_minimumScheduleDelay);

    return requestedTime.isBefore(minTime) ? minTime : requestedTime;
  }

  Future<void> snoozeNotification(int id, {int minutes = 5}) async {
    await _plugin.zonedSchedule(
      id,
      'Snoozed Task',
      'This is your snoozed reminder!',
      _scheduleAt(DateTime.now().add(Duration(minutes: minutes))),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'planly_tasks',
          'Task Reminders',
          channelDescription: 'Reminders for your Planly tasks',
          icon: _notificationIcon,
          color: Color(0xFF6366F1),
        ),
      ),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> init() async {
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(_notificationIcon);
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

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    final canScheduleExactNotifications =
        await androidPlugin?.canScheduleExactNotifications() ?? true;
    if (!canScheduleExactNotifications) {
      final exactPermissionGranted =
          await androidPlugin?.requestExactAlarmsPermission() ?? false;
      _scheduleMode = exactPermissionGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
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
      icon: _notificationIcon,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      color: const Color(0xFF6366F1),
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

    final resolvedScheduleTime = _scheduleAt(scheduledTime);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      resolvedScheduleTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: _scheduleMode,
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
