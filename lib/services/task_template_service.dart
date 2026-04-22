import 'package:hive/hive.dart';

class TaskTemplate {
  final String name;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String? recurrenceRule;
  final int? reminderMinutesBefore;
  final bool reminderEnabled;
  final bool skipMissedRecurrences;

  const TaskTemplate({
    required this.name,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.recurrenceRule,
    required this.reminderMinutesBefore,
    required this.reminderEnabled,
    required this.skipMissedRecurrences,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'recurrenceRule': recurrenceRule,
      'reminderMinutesBefore': reminderMinutesBefore,
      'reminderEnabled': reminderEnabled,
      'skipMissedRecurrences': skipMissedRecurrences,
    };
  }

  factory TaskTemplate.fromMap(Map<dynamic, dynamic> raw) {
    return TaskTemplate(
      name: (raw['name'] ?? '').toString(),
      title: (raw['title'] ?? '').toString(),
      description: (raw['description'] ?? '').toString(),
      category: (raw['category'] ?? 'Personal').toString(),
      priority: (raw['priority'] ?? 'Medium').toString(),
      recurrenceRule: raw['recurrenceRule'] as String?,
      reminderMinutesBefore: raw['reminderMinutesBefore'] as int?,
      reminderEnabled: (raw['reminderEnabled'] as bool?) ?? true,
      skipMissedRecurrences: (raw['skipMissedRecurrences'] as bool?) ?? true,
    );
  }
}

class TaskTemplateService {
  TaskTemplateService._();

  static const String _templatesKey = 'taskTemplates';

  static Box<dynamic> get _settings => Hive.box('settings');

  static List<TaskTemplate> loadTemplates() {
    final rawList = _settings.get(_templatesKey, defaultValue: <dynamic>[]) as List<dynamic>;

    return rawList
        .whereType<Map>()
        .map((raw) => TaskTemplate.fromMap(raw))
        .where((template) => template.name.trim().isNotEmpty)
        .toList();
  }

  static Future<void> saveTemplate(TaskTemplate template) async {
    final templates = loadTemplates();
    final nextTemplates = templates
        .where((existing) =>
            existing.name.trim().toLowerCase() !=
            template.name.trim().toLowerCase())
        .toList();

    nextTemplates.add(template);

    await _settings.put(
      _templatesKey,
      nextTemplates.map((entry) => entry.toMap()).toList(growable: false),
    );
  }

  static Future<void> deleteTemplate(String name) async {
    final templates = loadTemplates();
    final nextTemplates = templates
        .where((template) =>
            template.name.trim().toLowerCase() != name.trim().toLowerCase())
        .toList();

    await _settings.put(
      _templatesKey,
      nextTemplates.map((entry) => entry.toMap()).toList(growable: false),
    );
  }
}
