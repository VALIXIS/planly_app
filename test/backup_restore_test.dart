import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:planly/features/tasks/models/tag_model.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/services/backup_restore_service.dart';

void main() {
  late Box<Task> taskBox;
  late Box<TagModel> tagBox;
  late BackupRestoreService service;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('hive_backup_test_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TagModelAdapter());
    Hive.registerAdapter(TaskSubtaskAdapter());
  });

  setUp(() async {
    taskBox = await Hive.openBox<Task>('tasks');
    tagBox = await Hive.openBox<TagModel>('tags');
    await taskBox.clear();
    await tagBox.clear();
    service = BackupRestoreService();
  });

  tearDown(() async {
    await taskBox.close();
    await tagBox.close();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // ─── Schema validation ────────────────────────────────────────────────────

  group('importBackupJson — validation', () {
    test('rejects non-JSON input', () async {
      final result = await service.importBackupJson('not json');
      expect(result.success, false);
      expect(result.error, contains('valid JSON'));
    });

    test('rejects missing schemaVersion', () async {
      final json = jsonEncode({'tasks': [], 'tags': []});
      final result = await service.importBackupJson(json);
      expect(result.success, false);
      expect(result.error, contains('schemaVersion'));
    });

    test('rejects future schema version', () async {
      final json = jsonEncode({'schemaVersion': 9999, 'tasks': [], 'tags': []});
      final result = await service.importBackupJson(json);
      expect(result.success, false);
      expect(result.error, contains('newer version'));
    });

    test('rejects missing tasks array', () async {
      final json = jsonEncode({'schemaVersion': 1, 'tags': []});
      final result = await service.importBackupJson(json);
      expect(result.success, false);
      expect(result.error, contains('"tasks"'));
    });
  });

  // ─── Successful import ────────────────────────────────────────────────────

  group('importBackupJson — happy path', () {
    test('imports tasks and tags from valid backup', () async {
      final backup = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'appName': 'Planly',
        'tasks': [
          {
            'title': 'Buy groceries',
            'isCompleted': false,
            'priority': 'Medium',
            'tags': <String>[],
            'reminderEnabled': true,
            'skipMissedRecurrences': true,
          },
        ],
        'tags': [
          {'name': 'Work', 'colorValue': 0xFF7C4DFF},
        ],
      });

      final result = await service.importBackupJson(backup);

      expect(result.success, true);
      expect(result.tasksImported, 1);
      expect(result.tagsImported, 1);
      expect(result.tasksDuplicate, 0);
      expect(result.tagsDuplicate, 0);
      expect(taskBox.values.first.title, 'Buy groceries');
      expect(tagBox.values.first.name, 'Work');
    });

    test('skips duplicate tasks (same title+dueDate+category)', () async {
      await taskBox.add(Task(title: 'Meeting', priority: 'High'));

      final backup = jsonEncode({
        'schemaVersion': 1,
        'tasks': [
          {
            'title': 'Meeting',
            'isCompleted': false,
            'priority': 'High',
            'tags': <String>[],
            'reminderEnabled': true,
            'skipMissedRecurrences': true,
          },
          {
            'title': 'New Task',
            'isCompleted': false,
            'priority': 'Low',
            'tags': <String>[],
            'reminderEnabled': true,
            'skipMissedRecurrences': true,
          },
        ],
        'tags': [],
      });

      final result = await service.importBackupJson(backup);
      expect(result.tasksImported, 1);
      expect(result.tasksDuplicate, 1);
      expect(taskBox.length, 2);
    });

    test('skips duplicate tags (case-insensitive)', () async {
      await tagBox.add(TagModel(name: 'personal'));

      final backup = jsonEncode({
        'schemaVersion': 1,
        'tasks': [],
        'tags': [
          {'name': 'Personal'},
          {'name': 'Work'},
        ],
      });

      final result = await service.importBackupJson(backup);
      expect(result.tagsImported, 1);
      expect(result.tagsDuplicate, 1);
      expect(tagBox.length, 2);
    });

    test('handles subtasks inside tasks', () async {
      final backup = jsonEncode({
        'schemaVersion': 1,
        'tasks': [
          {
            'title': 'Project Alpha',
            'isCompleted': false,
            'priority': 'High',
            'tags': <String>[],
            'reminderEnabled': true,
            'skipMissedRecurrences': true,
            'subtasks': [
              {'title': 'Research', 'minutes': 30, 'isCompleted': false},
              {'title': 'Write report', 'minutes': 60, 'isCompleted': true},
            ],
          },
        ],
        'tags': [],
      });

      final result = await service.importBackupJson(backup);
      expect(result.tasksImported, 1);
      final imported = taskBox.values.first;
      expect(imported.subtasks?.length, 2);
      expect(imported.subtasks?.last.isCompleted, true);
    });

    test('empty backup imports nothing', () async {
      final backup = jsonEncode({'schemaVersion': 1, 'tasks': [], 'tags': []});
      final result = await service.importBackupJson(backup);
      expect(result.success, true);
      expect(result.tasksImported, 0);
      expect(result.tagsImported, 0);
      expect(result.summary, contains('Nothing'));
    });
  });

  // ─── ImportResult.summary ────────────────────────────────────────────────

  group('ImportResult.summary', () {
    test('returns failure message when error set', () {
      const r = ImportResult(error: 'Bad JSON');
      expect(r.summary, contains('Bad JSON'));
      expect(r.success, false);
    });

    test('returns nothing new message when all counts are zero', () {
      const r = ImportResult();
      expect(r.summary, contains('Nothing'));
    });

    test('returns combined import/skip summary', () {
      const r = ImportResult(
        tasksImported: 3,
        tasksDuplicate: 1,
        tagsImported: 2,
      );
      expect(r.summary, contains('3 task(s) imported'));
      expect(r.summary, contains('1 duplicate(s) skipped'));
      expect(r.summary, contains('2 tag(s) imported'));
    });
  });
}
