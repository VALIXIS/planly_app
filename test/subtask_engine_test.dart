import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/features/tasks/ui/widgets/subtask_list_widget.dart';
import 'package:planly/features/tasks/ui/widgets/task_card_3d.dart';

void main() {
  group('Subtask Engine & Progress Calculations', () {
    test('Task model subtask completion ratio and percentage calculations', () {
      final task = Task(
        title: 'Complete Project',
        subtasks: [
          SubTask(title: 'Setup Environment', isCompleted: true),
          SubTask(title: 'Build UI', isCompleted: true),
          SubTask(title: 'Run Tests', isCompleted: false),
          SubTask(title: 'Deploy', isCompleted: false),
        ],
      );

      expect(task.totalSubtasksCount, equals(4));
      expect(task.completedSubtasksCount, equals(2));
      expect(task.subtaskCompletionRatio, equals(0.5));
      expect(task.subtaskCompletionPercentage, equals(50));
      expect(task.areAllSubtasksCompleted, isFalse);

      // Complete all subtasks
      task.subtasks![2].isCompleted = true;
      task.subtasks![3].isCompleted = true;

      expect(task.completedSubtasksCount, equals(4));
      expect(task.subtaskCompletionRatio, equals(1.0));
      expect(task.subtaskCompletionPercentage, equals(100));
      expect(task.areAllSubtasksCompleted, isTrue);
    });

    test('Empty subtask list returns 0 ratio and percentage', () {
      final task = Task(title: 'Simple Task');
      expect(task.totalSubtasksCount, equals(0));
      expect(task.completedSubtasksCount, equals(0));
      expect(task.subtaskCompletionRatio, equals(0.0));
      expect(task.subtaskCompletionPercentage, equals(0));
      expect(task.areAllSubtasksCompleted, isFalse);
    });

    testWidgets('SubtaskListWidget renders progress bar and allows inline operations', (tester) async {
      final subtasks = [
        SubTask(title: 'Subtask 1', isCompleted: true),
        SubTask(title: 'Subtask 2', isCompleted: false),
      ];

      bool changed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtaskListWidget(
              subtasks: subtasks,
              onChanged: (_) {
                changed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Subtasks Progress'), findsOneWidget);
      expect(find.text('1/2 (50%)'), findsOneWidget);
      expect(find.text('Subtask 1'), findsOneWidget);
      expect(find.text('Subtask 2'), findsOneWidget);

      // Add a subtask inline
      await tester.enterText(find.byType(TextField), 'Subtask 3');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(subtasks.length, equals(3));
      expect(find.text('Subtask 3'), findsOneWidget);
      expect(find.text('1/3 (33%)'), findsOneWidget);
      expect(changed, isTrue);
    });

    testWidgets('TaskCard3D displays animated subtask progress bar and X/Y (Z%) text', (tester) async {
      final task = Task(
        title: 'Task with subtasks',
        subtasks: [
          SubTask(title: 'Part 1', isCompleted: true),
          SubTask(title: 'Part 2', isCompleted: false),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.indigo,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('1/2 (50%) completed'), findsOneWidget);
    });

    testWidgets('Checking last subtask on TaskCard3D triggers auto-completion of parent task', (tester) async {
      bool parentCompleted = false;

      final task = Task(
        title: 'Auto-complete task',
        isCompleted: false,
        subtasks: [
          SubTask(title: 'Only Subtask', isCompleted: false),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.indigo,
              isDark: false,
              onToggleComplete: (val) {
                parentCompleted = val;
              },
            ),
          ),
        ),
      );

      // Expand subtasks list on card
      await tester.tap(find.text('0/1 (0%) completed'));
      await tester.pumpAndSettle();

      expect(find.text('Only Subtask'), findsOneWidget);

      // Check off the subtask
      await tester.tap(find.text('Only Subtask'));
      await tester.pumpAndSettle();

      expect(task.isCompleted, isTrue);
      expect(parentCompleted, isTrue);
      expect(find.text('1/1 (100%) completed'), findsOneWidget);
    });
  });
}
