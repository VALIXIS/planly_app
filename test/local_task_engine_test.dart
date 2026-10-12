import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/services/local_task_engine.dart';

void main() {
  group('LocalTaskEngine - Natural Language Task Parsing', () {
    final fixedNow = DateTime(2026, 10, 5, 10, 0); // Monday

    test('parses date, time, priority, category, and tags correctly', () {
      const input = 'Design landing page wireframes tomorrow at 3pm !high #Work #UI';
      final parsed = LocalTaskEngine.parse(input, nowReference: fixedNow);

      expect(parsed.cleanTitle, contains('Design landing page wireframes'));
      expect(parsed.dueDate, DateTime(2026, 10, 6)); // Tuesday
      expect(parsed.dueTime, const TimeOfDay(hour: 15, minute: 0));
      expect(parsed.priority, 'High');
      expect(parsed.category, 'Work');
      expect(parsed.tags, containsAll(['Work', 'UI']));
    });

    test('parses urgent meeting with reminder', () {
      const input = 'Urgent client sync this Friday 10:30am reminder 30m';
      final parsed = LocalTaskEngine.parse(input, nowReference: fixedNow);

      expect(parsed.cleanTitle, contains('Client sync'));
      expect(parsed.dueDate, DateTime(2026, 10, 9)); // Friday
      expect(parsed.dueTime, const TimeOfDay(hour: 10, minute: 30));
      expect(parsed.priority, 'High');
      expect(parsed.category, 'Work');
      expect(parsed.reminderMinutesBefore, 30);
    });

    test('parses shopping task with explicit items', () {
      const input = 'Buy groceries: organic milk, eggs, sourdough bread, apples';
      final parsed = LocalTaskEngine.parse(input, nowReference: fixedNow);

      expect(parsed.cleanTitle, contains('Buy groceries'));
      expect(parsed.category, 'Shopping');
      expect(parsed.subtasks.length, 4);
      expect(parsed.subtasks[0].title, contains('organic milk'));
      expect(parsed.subtasks[1].title, contains('eggs'));
      expect(parsed.subtasks[2].title, contains('sourdough bread'));
      expect(parsed.subtasks[3].title, contains('apples'));
    });

    test('parses relative day offsets like "in 3 days"', () {
      const input = 'Submit tax report in 3 days !urgent #Finance';
      final parsed = LocalTaskEngine.parse(input, nowReference: fixedNow);

      expect(parsed.cleanTitle, contains('Submit tax report'));
      expect(parsed.dueDate, DateTime(2026, 10, 8));
      expect(parsed.priority, 'High');
      expect(parsed.category, 'Work');
    });

    test('parses low priority and personal domain', () {
      const input = 'Organize bookshelf and clean room !low';
      final parsed = LocalTaskEngine.parse(input, nowReference: fixedNow);

      expect(parsed.cleanTitle, contains('Organize bookshelf and clean room'));
      expect(parsed.priority, 'Low');
      expect(parsed.category, 'Personal');
    });
  });

  group('LocalTaskEngine - Domain Subtask Deconstruction (0 Tokens)', () {
    test('generates coding subtasks for software development tasks', () {
      final subtasks = LocalTaskEngine.deconstructTaskLocally('Fix auth bug in flutter app');
      expect(subtasks.length, 4);
      expect(subtasks[0].title, contains('Reproduce issue'));
      expect(subtasks[1].title, contains('Implement core code'));
      expect(subtasks[2].title, contains('tests'));
      expect(subtasks.every((s) => s.minutes > 0), isTrue);
    });

    test('generates writing subtasks for report/document tasks', () {
      final subtasks = LocalTaskEngine.deconstructTaskLocally('Write annual finance report');
      expect(subtasks.length, 4);
      expect(subtasks[0].title, contains('Outline structure'));
      expect(subtasks[1].title, contains('Draft main content'));
    });

    test('generates meeting subtasks for calls/syncs', () {
      final subtasks = LocalTaskEngine.deconstructTaskLocally('Weekly team standup meeting');
      expect(subtasks.length, 4);
      expect(subtasks[0].title, contains('agenda'));
      expect(subtasks[3].title, contains('action items'));
    });

    test('generates workout subtasks for fitness tasks', () {
      final subtasks = LocalTaskEngine.deconstructTaskLocally('Full body gym workout routine');
      expect(subtasks.length, 4);
      expect(subtasks[0].title, contains('Warm-up'));
      expect(subtasks[1].title, contains('training routine'));
      expect(subtasks[2].title, contains('Cool-down'));
    });

    test('generates universal workflow subtasks for custom tasks', () {
      final subtasks = LocalTaskEngine.deconstructTaskLocally('Setup new aquarium');
      expect(subtasks.length, 4);
      expect(subtasks[0].title, contains('Prepare'));
      expect(subtasks[1].title, contains('Execute'));
      expect(subtasks[2].title, contains('Review'));
      expect(subtasks[3].title, contains('Finalize'));
    });

    test('streams progressive subtasks smoothly on-device', () async {
      final stream = LocalTaskEngine.deconstructTaskStreamLocally('Study physics for exam');
      final progressiveEvents = await stream.toList();

      expect(progressiveEvents.isNotEmpty, isTrue);
      expect(progressiveEvents.last.length, 4);
      expect(progressiveEvents.last[0].title, contains('syllabus'));
    });
  });
}
