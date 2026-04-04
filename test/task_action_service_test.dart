import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/models/task_model.dart';
import 'package:planly/services/task_action_service.dart';

void main() {
  test('nextRecurringDueDate returns next daily occurrence in the future', () {
    final task = Task(
      title: 'Daily standup',
      dueDate: DateTime(2026, 4, 1, 9),
      recurrenceRule: 'daily',
    );

    final nextDueDate = TaskActionService.nextRecurringDueDate(
      task,
      now: DateTime(2026, 4, 4, 8),
    );

    expect(nextDueDate, DateTime(2026, 4, 4, 9));
  });

  test('nextRecurringDueDate returns next matching weekday occurrence', () {
    final task = Task(
      title: 'Workout',
      dueDate: DateTime(2026, 4, 1, 7),
      recurrenceRule: 'days:1,3,5',
    );

    final nextDueDate = TaskActionService.nextRecurringDueDate(
      task,
      now: DateTime(2026, 4, 2, 12),
    );

    expect(nextDueDate, DateTime(2026, 4, 3, 7));
  });
}
