import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/tasks/models/tag_model.dart';
import '../features/tasks/models/task_model.dart';

/// Performance-optimized query index result holding partitioned task lists.
class IndexedQueryResult {
  final List<Task> allFilteredTasks;
  final List<Task> todayTasks;
  final List<Task> upcomingTasks;
  final List<Task> pendingTasks;
  final List<Task> completedTasks;
  final int todayCount;
  final int upcomingCount;
  final int pendingCount;
  final int completedCount;
  final Map<String, List<Task>> smartGroups;
  final Task? suggestedTask;

  const IndexedQueryResult({
    required this.allFilteredTasks,
    required this.todayTasks,
    required this.upcomingTasks,
    required this.pendingTasks,
    required this.completedTasks,
    required this.todayCount,
    required this.upcomingCount,
    required this.pendingCount,
    required this.completedCount,
    required this.smartGroups,
    required this.suggestedTask,
  });
}

/// Service providing parallel box initialization, automatic lifecycle box compaction,
/// and single-pass indexed task querying for 500+ task performance.
class HiveStorageService {
  HiveStorageService._();

  static AppLifecycleListener? _lifecycleListener;
  static DateTime? _lastCompactionTime;

  /// Parallelized Hive initialization for cold-start speed < 300ms.
  static Future<void> initializeStorage() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    await Hive.initFlutter();

    // Register Hive adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TagModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskSubtaskAdapter());

    // Open boxes concurrently in parallel
    final results = await Future.wait([
      Hive.openBox<Task>('tasks'),
      Hive.openBox<TagModel>('tags'),
      Hive.openBox('settings'),
    ]);

    final tagBox = results[1] as Box<TagModel>;
    if (tagBox.isEmpty) {
      await tagBox.addAll([
        TagModel(name: 'work', colorValue: 0xFF42A5F5),
        TagModel(name: 'personal', colorValue: 0xFF66BB6A),
        TagModel(name: 'urgent', colorValue: 0xFFEF5350),
      ]);
    }

    stopwatch.stop();
    debugPrint('⚡ Hive storage initialized in ${stopwatch.elapsedMilliseconds}ms');

