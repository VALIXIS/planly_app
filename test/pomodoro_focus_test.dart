import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:planly/features/focus/services/ambient_audio_service.dart';
import 'package:planly/features/focus/services/focus_stats_service.dart';
import 'package:planly/features/focus/ui/pomodoro_screen.dart';
import 'package:planly/features/tasks/models/task_model.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock audioplayers platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        return 1;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async {
        return 1;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );

    tempDir = await Directory.systemTemp.createTemp('planly_test_pomodoro');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskSubtaskAdapter());
    await Hive.openBox('settings');
    await Hive.openBox<Task>('tasks');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FocusStatsService tests', () {
    setUp(() async {
      final box = Hive.box('settings');
      await box.clear();
    });

    test('initial stats are zero', () {
      expect(FocusStatsService.todayFocusMinutes, 0);
      expect(FocusStatsService.todayCompletedSessions, 0);
      expect(FocusStatsService.totalFocusMinutes, 0);
      expect(FocusStatsService.totalSessions, 0);
      expect(FocusStatsService.dailyStreak, 0);
    });

    test('recordCompletedSession increments daily and total stats', () async {
      await FocusStatsService.recordCompletedSession(minutes: 25);

      expect(FocusStatsService.todayFocusMinutes, 25);
      expect(FocusStatsService.todayCompletedSessions, 1);
      expect(FocusStatsService.totalFocusMinutes, 25);
      expect(FocusStatsService.totalSessions, 1);
      expect(FocusStatsService.dailyStreak, 1);

      await FocusStatsService.recordCompletedSession(minutes: 25);
      expect(FocusStatsService.todayFocusMinutes, 50);
      expect(FocusStatsService.todayCompletedSessions, 2);
      expect(FocusStatsService.totalFocusMinutes, 50);
      expect(FocusStatsService.totalSessions, 2);
      expect(FocusStatsService.dailyStreak, 1); // same day, streak stays 1
    });

    test('getRecentWeeklyHistory returns 7 days of data', () {
      final history = FocusStatsService.getRecentWeeklyHistory();
      expect(history.length, 7);
    });
  });

  group('AmbientAudioService tests', () {
    test('sound enum contains all 4 ambient loops plus none', () {
      expect(AmbientSound.values.length, 5);
      expect(AmbientSound.rain.label, 'Rain');
      expect(AmbientSound.cozyCafe.label, 'Cozy Cafe');
      expect(AmbientSound.whiteNoise.label, 'White Noise');
      expect(AmbientSound.deepSpaceLoFi.label, 'Deep Space Lo-Fi');
      expect(AmbientSound.none.label, 'None');
    });

    test('volume clamping works correctly', () async {
      final service = AmbientAudioService();
      await service.setVolume(0.8);
      expect(service.volume, 0.8);

      await service.setVolume(1.5);
      expect(service.volume, 1.0);

      await service.setVolume(-0.5);
      expect(service.volume, 0.0);
    });
  });

  group('PomodoroScreen Widget tests', () {
    testWidgets('PomodoroScreen renders core controls and initial 25m countdown',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PomodoroScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pomodoro Focus'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('DEEP FOCUS'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Short'), findsOneWidget);
      expect(find.text('Long'), findsOneWidget);
      expect(find.text('Ambient Audio & Focus Loops'), findsOneWidget);
    });

    testWidgets('Switching modes updates countdown duration and state label',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PomodoroScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Short Break
      await tester.tap(find.text('Short'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('SHORT BREAK'), findsOneWidget);

      // Tap Long Break
      await tester.tap(find.text('Long'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('LONG BREAK'), findsOneWidget);
    });

    testWidgets('Play / Pause button toggles countdown timer state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PomodoroScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Initially Play icon is visible
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap Play
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(seconds: 1));

      // Now Pause icon is visible
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('24:59'), findsOneWidget);

      // Tap Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });
}
