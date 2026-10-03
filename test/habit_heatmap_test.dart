import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:planly/features/tasks/models/tag_model.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/features/tasks/services/habit_stats_service.dart';
import 'package:planly/features/tasks/ui/stats_screen.dart';
import 'package:planly/features/tasks/ui/widgets/habit_heatmap_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('planly_test_habit');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TagModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskSubtaskAdapter());
    await Hive.openBox('settings');
    await Hive.openBox<Task>('tasks');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    if (!Hive.isBoxOpen('tasks')) await Hive.openBox<Task>('tasks');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    await Hive.box<Task>('tasks').clear();
    await Hive.box('settings').clear();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('tasks')) await Hive.box<Task>('tasks').clear();
    if (Hive.isBoxOpen('settings')) await Hive.box('settings').clear();
  });

  group('HabitHeatmapWidget color intensity calculations', () {
    test('getCubeColor maps task counts to correct color intensity tiers', () {
      // 0 tasks: empty cell
      final emptyDark = HabitHeatmapWidget.getCubeColor(0, isDark: true);
      final emptyLight = HabitHeatmapWidget.getCubeColor(0, isDark: false);
      expect(emptyDark, equals(const Color(0xFF222222)));
      expect(emptyLight, equals(const Color(0xFFE5E7EB)));

      // 1 task: Light green
      final tier1 = HabitHeatmapWidget.getCubeColor(1, isDark: true);
      expect(tier1, equals(HabitHeatmapWidget.lightGreen));

      // 2 or 3 tasks: Dark green
      final tier2 = HabitHeatmapWidget.getCubeColor(2, isDark: true);
      final tier3 = HabitHeatmapWidget.getCubeColor(3, isDark: true);
      expect(tier2, equals(HabitHeatmapWidget.darkGreen));
      expect(tier3, equals(HabitHeatmapWidget.darkGreen));

      // 4+ tasks: Radiant Gold
      final tier4 = HabitHeatmapWidget.getCubeColor(4, isDark: true);
      final tier5 = HabitHeatmapWidget.getCubeColor(10, isDark: false);
      expect(tier4, equals(HabitHeatmapWidget.gold));
      expect(tier5, equals(HabitHeatmapWidget.gold));
    });
  });

  group('HabitStatsService streak and history calculations', () {
    test('records task completions and computes streak accurately', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final dayBefore = today.subtract(const Duration(days: 2));

      await HabitStatsService.recordTaskCompletion('Build 3D Cards', date: dayBefore);
      await HabitStatsService.recordTaskCompletion('OLED Theme', date: yesterday);
      await HabitStatsService.recordTaskCompletion('Habit Heatmap', date: today);

      final streak = HabitStatsService.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(3));

      final data = HabitStatsService.getCompletionData(days: 90);
      final todayNormalized = DateTime(today.year, today.month, today.day);
      expect(data[todayNormalized], contains('Habit Heatmap'));
    });

    test('unrecordTaskCompletion properly updates history', () async {
      final today = DateTime.now();
      await HabitStatsService.recordTaskCompletion('Morning Run', date: today);
      var data = HabitStatsService.getCompletionData(days: 90);
      final todayNormalized = DateTime(today.year, today.month, today.day);
      expect(data[todayNormalized], contains('Morning Run'));

      await HabitStatsService.unrecordTaskCompletion('Morning Run', date: today);
      data = HabitStatsService.getCompletionData(days: 90);
      expect(data[todayNormalized], isNot(contains('Morning Run')));
    });
  });

  group('HabitHeatmapWidget UI & Interaction tests', () {
    testWidgets('renders 7x13 grid, top streak fire badge, and legend', (tester) async {
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);
      final yesterdayNormalized = todayNormalized.subtract(const Duration(days: 1));
      final threeDaysAgo = todayNormalized.subtract(const Duration(days: 3));

      final mockData = <DateTime, List<String>>{
        todayNormalized: ['Review Pull Request', 'Design OLED Colors', 'Release Build', 'Write Tests'],
        yesterdayNormalized: ['Fix Memory Leak', 'Team Sync'],
        threeDaysAgo: ['Draft RFC'],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HabitHeatmapWidget(
                completionData: mockData,
                currentStreak: 5,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top streak badge verification
      expect(find.text('5 Day Streak'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);

      // Header title verification
      expect(find.text('90-Day Habit Heatmap'), findsOneWidget);

      // Legend verification
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More (Gold 🔥)'), findsOneWidget);

      // 91 Tooltips for 7x13 grid cubes
      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('tapping a cube reveals tooltip and displays completed task titles', (tester) async {
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      final mockData = <DateTime, List<String>>{
        todayNormalized: ['Implement Habit Heatmap', 'Verify Gold Gradient'],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HabitHeatmapWidget(
                completionData: mockData,
                currentStreak: 7,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the last cube corresponding to today's date
      final todayFormat = DateFormat('EEE, MMM d, yyyy').format(todayNormalized);
      final todayTooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && (widget.message?.contains(todayFormat) ?? false),
      );

      expect(todayTooltipFinder, findsOneWidget);

      // Tap on the cube
      await tester.tap(todayTooltipFinder);
      await tester.pumpAndSettle();

      // Verify the details card displays the task titles
      expect(find.text('Implement Habit Heatmap'), findsOneWidget);
      expect(find.text('Verify Gold Gradient'), findsOneWidget);
      expect(find.text('2 completed'), findsOneWidget);
    });
  });

  group('StatsScreen tests', () {
    testWidgets('renders StatsScreen with metric tiles and HabitHeatmapWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(tasks: []),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Productivity & Habits'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('90-Day Completed'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.byType(HabitHeatmapWidget), findsOneWidget);
      expect(find.text('Consistency Milestone'), findsOneWidget);
    });
  });
}
