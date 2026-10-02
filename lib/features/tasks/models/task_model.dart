import 'package:hive/hive.dart';

part 'task_model.g.dart';

typedef SubTask = TaskSubtask;

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String? category;

  @HiveField(2)
  DateTime? dueDate;

  @HiveField(3)
  bool isCompleted;

  @HiveField(4)
  String? description;

  @HiveField(5)
  String priority;

  // Recurring task fields
  @HiveField(6)
  String? recurrenceRule; // e.g., "daily", "weekly", "monthly", or custom RRULE

  @HiveField(7)
  DateTime? reminderTime; // For advanced reminders

  @HiveField(8)
  int? reminderMinutesBefore; // e.g., 10 for 10 minutes before

  @HiveField(9)
  bool reminderEnabled;

  @HiveField(10)
  bool skipMissedRecurrences;

  @HiveField(11)
  List<String> tags;

  @HiveField(12)
  List<TaskSubtask>? subtasks;

  Task({
    required this.title,
    this.category,
    this.dueDate,
    this.isCompleted = false,
    this.description,
    this.priority = "Medium",
    this.recurrenceRule,
    this.reminderTime,
    this.reminderMinutesBefore,
    this.reminderEnabled = true,
    this.skipMissedRecurrences = true,
    this.tags = const [],
    this.subtasks,
  });

  int get completedSubtasksCount =>
      subtasks?.where((s) => s.isCompleted).length ?? 0;

  int get totalSubtasksCount => subtasks?.length ?? 0;

  double get subtaskCompletionRatio {
    if (subtasks == null || subtasks!.isEmpty) return 0.0;
    return completedSubtasksCount / totalSubtasksCount;
  }

  int get subtaskCompletionPercentage =>
      (subtaskCompletionRatio * 100).round();

  bool get areAllSubtasksCompleted =>
      subtasks != null &&
      subtasks!.isNotEmpty &&
      subtasks!.every((s) => s.isCompleted);
}

@HiveType(typeId: 2)
class TaskSubtask extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  int minutes;

  @HiveField(2)
  bool isCompleted;

  TaskSubtask({
    required this.title,
    this.minutes = 0,
    this.isCompleted = false,
  });

  TaskSubtask copyWith({
    String? title,
    int? minutes,
    bool? isCompleted,
  }) {
    return TaskSubtask(
      title: title ?? this.title,
      minutes: minutes ?? this.minutes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'minutes': minutes,
        'isCompleted': isCompleted,
      };

  factory TaskSubtask.fromJson(Map<String, dynamic> json) {
    return TaskSubtask(
      title: json['title'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskSubtask &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          minutes == other.minutes &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => title.hashCode ^ minutes.hashCode ^ isCompleted.hashCode;
}