    _setupLifecycleCompaction();
  }

  static bool _isCompacting = false;

  /// Compacts all open Hive boxes concurrently to recover disk space and optimize I/O.
  static Future<void> compactAllBoxes() async {
    if (_isCompacting) return;
    _isCompacting = true;

    try {
      final List<Future<void>> compactionFutures = [];

      if (Hive.isBoxOpen('tasks')) {
        compactionFutures.add(Hive.box<Task>('tasks').compact());
      }
      if (Hive.isBoxOpen('tags')) {
        compactionFutures.add(Hive.box<TagModel>('tags').compact());
      }
      if (Hive.isBoxOpen('settings')) {
        compactionFutures.add(Hive.box('settings').compact());
      }

      if (compactionFutures.isNotEmpty) {
        final Stopwatch sw = Stopwatch()..start();
        await Future.wait(compactionFutures);
        _lastCompactionTime = DateTime.now();
        sw.stop();
        debugPrint('🧹 Compacted all Hive boxes in ${sw.elapsedMilliseconds}ms');
      }
    } catch (e) {
      debugPrint('Compaction error: $e');
    } finally {
      _isCompacting = false;
    }
  }

  static DateTime? get lastCompactionTime => _lastCompactionTime;

  /// Sets up automatic box compaction when the app is paused or hidden.
  static void _setupLifecycleCompaction() {
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => compactAllBoxes(),
      onHide: () => compactAllBoxes(),
      onDetach: () => compactAllBoxes(),
    );
  }

  /// Single-pass indexed task partitioning & query engine ($O(N)$ complexity).
  ///
  /// Processes 500+ tasks in a single pass to build counts, filter states,
  /// and smart groups without multiple redundant iterations.
  static IndexedQueryResult queryAndIndexTasks({
    required List<Task> allTasks,
    required String searchQuery,
    required String selectedFilterName,
    required List<String> categories,
    required DateTime now,
  }) {
    final String query = searchQuery.trim().toLowerCase();

    int todayCount = 0;
    int upcomingCount = 0;
    int pendingCount = 0;
    int completedCount = 0;

    final List<Task> todayTasks = [];
    final List<Task> upcomingTasks = [];
    final List<Task> pendingTasks = [];
    final List<Task> completedTasks = [];
    final List<Task> filteredTasks = [];

    final Map<String, List<Task>> groups = {
      "Overdue": [],
      "Now": [],
      "Later Today": [],
      "Tomorrow": [],
      "This Week": [],
      "Later": [],
      "Anytime": [],
    };

    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);
    final DateTime dayAfterTomorrow = DateTime(now.year, now.month, now.day + 2);
    final DateTime nextWeek = now.add(const Duration(days: 7));
    final DateTime threeHoursLater = now.add(const Duration(hours: 3));

    // Single pass indexing
    for (int i = 0; i < allTasks.length; i++) {
      final Task task = allTasks[i];
      final DateTime? due = task.dueDate;
      final bool isToday = due != null &&
          due.year == now.year &&
          due.month == now.month &&
          due.day == now.day;

      if (isToday) {
        todayCount++;
        todayTasks.add(task);
      }

      if (due != null && due.isAfter(now)) {
        upcomingCount++;
        upcomingTasks.add(task);
      }

      if (task.isCompleted) {
        completedCount++;
        completedTasks.add(task);
      } else {
        pendingCount++;
        pendingTasks.add(task);
      }

      final bool matchesSearch =
          query.isEmpty || task.title.toLowerCase().contains(query);

      if (!matchesSearch) continue;

      final bool includeTask = switch (selectedFilterName) {
        'all' => true,
        'today' => isToday,
        'upcoming' => due != null && due.isAfter(now),
        'pending' => !task.isCompleted,
        'completed' => task.isCompleted,
        _ => true,
      };

      if (!includeTask) continue;
      filteredTasks.add(task);

      // Smart grouping during single pass
      if (selectedFilterName == 'all' || selectedFilterName == 'today') {
        if (due == null) {
          groups["Anytime"]!.add(task);
        } else if (due.isBefore(now) && !task.isCompleted) {
          groups["Overdue"]!.add(task);
        } else if (!due.isBefore(now) &&
            due.isBefore(threeHoursLater) &&
            due.year == now.year &&
            due.month == now.month &&
            due.day == now.day) {
          groups["Now"]!.add(task);
        } else if (due.year == now.year &&
            due.month == now.month &&
            due.day == now.day) {
          groups["Later Today"]!.add(task);
        } else if (due.isAfter(tomorrow.subtract(const Duration(seconds: 1))) &&
            due.isBefore(dayAfterTomorrow)) {
          groups["Tomorrow"]!.add(task);
        } else if (due.isAfter(dayAfterTomorrow) && due.isBefore(nextWeek)) {
          groups["This Week"]!.add(task);
        } else if (due.isAfter(nextWeek)) {
          groups["Later"]!.add(task);
        } else {
          groups["Anytime"]!.add(task);
        }
      }
    }

    // Sort priority helper
    int priorityVal(String p) => switch (p) {
          "High" => 0,
          "Low" => 2,
          _ => 1,
        };

    void sortGroup(List<Task> group) {
      group.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return priorityVal(a.priority).compareTo(priorityVal(b.priority));
      });
    }

    Map<String, List<Task>> displayGroups = {};
    final bool useSmartFlow =
        selectedFilterName == 'all' || selectedFilterName == 'today';

    if (useSmartFlow) {
      displayGroups = groups;
      for (final g in displayGroups.values) {
        if (g.isNotEmpty) sortGroup(g);
      }
    } else {
      for (int i = 0; i < categories.length; i++) {
        final String cat = categories[i];
        final List<Task> catTasks =
            filteredTasks.where((t) => t.category == cat).toList();
        if (catTasks.isNotEmpty) {
          sortGroup(catTasks);
          displayGroups[cat] = catTasks;
        }
      }
      final List<Task> uncategorized = filteredTasks
          .where((t) => t.category == null || !categories.contains(t.category))
          .toList();
      if (uncategorized.isNotEmpty) {
        sortGroup(uncategorized);
        displayGroups["Others"] =
            (displayGroups["Others"] ?? []) + uncategorized;
      }
    }

    // Determine smart suggested task
    Task? suggestedTask;
    if (pendingTasks.isNotEmpty) {
      final sortedPending = List<Task>.from(pendingTasks);
      sortedPending.sort((a, b) {
        final aDue = a.dueDate;
        final bDue = b.dueDate;
        if (aDue != null && bDue != null) {
          final dueCmp = aDue.compareTo(bDue);
          if (dueCmp != 0) return dueCmp;
        } else if (aDue != null) {
          return -1;
        } else if (bDue != null) {
          return 1;
        }
        return priorityVal(a.priority).compareTo(priorityVal(b.priority));
      });
      suggestedTask = sortedPending.first;
    }

    return IndexedQueryResult(
      allFilteredTasks: filteredTasks,
      todayTasks: todayTasks,
      upcomingTasks: upcomingTasks,
      pendingTasks: pendingTasks,
      completedTasks: completedTasks,
      todayCount: todayCount,
      upcomingCount: upcomingCount,
      pendingCount: pendingCount,
      completedCount: completedCount,
      smartGroups: displayGroups,
      suggestedTask: suggestedTask,
    );
  }
}
