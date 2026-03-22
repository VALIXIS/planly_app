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
  String priority; // ✅ NEW

  Task({
    required this.title,
    this.category,
    this.dueDate,
    this.isCompleted = false,
    this.description,
    this.priority = "Medium", // ✅ DEFAULT
  });
}