import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TextEditingController _controller = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedCategory = "Personal";

  final List<String> categories = [
    "Work",
    "Personal",
    "Shopping",
    "Others",
  ];

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

  void saveTask() {
    String title = _controller.text.trim();

    if (title.isEmpty) return;

    Navigator.pop(context, {
      "title": title,
      "category": selectedCategory,
      "date": selectedDate.toIso8601String(),
      "isDone": false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF), // 💜 soft bg

      appBar: AppBar(
        title: const Text("Add Task"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📝 Task Title (soft input)
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Task Title",
                filled: true,
                fillColor: const Color(0xFFF8F6FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 📅 Date Picker (soft button)
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB39DDB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: pickDate,
                  child: const Text("Pick Date"),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd-MM-yyyy').format(selectedDate),
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🏷 Category Dropdown (soft box)
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
                labelText: "Category",
                filled: true,
                fillColor: const Color(0xFFF8F6FF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 💾 Save Button (soft full width)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9575CD),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: saveTask,
                child: const Text("Save Task"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}