import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/habit_stats_service.dart';

/// 90-Day Task Completion Habit & Routine Heatmap Widget.
/// Renders a 7x13 calendar grid representing the last 90 days with
/// color intensity gradient (Light green -> Dark green -> Gold),
/// interactive tooltips with completed task titles on tap, and
/// a prominent fire streak badge at the top.
class HabitHeatmapWidget extends StatefulWidget {
  /// Optional mock/custom completion data: Date -> List of completed task titles.
  /// If null, reads dynamically from [HabitStatsService].
  final Map<DateTime, List<String>>? completionData;

  /// Optional override for the current streak count.
  /// If null, computed from [HabitStatsService.getCurrentStreak()].
  final int? currentStreak;

  /// Optional callback when the streak badge is tapped.
  final VoidCallback? onStreakTap;

  const HabitHeatmapWidget({
    super.key,
    this.completionData,
    this.currentStreak,
    this.onStreakTap,
  });

  /// Color palette constants for cube intensity tiers
  static const Color lightGreen = Color(0xFF81C784);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldBorder = Color(0xFFFFA000);

  /// Returns the color intensity for a cube based on completed task count.
  /// Tier 0 (0 tasks): Empty charcoal / gray
  /// Tier 1 (1 task): Light green
  /// Tier 2 (2-3 tasks): Dark green
  /// Tier 3 (4+ tasks): Radiant Gold
  static Color getCubeColor(int count, {required bool isDark}) {
    if (count <= 0) {
      return isDark ? const Color(0xFF222222) : const Color(0xFFE5E7EB);
    } else if (count == 1) {
      return lightGreen;
    } else if (count <= 3) {
      return darkGreen;
    } else {
      return gold;
    }
  }

  @override
  State<HabitHeatmapWidget> createState() => _HabitHeatmapWidgetState();
}

class _HabitHeatmapWidgetState extends State<HabitHeatmapWidget> {
  DateTime? _selectedDate;
  List<String> _selectedTasks = const [];

  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Load completion data and current streak
    final data = widget.completionData ?? HabitStatsService.getCompletionData(days: 90);
    final streak = widget.currentStreak ?? HabitStatsService.getCurrentStreak();

    final today = _normalize(DateTime.now());
    // 91 days total (13 weeks x 7 days) ending on today's week
    // We align the grid so columns are 13 weeks, ending today
    final daysToSubtract = 90;
    final startDate = today.subtract(Duration(days: daysToSubtract));

    // Organize into 13 columns of 7 days (7 rows)
    final gridDays = <List<DateTime>>[];
    for (var col = 0; col < 13; col++) {
      final columnDays = <DateTime>[];
      for (var row = 0; row < 7; row++) {
        final dayOffset = (col * 7) + row;
        final day = startDate.add(Duration(days: dayOffset));
        columnDays.add(_normalize(day));
      }
      gridDays.add(columnDays);
    }

