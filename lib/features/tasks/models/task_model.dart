import 'package:hive/hive.dart';

part 'task_model.g.dart';

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
  });
}