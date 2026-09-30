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

    testWidgets('swipe right triggers onComplete and celebration', (tester) async {
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
  });
}
