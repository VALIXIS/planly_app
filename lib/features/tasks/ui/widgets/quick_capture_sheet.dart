import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../services/natural_language_parser.dart';
import '../../../../services/notification_service.dart';
import '../../models/task_model.dart';
import '../add_task_screen.dart';

class QuickCaptureSheet extends StatefulWidget {
  final Task? initialTask;

  const QuickCaptureSheet({super.key, this.initialTask});

  static Future<void> show(BuildContext context, {Task? initialTask}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickCaptureSheet(initialTask: initialTask),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ParsedTaskResult _parsedResult = const ParsedTaskResult(title: '');
  String _selectedPriority = 'Medium';
  String _selectedCategory = 'Personal';
  bool _isSaving = false;

  final List<String> _categories = ['Personal', 'Work', 'Shopping', 'Others'];
  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      _inputController.text = widget.initialTask!.title;
      _selectedPriority = widget.initialTask!.priority;
      _selectedCategory = widget.initialTask!.category ?? 'Personal';
    }

    _inputController.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _inputController.text;
    setState(() {
      _parsedResult = NaturalLanguageParser.parse(text);
    });
  }

  Future<void> _saveTask() async {
    final rawText = _inputController.text.trim();
    if (rawText.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _parsedResult.title.isNotEmpty ? _parsedResult.title : rawText;
      final dueDate = _parsedResult.dueDate;

      // Extract inline #hashtags if present
      final tagMatches = RegExp(r'#(\w+)').allMatches(rawText);
      final inlineTags = tagMatches.map((m) => m.group(1)!).toList();

      final newTask = Task(
        title: title,
        category: _selectedCategory,
        dueDate: dueDate,
        isCompleted: false,
        priority: _selectedPriority,
        tags: inlineTags,
        reminderEnabled: dueDate != null,
        reminderTime: dueDate,
      );

      final box = await Hive.openBox<Task>('tasks');
      final key = await box.add(newTask);

      if (dueDate != null && dueDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: key,
          title: title,
          body: 'Task due now',
          scheduledTime: dueDate,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$title" captured!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openFullForm() {
    final title = _parsedResult.title.isNotEmpty ? _parsedResult.title : _inputController.text.trim();
    final dueDate = _parsedResult.dueDate;

    final tempTask = Task(
      title: title,
      category: _selectedCategory,
      dueDate: dueDate,
      priority: _selectedPriority,
    );

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(task: tempTask),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.flash_on_rounded,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quick Capture',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _openFullForm,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('More options'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Single Input Field
              TextField(
                controller: _inputController,
                focusNode: _focusNode,
                autofocus: true,
                maxLines: 2,
                minLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., Dentist tomorrow at 3pm #urgent',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A3D) : const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _inputController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel, size: 20),
                          onPressed: () {
                            _inputController.clear();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _saveTask(),
              ),

              const SizedBox(height: 14),

              // Real-time parsed details / Auto-highlight card
              if (_inputController.text.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26273B) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Parsed Task Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title preview
                      Row(
                        children: [
                          Text(
                            'Title: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _parsedResult.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      if (_parsedResult.dueDate != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatParsedDate(_parsedResult.dueDate!, _parsedResult.hasTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Display matched token badges
                            ..._parsedResult.matchedTokens.map(
                              (token) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.primaryColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  token,
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Priority & Category Pickers Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                            selectedColor: theme.primaryColor.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? theme.primaryColor
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12.5,
                            ),
                            backgroundColor: isDark ? const Color(0xFF2A2A3D) : const Color(0xFFF3F4F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? theme.primaryColor : Colors.transparent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Priority chips
                  Row(
                    children: [
                      Text(
                        'Priority: ',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ..._priorities.map((prio) {
                        final isSelected = _selectedPriority == prio;
                        final color = _getPriorityColor(prio);

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPriority = prio;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                prio,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Save Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Task',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatParsedDate(DateTime dt, bool hasTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dt.year, dt.month, dt.day);

    String dateStr;
    if (targetDate == today) {
      dateStr = 'Today';
    } else if (targetDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = DateFormat('MMM d').format(dt);
    }

    if (hasTime) {
      final timeStr = DateFormat('h:mm a').format(dt);
      return '$dateStr at $timeStr';
    }
    return dateStr;
  }

  Color _getPriorityColor(String prio) {
    switch (prio) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
