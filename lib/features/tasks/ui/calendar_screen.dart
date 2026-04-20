import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../services/admob_service.dart';
import '../models/task_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin<CalendarScreen> {
  DateTime selectedDay = DateTime.now();

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;

    if (!AdMobService.isSupportedPlatform) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: AdMobService.buildBannerRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() => _isBannerLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() => _isBannerLoaded = false);
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  DateTime _dayKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Map<DateTime, List<Task>> _groupTasksByDay(Iterable<Task> tasks) {
    final groupedTasks = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final dueDate = task.dueDate;
      if (dueDate == null) continue;

      final key = _dayKey(dueDate);
      groupedTasks.putIfAbsent(key, () => <Task>[]).add(task);
    }

    for (final dayTasks in groupedTasks.values) {
      dayTasks.sort((a, b) {
        final aDone = a.isCompleted ? 1 : 0;
        final bDone = b.isCompleted ? 1 : 0;
        if (aDone != bDone) return aDone.compareTo(bDone);
        return (a.dueDate ?? DateTime(2100))
            .compareTo(b.dueDate ?? DateTime(2100));
      });
    }

    return groupedTasks;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final box = Hive.box<Task>('tasks');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final calendarHeight = MediaQuery.of(context).size.height * 0.42;
    final overlayStyle = (isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<Task> taskBox, _) {
                  final tasksByDay = _groupTasksByDay(taskBox.values);
                  final selectedDayTasks =
                      tasksByDay[_dayKey(selectedDay)] ?? const <Task>[];

                  return Column(
                    children: [
                      SizedBox(
                        height: calendarHeight,
                        child: Card(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: TableCalendar<Task>(
                              firstDay: DateTime(2020),
                              lastDay: DateTime(2035),
                              focusedDay: selectedDay,
                              rowHeight: 36,
                              selectedDayPredicate: (day) =>
                                  isSameDay(day, selectedDay),
                              onDaySelected: (selected, focused) {
                                setState(() {
                                  selectedDay = DateTime(
                                    selected.year,
                                    selected.month,
                                    selected.day,
                                    focused.hour,
                                    focused.minute,
                                  );
                                });
                              },
                              eventLoader: (day) =>
                                  tasksByDay[_dayKey(day)] ?? const <Task>[],
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                                outsideDaysVisible: false,
                                defaultTextStyle: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                weekendTextStyle: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                ),
                                todayTextStyle: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                selectedTextStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                                leftChevronIcon: Icon(
                                  Icons.chevron_left,
                                  size: 18,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                                rightChevronIcon: Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                ),
                                weekendStyle: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DateFormat('EEEE, dd MMM').format(selectedDay),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _CalendarTaskList(
                          tasks: selectedDayTasks,
                          primary: primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ),
            if (AdMobService.isSupportedPlatform)
              SizedBox(
                width: AdSize.banner.width.toDouble(),
                height: AdSize.banner.height.toDouble(),
                child: _isBannerLoaded && _bannerAd != null
                    ? AdWidget(ad: _bannerAd!)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _CalendarTaskList extends StatelessWidget {
  final List<Task> tasks;
  final Color primary;

  const _CalendarTaskList({
    required this.tasks,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 44,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No tasks for this day',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Select another date or add a task',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final date = task.dueDate ?? DateTime.now();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.category ?? 'General',
                      style: TextStyle(
                        fontSize: 12,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('hh:mm a').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
