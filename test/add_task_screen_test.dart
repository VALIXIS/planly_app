import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:planly/features/tasks/models/tag_model.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/features/tasks/ui/add_task_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('planly_test_hive');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TagModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskSubtaskAdapter());
    await Hive.openBox<Task>('tasks');
    await Hive.openBox('settings');
    await Hive.openBox<TagModel>('tags');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('AddTaskScreen renders task details and Deconstruct with AI button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddTaskScreen(),
      ),
    );

    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Task Details'), findsOneWidget);
    expect(find.text('Deconstruct with AI'), findsOneWidget);
    expect(find.text('Checklist / Subtasks (0)'), findsOneWidget);
  });

  testWidgets('Tapping Deconstruct with AI with empty title shows validation message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddTaskScreen(),
      ),
    );

    final deconstructButton = find.text('Deconstruct with AI');
    expect(deconstructButton, findsOneWidget);

    await tester.tap(deconstructButton);
    await tester.pump();

    expect(find.text('Enter a task title first.'), findsOneWidget);
  });

  testWidgets('Existing task with subtasks loads subtasks into checklist', (
    WidgetTester tester,
  ) async {
    final existingTask = Task(
      title: 'Study DBMS',
      subtasks: [
        TaskSubtask(title: 'Normalization', minutes: 30, isCompleted: true),
        TaskSubtask(title: 'SQL Queries', minutes: 45, isCompleted: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddTaskScreen(task: existingTask),
      ),
    );

    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Checklist / Subtasks (2)'), findsOneWidget);
    expect(find.text('Normalization'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('SQL Queries'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
  });
}
