import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../focus/services/focus_stats_service.dart';
import '../../focus/ui/pomodoro_screen.dart';
import '../models/task_model.dart';
import '../services/habit_stats_service.dart';
import 'widgets/habit_heatmap_widget.dart';

/// Screen displaying productivity analytics, completion metrics, and the
/// 90-day Habit & Routine Completion Heatmap.
class StatsScreen extends StatelessWidget {
  final List<Task>? tasks;

  const StatsScreen({super.key, this.tasks});

  Widget _buildBody(BuildContext context, List<Task> taskList) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final totalTasks = taskList.length;
    final completedTasks = taskList.where((t) => t.isCompleted).length;
    final completionRate = totalTasks > 0
        ? ((completedTasks / totalTasks) * 100).round()
        : 0;

    final streak = HabitStatsService.getCurrentStreak();
    final last90DaysCount = HabitStatsService.getTotalCompletedTasksInLast90Days();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
              // ── Top Summary Grid ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Current Streak',
                      value: '$streak Days',
                      icon: Icons.local_fire_department_rounded,
                      iconColor: Colors.orange,
                      bgColor: Colors.orange.withValues(alpha: 0.12),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: '90-Day Completed',
                      value: '$last90DaysCount Tasks',
                      icon: Icons.check_circle_rounded,
                      iconColor: HabitHeatmapWidget.lightGreen,
                      bgColor: HabitHeatmapWidget.lightGreen.withValues(alpha: 0.12),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Completion Rate',
                      value: '$completionRate%',
                      icon: Icons.pie_chart_rounded,
                      iconColor: primary,
                      bgColor: primary.withValues(alpha: 0.12),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Focus Time',
                      value: '${FocusStatsService.todayFocusMinutes}m Today',
                      icon: Icons.hourglass_top_rounded,
                      iconColor: const Color(0xFF00E5FF),
                      bgColor: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 90-Day Habit & Routine Heatmap Widget ─────────────────────
              const HabitHeatmapWidget(),

              const SizedBox(height: 20),

              // ── Routine Insights & Focus Quick Launcher ───────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Consistency Milestone',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      streak > 0
                          ? "You are on a $streak-day roll! Keep completing at least one task or focus session each day to keep the gold flame shining."
                          : "Start building your streak today! Complete any pending task to ignite your habit flame on the 90-day heatmap.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PomodoroScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.timer_rounded, size: 18),
                        label: const Text('Start Deep Focus Session'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productivity & Habits'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Focus Mode',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PomodoroScreen()),
              );
            },
          ),
        ],
      ),
      body: tasks != null
          ? _buildBody(context, tasks!)
          : ValueListenableBuilder(
              valueListenable: Hive.box<Task>('tasks').listenable(),
              builder: (context, Box<Task> taskBox, _) {
                return _buildBody(context, taskBox.values.toList());
              },
            ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
