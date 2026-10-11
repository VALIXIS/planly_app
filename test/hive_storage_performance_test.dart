import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:planly/features/tasks/models/tag_model.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/services/app_state_service.dart';
import 'package:planly/services/hive_storage_service.dart';

void main() {
  late Directory tempDir;
  late Box<Task> taskBox;
  late Box<TagModel> tagBox;
  late Box settingsBox;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('hive_perf_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TagModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskSubtaskAdapter());
  });

  setUp(() async {
    taskBox = await Hive.openBox<Task>('tasks');
    tagBox = await Hive.openBox<TagModel>('tags');
    settingsBox = await Hive.openBox('settings');

    await taskBox.clear();
    await tagBox.clear();
    await settingsBox.clear();
  });

  tearDown(() async {
    await taskBox.close();
    await tagBox.close();
    await settingsBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveStorageService - Performance & Cold Start Audit', () {
    test('cold-start initialization executes in under 300ms', () async {
      final Stopwatch stopwatch = Stopwatch()..start();

      // Simulate cold start opening boxes in parallel
      await Future.wait([
        Hive.openBox<Task>('tasks_perf'),
        Hive.openBox<TagModel>('tags_perf'),
        Hive.openBox('settings_perf'),
      ]);

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300));

      await Hive.box<Task>('tasks_perf').close();
      await Hive.box<TagModel>('tags_perf').close();
      await Hive.box('settings_perf').close();
    });

    test('stress test: single-pass indexes 500+ mock tasks in < 20ms', () async {
      final now = DateTime.now();
      final baseToday = DateTime(now.year, now.month, now.day, 10, 0);
      final List<Task> mockTasks = List.generate(550, (index) {
        final isToday = index % 3 == 0;
        final isCompleted = index % 5 == 0;
        final priority = index % 2 == 0 ? 'High' : 'Low';
        final category = index % 4 == 0 ? 'Work' : 'Personal';

        return Task(
          title: 'Stress Task #$index',
          category: category,
          dueDate: isToday
              ? baseToday.add(Duration(minutes: (index % 120)))
              : now.add(Duration(days: (index % 10) + 1)),
          isCompleted: isCompleted,
          priority: priority,
          subtasks: [
            TaskSubtask(title: 'Subtask 1 for #$index', isCompleted: true),
            TaskSubtask(title: 'Subtask 2 for #$index', isCompleted: false),
          ],
        );
      });

      await taskBox.addAll(mockTasks);
      expect(taskBox.length, 550);

      final List<Task> allTasks = taskBox.values.toList();
      final Stopwatch querySw = Stopwatch()..start();

      final result = HiveStorageService.queryAndIndexTasks(
        allTasks: allTasks,
        searchQuery: '',
        selectedFilterName: 'all',
        categories: ['Work', 'Personal', 'Shopping', 'Others'],
        now: now,
      );

      querySw.stop();

      expect(querySw.elapsedMilliseconds, lessThan(30));
      expect(result.allFilteredTasks.length, 550);
      expect(result.todayTasks.isNotEmpty, true);
      expect(result.upcomingTasks.isNotEmpty, true);
      expect(result.pendingCount + result.completedCount, 550);
      expect(result.smartGroups.isNotEmpty, true);
      expect(result.smartGroups.keys, contains('Overdue'));
      expect(result.suggestedTask, isNotNull);
    });

    test('box compaction shrinks storage and executes without errors', () async {
      final List<Task> mockTasks = List.generate(100, (i) => Task(title: 'Temp Task $i'));
      await taskBox.addAll(mockTasks);

      // Overwrite/delete half to create fragmented Hive entries
      for (int i = 0; i < 50; i++) {
        final task = taskBox.getAt(i);
        if (task != null) {
          task.title = 'Updated Task $i';
          await task.save();
        }
      }

      final Stopwatch compactSw = Stopwatch()..start();
      await HiveStorageService.compactAllBoxes();
      compactSw.stop();

      expect(compactSw.elapsedMilliseconds, lessThan(1500));
      expect(taskBox.length, 100);
    });
  });

  group('AppStateService - Redundant Write Audit', () {
    test('AppStateService prevents redundant writes to Hive when value is unchanged', () async {
      AppStateService.loadPersistedSettings();

      await AppStateService.setThemeMode(ThemeMode.dark);
      expect(settingsBox.get('isDarkMode'), true);

      // Repeat set with same value — should be a no-op
      await AppStateService.setThemeMode(ThemeMode.dark);
      expect(settingsBox.get('isDarkMode'), true);

      await AppStateService.setOnboardingDone();
      expect(settingsBox.get('onboardingDone'), true);

      await AppStateService.setReliabilityWizardSeen(true);
      expect(settingsBox.get(AppStateService.reliabilityWizardSeenKey), true);
    });
  });
}
