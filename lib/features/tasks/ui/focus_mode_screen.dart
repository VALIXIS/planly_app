import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/task_action_service.dart';
import '../models/task_model.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, int> _priorityOrder = {
    'High': 0,
    'Medium': 1,
    'Low': 2,
  };

  int currentIndex = 0;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Task> _getTodayTasks(Box<Task> box) {
    final today = DateTime.now();
    final todayTasks = box.values.where((task) {
      return !task.isCompleted &&
          task.dueDate != null &&
          _isSameDay(task.dueDate!, today);
    }).toList();

    todayTasks.sort((a, b) {
      final priorityCompare = (_priorityOrder[a.priority] ?? 1).compareTo(
        _priorityOrder[b.priority] ?? 1,
      );
      if (priorityCompare != 0) return priorityCompare;
      return (a.dueDate ?? DateTime(2100)).compareTo(
        b.dueDate ?? DateTime(2100),
      );
    });

    return todayTasks;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFE57373);
      case 'Low':
        return const Color(0xFF64B5F6);
      default:
        return const Color(0xFFFFB74D);
    }
  }

  void _animateToNext() {
    _animController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Focus Mode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Task>('tasks').listenable(),
        builder: (context, Box<Task> box, _) {
          final tasks = _getTodayTasks(box);

          if (tasks.isEmpty) {
            return _EmptyFocusState(primary: primary);
          }

          if (currentIndex >= tasks.length) {
            currentIndex = tasks.length - 1;
          }

          final task = tasks[currentIndex];
          final priorityColor = _getPriorityColor(task.priority);
          final date = task.dueDate;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentIndex + 1} of ${tasks.length} tasks',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (currentIndex + 1) / tasks.length,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      color: primary,
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: priorityColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${task.priority} Priority',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    if (task.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white54 : Colors.black45,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (date != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM - hh:mm a').format(date),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (task.category?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.category!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await TaskActionService.setTaskCompletion(task, true);
                          if (mounted) {
                            setState(_animateToNext);
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'Mark as Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: tasks.length <= 1
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      currentIndex =
                                          (currentIndex + 1) % tasks.length;
                                      _animateToNext();
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Exit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFocusState extends StatelessWidget {
  final Color primary;

  const _EmptyFocusState({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 72,
            color: primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'All done for today!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No more tasks remaining.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Back to Tasks'),
          ),
        ],
      ),
    );
  }
}
