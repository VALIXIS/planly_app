import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _deviceControlsChannel = MethodChannel(
    'planly/device_controls',
  );

  static bool get isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

  Future<AndroidNotificationHealth?> getAndroidNotificationHealth() async {
    if (!isAndroidDevice) return null;

    try {
      final raw = await _deviceControlsChannel
          .invokeMethod<Map<Object?, Object?>>('getBatteryOptimizationStatus');
      if (raw == null) return null;

      return AndroidNotificationHealth.fromMap(raw);
    } on PlatformException {
      return null;
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    if (!isAndroidDevice) return false;

    try {
      return await _deviceControlsChannel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openAutoStartSettings() async {
    if (!isAndroidDevice) return false;

    try {
      return await _deviceControlsChannel.invokeMethod<bool>(
            'openAutoStartSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final canScheduleExactNotifications =
        await androidPlugin?.canScheduleExactNotifications() ?? true;
    if (canScheduleExactNotifications) {
      _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      return true;
    }

    final exactPermissionGranted =
        await androidPlugin?.requestExactAlarmsPermission() ?? false;
    _scheduleMode = exactPermissionGranted
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    return exactPermissionGranted;
  }

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

  String _defaultTaskBody(Task task) {
    final description = task.description?.trim() ?? '';
    if (description.isNotEmpty) return description;
    return 'Your task is due now!';
  }

  DateTime _nextTonightTime() {
    final now = DateTime.now();
    final tonight = DateTime(now.year, now.month, now.day, 20);
    if (tonight.isAfter(now)) return tonight;
    return tonight.add(const Duration(days: 1));
  }

  Future<bool> scheduleTaskReminderAt(
    int taskId,
    DateTime when,
  ) async {
    final box = await _taskBox();
    final task = box.get(taskId);
    if (task == null) return false;

    await scheduleNotification(
      id: taskId,
      title: task.title,
      body: _defaultTaskBody(task),
      scheduledTime: when,
    );
    return true;
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

        if (id <= 0) return;

        if (response.actionId == 'snooze_10') {
          await scheduleTaskReminderAt(
            id,
            DateTime.now().add(const Duration(minutes: 10)),
          );
          return;
        }

        if (response.actionId == 'tonight') {
          await scheduleTaskReminderAt(id, _nextTonightTime());
          return;
        }

        if (response.actionId == 'done') {
          final box = await _taskBox();
          final task = box.get(id);
          if (task != null && !task.isCompleted) {
            task.isCompleted = true;
            await task.save();
            await cancelNotification(id);
          }
        }
      },
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await requestExactAlarmPermission();
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
          'snooze_10',
          'Snooze 10 min',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'tonight',
          'Tonight 8 PM',
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

    Future<void> doSchedule(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        resolvedScheduleTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    try {
      await doSchedule(_scheduleMode);
    } on PlatformException catch (error) {
      if (error.code == 'exact_alarms_not_permitted' &&
          _scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        await doSchedule(_scheduleMode);
        return;
      }
      rethrow;
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

class AndroidNotificationHealth {
  final bool isIgnoringBatteryOptimizations;
  final bool isPowerSaveModeEnabled;
  final bool canScheduleExactAlarms;
  final String manufacturer;
  final String brand;
  final String model;

  const AndroidNotificationHealth({
    required this.isIgnoringBatteryOptimizations,
    required this.isPowerSaveModeEnabled,
    required this.canScheduleExactAlarms,
    required this.manufacturer,
    required this.brand,
    required this.model,
  });

  factory AndroidNotificationHealth.fromMap(Map<Object?, Object?> raw) {
    bool readBool(String key, {required bool fallback}) {
      final value = raw[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return fallback;
    }

    String readString(String key) {
      final value = raw[key];
      return value == null ? '' : value.toString();
    }

    return AndroidNotificationHealth(
      isIgnoringBatteryOptimizations: readBool(
        'isIgnoringBatteryOptimizations',
        fallback: true,
      ),
      isPowerSaveModeEnabled: readBool(
        'isPowerSaveModeEnabled',
        fallback: false,
      ),
      canScheduleExactAlarms: readBool(
        'canScheduleExactAlarms',
        fallback: true,
      ),
      manufacturer: readString('manufacturer'),
      brand: readString('brand'),
      model: readString('model'),
    );
  }

  bool get hasDeliveryRisk =>
      !isIgnoringBatteryOptimizations ||
      isPowerSaveModeEnabled ||
      !canScheduleExactAlarms;

  bool get isVivoOrIqoo {
    final deviceInfo =
        '${manufacturer.toLowerCase()} ${brand.toLowerCase()} ${model.toLowerCase()}';
    return deviceInfo.contains('vivo') || deviceInfo.contains('iqoo');
  }

  String get deviceLabel {
    final parts = [brand.trim(), model.trim()]
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Android device';
    return parts.join(' ');
  }
}
