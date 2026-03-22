import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task; // ✅ NEW

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _controller = TextEditingController();
  DateTime selectedDate = DateTime.now();

  TimeOfDay selectedTime = TimeOfDay.now();

  String selectedCategory = "Personal";

  final List<String> categories = [
    "Work",
    "Personal",
    "Shopping",
    "Others",
  ];

  @override
  void initState() {
    super.initState();

    // ✅ PREFILL WHEN EDITING
    if (widget.task != null) {
      final task = widget.task!;
      _controller.text = task.title;
      selectedCategory = task.category ?? "Personal";

      if (task.dueDate != null) {
        selectedDate = task.dueDate!;
        selectedTime = TimeOfDay.fromDateTime(task.dueDate!);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void saveTask() {
    String title = _controller.text.trim();
    if (title.isEmpty) return;

    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (widget.task != null) {
      // ✅ EDIT MODE
      final task = widget.task!;
      task.title = title;
      task.category = selectedCategory;
      task.dueDate = combinedDateTime;
      task.save();

      Navigator.pop(context);
    } else {
      // ✅ ADD MODE
      final newTask = Task(
        title: title,
        category: selectedCategory,
        dueDate: combinedDateTime,
        isCompleted: false,
      );

      Navigator.pop(context, newTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(isEditing ? "Edit Task" : "Add Task"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Task Details",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // ✏️ Title
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "Enter task title...",
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 📅 Date
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    ],
                  ),
                  TextButton(
                    onPressed: pickDate,
                    child: const Text("Change"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ⏰ Time
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(selectedTime.format(context)),
                    ],
                  ),
                  TextButton(
                    onPressed: pickTime,
                    child: const Text("Change"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🏷 Category
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedCategory = val!;
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const Spacer(),

            // 🚀 Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveTask,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? "Update Task" : "Save Task",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}