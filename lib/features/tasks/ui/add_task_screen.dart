import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../../../services/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  bool enableReminder = true;

  String selectedCategory = "Personal";
  String selectedPriority = "Medium";

  final List<String> categories = ["Work", "Personal", "Shopping", "Others"];
  final List<String> priorities = ["High", "Medium", "Low"];

  @override
  void initState() {
    super.initState();

    if (widget.task != null) {
      final task = widget.task!;
      _controller.text = task.title;
      selectedCategory = task.category ?? "Personal";
      _descController.text = task.description ?? "";
      selectedPriority = task.priority;

      if (task.dueDate != null) {
        selectedDate = task.dueDate!;
        selectedTime = TimeOfDay.fromDateTime(task.dueDate!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    super.dispose();
  }

  void pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  DateTime get combinedDateTime => DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

  void saveTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final notifService = NotificationService();
    final box = Hive.box<Task>('tasks');

    if (widget.task != null) {
      final task = widget.task!;

      await notifService.cancelNotification(task.key as int);

      task.title = title;
      task.category = selectedCategory;
      task.dueDate = combinedDateTime;
      task.description = _descController.text.trim();
      task.priority = selectedPriority;
      await task.save();

      if (enableReminder) {
        await notifService.scheduleNotification(
          id: task.key as int,
          title: task.title,
          body: task.description?.isNotEmpty == true
              ? task.description!
              : 'Your task is due now!',
          scheduledTime: combinedDateTime,
        );
      }

      if (mounted) Navigator.pop(context);
    } else {
      final newTask = Task(
        title: title,
        category: selectedCategory,
        dueDate: combinedDateTime,
        isCompleted: false,
        description: _descController.text.trim(),
        priority: selectedPriority,
      );

      final key = await box.add(newTask);

      if (enableReminder) {
        await notifService.scheduleNotification(
          id: key,
          title: title,
          body: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : 'Your task is due now!',
          scheduledTime: combinedDateTime,
        );
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final colorScheme = Theme.of(context).colorScheme;

    final fieldFill = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : Colors.white;

    InputDecoration fieldDecoration({String? hint, Widget? prefix}) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? "Edit Task" : "Add Task"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Task Details",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              TextField(
                controller: _controller,
                decoration:
                    fieldDecoration(hint: "Enter task title..."),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: fieldDecoration(
                    hint: "Add description (optional)..."),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.calendar_today,
                      label:
                          DateFormat('dd MMM yyyy').format(selectedDate),
                      onTap: pickDate,
                      fillColor: fieldFill,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.access_time,
                      label: selectedTime.format(context),
                      onTap: pickTime,
                      fillColor: fieldFill,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: fieldFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_outlined, size: 18),
                        SizedBox(width: 10),
                        Text("Remind me",
                            style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    Switch(
                      value: enableReminder,
                      activeColor: colorScheme.primary,
                      onChanged: (val) =>
                          setState(() => enableReminder = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text("Category",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: fieldDecoration(hint: "Category"),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text("Priority",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),

              DropdownButtonFormField<String>(
                value: selectedPriority,
                decoration: fieldDecoration(hint: "Priority"),
                items: priorities.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => selectedPriority = val!),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isEditing ? "Update Task" : "Save Task",
                    style:
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color fillColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}