    final totalCompleted = data.values.fold<int>(0, (sum, list) => sum + list.length);
    final activeDays = data.values.where((list) => list.isNotEmpty).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Row with Streak Fire Badge ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '90-Day Habit Heatmap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$totalCompleted completed • $activeDays active days',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔥 Current Streak Fire Badge at Top
              GestureDetector(
                onTap: widget.onStreakTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: streak > 0
                          ? [
                              const Color(0xFFFF5722),
                              const Color(0xFFFF9800),
                            ]
                          : [
                              isDark ? const Color(0xFF333333) : Colors.grey.shade400,
                              isDark ? const Color(0xFF222222) : Colors.grey.shade300,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: streak > 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak Day Streak',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── 7x13 Calendar Grid ────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels along top of grid
                    _buildMonthHeaders(gridDays, isDark),
                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weekday labels (Mon, Wed, Fri)
                        _buildWeekdayLabels(isDark),
                        const SizedBox(width: 6),

                        // The 7x13 heatmap cubes
                        Row(
                          children: List.generate(gridDays.length, (colIdx) {
                            final column = gridDays[colIdx];
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Column(
                                children: List.generate(column.length, (rowIdx) {
                                  final date = column[rowIdx];
                                  final isFuture = date.isAfter(today);
                                  final tasks = data[date] ?? const <String>[];
                                  final count = isFuture ? 0 : tasks.length;
                                  final isSelected = _selectedDate != null &&
                                      _selectedDate == date;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _buildHeatmapCube(
                                      date: date,
                                      count: count,
                                      tasks: tasks,
                                      isFuture: isFuture,
                                      isSelected: isSelected,
                                      isDark: isDark,
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ── Intensity Legend (Light Green -> Dark Green -> Gold) ───────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
              const SizedBox(width: 6),
              _buildLegendCube(HabitHeatmapWidget.getCubeColor(0, isDark: isDark)),
              const SizedBox(width: 3),
              _buildLegendCube(HabitHeatmapWidget.lightGreen),
              const SizedBox(width: 3),
              _buildLegendCube(HabitHeatmapWidget.darkGreen),
              const SizedBox(width: 3),
              _buildLegendCube(HabitHeatmapWidget.gold),
              const SizedBox(width: 6),
              Text(
                'More (Gold 🔥)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),

          // ── Selected Cube Details Card (Interactive Tooltip Details) ──
          if (_selectedDate != null) ...[
            const SizedBox(height: 14),
            _buildSelectedDateDetails(isDark, theme.colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildHeatmapCube({
    required DateTime date,
    required int count,
    required List<String> tasks,
    required bool isFuture,
    required bool isSelected,
    required bool isDark,
  }) {
    final color = isFuture
        ? Colors.transparent
        : HabitHeatmapWidget.getCubeColor(count, isDark: isDark);

    final dateFormatted = DateFormat('EEE, MMM d, yyyy').format(date);
    final tooltipText = isFuture
        ? '$dateFormatted (Upcoming)'
        : count == 0
            ? '$dateFormatted: No tasks completed'
            : '$dateFormatted: $count completed\n${tasks.map((t) => '• $t').join('\n')}';

    return Tooltip(
      message: tooltipText,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
      child: GestureDetector(
        onTap: isFuture
            ? null
            : () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedDate = date;
                  _selectedTasks = List<String>.from(tasks);
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: isSelected
                ? Border.all(
                    color: Colors.white,
                    width: 2,
                  )
                : count >= 4
                    ? Border.all(
                        color: HabitHeatmapWidget.goldBorder,
                        width: 1.2,
                      )
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        width: 0.8,
                      ),
            boxShadow: count >= 4
                ? [
                    BoxShadow(
                      color: HabitHeatmapWidget.gold.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeaders(List<List<DateTime>> gridDays, bool isDark) {
    return Row(
      children: [
        const SizedBox(width: 20), // weekday label offset
        Row(
          children: List.generate(gridDays.length, (colIdx) {
            final firstDay = gridDays[colIdx].first;
            final isFirstWeekOfMonth = firstDay.day <= 7 || colIdx == 0;
            final monthStr = DateFormat('MMM').format(firstDay);

            return SizedBox(
              width: 21,
              child: isFirstWeekOfMonth
                  ? Text(
                      monthStr,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                      overflow: TextOverflow.visible,
                    )
                  : const SizedBox.shrink(),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(bool isDark) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: List.generate(7, (idx) {
        final show = idx == 0 || idx == 2 || idx == 4; // Mon, Wed, Fri
        return Container(
          height: 17,
          margin: const EdgeInsets.only(bottom: 4),
          alignment: Alignment.centerLeft,
          child: Text(
            show ? labels[idx] : '',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLegendCube(Color color) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildSelectedDateDetails(bool isDark, Color primary) {
    final date = _selectedDate!;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final count = _selectedTasks.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: count >= 4
              ? HabitHeatmapWidget.gold.withValues(alpha: 0.5)
              : count > 0
                  ? HabitHeatmapWidget.darkGreen.withValues(alpha: 0.4)
                  : (isDark ? Colors.white10 : Colors.black12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: count >= 4
                      ? HabitHeatmapWidget.gold.withValues(alpha: 0.2)
                      : count > 0
                          ? HabitHeatmapWidget.darkGreen.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count == 0 ? 'No tasks' : '$count completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: count >= 4
                        ? HabitHeatmapWidget.gold
                        : count > 0
                            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
                            : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 8),
            ..._selectedTasks.map(
              (title) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF81C784),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
