import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../features/tasks/models/tag_model.dart';
import '../features/tasks/models/task_model.dart';

/// Semantic version of the backup schema. Bump only on breaking changes.
const int _kBackupSchemaVersion = 1;

/// Result returned from [BackupRestoreService.importBackupJson].
class ImportResult {
  final int tasksImported;
  final int tasksDuplicate;
  final int tagsImported;
  final int tagsDuplicate;
  final String? error;

  const ImportResult({
    this.tasksImported = 0,
    this.tasksDuplicate = 0,
    this.tagsImported = 0,
    this.tagsDuplicate = 0,
    this.error,
  });

  bool get success => error == null;

  String get summary {
    if (!success) return 'Import failed: $error';
    final parts = <String>[];
    if (tasksImported > 0) parts.add('$tasksImported task(s) imported');
    if (tasksDuplicate > 0) parts.add('$tasksDuplicate duplicate(s) skipped');
    if (tagsImported > 0) parts.add('$tagsImported tag(s) imported');
    if (tagsDuplicate > 0) parts.add('$tagsDuplicate tag duplicate(s) skipped');
    return parts.isEmpty ? 'Nothing new to import.' : '${parts.join(', ')}.';
  }
}

class BackupRestoreService {
  // ─── Export ──────────────────────────────────────────────────────────────

  /// Serialises all tasks and tags to a formatted JSON string and
  /// triggers the system share sheet so the user can save/send the file.
  ///
  /// Returns the generated JSON string (useful for testing).
  Future<String> exportBackupJson() async {
    final taskBox = Hive.box<Task>('tasks');
    final tagBox = Hive.box<TagModel>('tags');

    final tasks = taskBox.values.map(_taskToJson).toList();
    final tags = tagBox.values.map(_tagToJson).toList();

    final payload = {
      'schemaVersion': _kBackupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Planly',
      'tasks': tasks,
      'tags': tags,
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);

    // Write to a temp file so share_plus can attach it.
    final dir = await getTemporaryDirectory();
    final fileName =
        'planly_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Planly Backup – $fileName',
    );

    return json;
  }

  // ─── Import ──────────────────────────────────────────────────────────────

  /// Validates [jsonString], then inserts tasks/tags that don't already exist.
  ///
  /// Duplicate detection:
  ///   - Tasks  → same `title` + `dueDate` (ISO string) + `category`
  ///   - Tags   → same `name` (case-insensitive)
  Future<ImportResult> importBackupJson(String jsonString) async {
    // 1. Parse JSON
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return const ImportResult(error: 'File is not valid JSON.');
    }

    // 2. Schema version check
    final version = payload['schemaVersion'];
    if (version == null || version is! int) {
      return const ImportResult(
          error: 'Missing or invalid schemaVersion field.');
    }
    if (version > _kBackupSchemaVersion) {
      return ImportResult(
        error:
            'Backup was created with a newer version of Planly (schema v$version). '
            'Please update the app and try again.',
      );
    }

    // 3. Validate required top-level keys
    if (payload['tasks'] is! List || payload['tags'] is! List) {
      return const ImportResult(
          error: 'Backup file is missing required "tasks" or "tags" arrays.');
    }

    final rawTasks = payload['tasks'] as List<dynamic>;
    final rawTags = payload['tags'] as List<dynamic>;

    // 4. Import tags first (tasks may reference tag names)
    final tagResult = await _importTags(rawTags);
    if (!tagResult.success) return tagResult;

    // 5. Import tasks
    final taskResult = await _importTasks(rawTasks);
    if (!taskResult.success) return taskResult;

    return ImportResult(
      tasksImported: taskResult.tasksImported,
      tasksDuplicate: taskResult.tasksDuplicate,
      tagsImported: tagResult.tagsImported,
      tagsDuplicate: tagResult.tagsDuplicate,
    );
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  Future<ImportResult> _importTags(List<dynamic> rawTags) async {
    final tagBox = Hive.box<TagModel>('tags');
    final existingNames =
        tagBox.values.map((t) => t.name.toLowerCase()).toSet();

    int imported = 0;
    int duplicates = 0;

    for (final raw in rawTags) {
      if (raw is! Map<String, dynamic>) continue;
      final name = raw['name'] as String? ?? '';
      if (name.isEmpty) continue;

      if (existingNames.contains(name.toLowerCase())) {
        duplicates++;
        continue;
      }

      final tag = TagModel(
        name: name,
        colorValue: raw['colorValue'] as int?,
      );
      await tagBox.add(tag);
      existingNames.add(name.toLowerCase());
      imported++;
    }

    return ImportResult(tagsImported: imported, tagsDuplicate: duplicates);
  }

  Future<ImportResult> _importTasks(List<dynamic> rawTasks) async {
    final taskBox = Hive.box<Task>('tasks');

    // Build a dedup key set: title|dueDate|category
    String keyOf(Task t) =>
        '${t.title}|${t.dueDate?.toIso8601String() ?? ''}|${t.category ?? ''}';

    final existingKeys = taskBox.values.map(keyOf).toSet();

    int imported = 0;
    int duplicates = 0;

    for (final raw in rawTasks) {
      if (raw is! Map<String, dynamic>) continue;

      Task task;
      try {
        task = _taskFromJson(raw);
      } catch (e) {
        // Skip malformed task entries gracefully
        continue;
      }

      final key = keyOf(task);
      if (existingKeys.contains(key)) {
        duplicates++;
        continue;
      }

      await taskBox.add(task);
      existingKeys.add(key);
      imported++;
    }

    return ImportResult(tasksImported: imported, tasksDuplicate: duplicates);
  }

  // ─── Serialisation helpers ───────────────────────────────────────────────

  Map<String, dynamic> _taskToJson(Task t) => {
        'title': t.title,
        'category': t.category,
        'dueDate': t.dueDate?.toIso8601String(),
        'isCompleted': t.isCompleted,
        'description': t.description,
        'priority': t.priority,
        'recurrenceRule': t.recurrenceRule,
        'reminderTime': t.reminderTime?.toIso8601String(),
        'reminderMinutesBefore': t.reminderMinutesBefore,
        'reminderEnabled': t.reminderEnabled,
        'skipMissedRecurrences': t.skipMissedRecurrences,
        'tags': t.tags,
        'subtasks': t.subtasks?.map((s) => s.toJson()).toList(),
      };

  Task _taskFromJson(Map<String, dynamic> j) => Task(
        title: j['title'] as String? ?? 'Untitled',
        category: j['category'] as String?,
        dueDate: j['dueDate'] != null
            ? DateTime.tryParse(j['dueDate'] as String)
            : null,
        isCompleted: j['isCompleted'] as bool? ?? false,
        description: j['description'] as String?,
        priority: j['priority'] as String? ?? 'Medium',
        recurrenceRule: j['recurrenceRule'] as String?,
        reminderTime: j['reminderTime'] != null
            ? DateTime.tryParse(j['reminderTime'] as String)
            : null,
        reminderMinutesBefore: j['reminderMinutesBefore'] as int?,
        reminderEnabled: j['reminderEnabled'] as bool? ?? true,
        skipMissedRecurrences: j['skipMissedRecurrences'] as bool? ?? true,
        tags: (j['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        subtasks: (j['subtasks'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(TaskSubtask.fromJson)
            .toList(),
      );

  Map<String, dynamic> _tagToJson(TagModel t) => {
        'name': t.name,
        'colorValue': t.colorValue,
      };
}
