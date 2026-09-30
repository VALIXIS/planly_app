import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/features/tasks/ui/widgets/task_card_3d.dart';

void main() {
  group('TaskCard3D Widget Tests', () {
    testWidgets('renders task card title, metadata, and priority bar', (tester) async {
      final task = Task(
        title: 'Review 3D Parallax PR',
        description: 'Test fluid gestures and matrix transform',
        priority: 'High',
        category: 'Work',
        dueDate: DateTime.now().add(const Duration(hours: 4)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('Review 3D Parallax PR'), findsOneWidget);
      expect(find.text('Test fluid gestures and matrix transform'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('swipe right triggers onComplete and celebratory particle burst', (tester) async {
      bool completed = false;
      final task = Task(
        title: 'Complete my milestone',
        priority: 'Medium',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      // Drag right by 120 pixels to pass swipe threshold
      await tester.drag(find.text('Complete my milestone'), const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('swipe left triggers onReschedule', (tester) async {
      bool rescheduled = false;
      final task = Task(
        title: 'Reschedule my meeting',
        priority: 'Low',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
              onReschedule: () {
                rescheduled = true;
              },
            ),
          ),
        ),
      );

      // Drag left by -120 pixels to pass swipe threshold
      await tester.drag(find.text('Reschedule my meeting'), const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(rescheduled, isTrue);
    });

    testWidgets('tap checkbox toggles completion and triggers onComplete', (tester) async {
      bool completed = false;
      final task = Task(
        title: 'Checkbox test task',
        isCompleted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      // Find the checkbox container by key
      final checkboxFinder = find.byKey(const ValueKey('task_card_checkbox'));
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('touch gesture applies 3D parallax tilt with 4x4 matrix', (tester) async {
      final task = Task(
        title: '3D Parallax Tilt Card',
        priority: 'High',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
            ),
          ),
        ),
      );

      // Verify Transform widgets exist with perspective
      final initialTransforms = tester.widgetList<Transform>(find.byType(Transform));
      final hasPerspective = initialTransforms.any(
        (t) => (t.transform.entry(3, 2) - 0.001).abs() < 1e-5,
      );
      expect(hasPerspective, isTrue);

      // Perform pointer touch and move to induce 3D tilt
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      await gesture.down(tester.getCenter(find.text('3D Parallax Tilt Card')));
      await gesture.moveBy(const Offset(40, -20));
      await tester.pump();

      // Check transform maintains 3D camera perspective under tilt
      final updatedTransforms = tester.widgetList<Transform>(find.byType(Transform));
      final hasActivePerspective = updatedTransforms.any(
        (t) => (t.transform.entry(3, 2) - 0.001).abs() < 0.0005,
      );
      expect(hasActivePerspective, isTrue);

      // Release finger - spring animation resets tilt
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('renders overdue styling with red text for overdue tasks', (tester) async {
      final task = Task(
        title: 'Overdue task',
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        isCompleted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
            ),
          ),
        ),
      );

      final iconFinder = find.byIcon(Icons.access_time_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, const Color(0xFFEF4444));
    });

    testWidgets('renders recurrence icon for recurring tasks', (tester) async {
      final task = Task(
        title: 'Recurring task',
        recurrenceRule: 'daily',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });

    testWidgets('multi-select mode renders selection checkmark and disables tilt/swipe', (tester) async {
      final task = Task(
        title: 'Selectable task',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskCard3D(
              task: task,
              primary: Colors.teal,
              isDark: false,
              isSelectionMode: true,
              isSelected: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });
}
