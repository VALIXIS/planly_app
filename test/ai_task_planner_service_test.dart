import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:planly/services/ai_task_planner_service.dart';

void main() {
  group('AiTaskPlannerService - JSON Parsing & Validation', () {
    late AiTaskPlannerService service;

    setUp(() {
      service = AiTaskPlannerService(apiKey: 'TEST_KEY');
    });

    test('valid 4 subtasks JSON parses successfully', () {
      const validJson = '''
      {
        "subtasks": [
          {"title": "Review normalization concepts", "minutes": 30},
          {"title": "Practice functional dependency problems", "minutes": 45},
          {"title": "Revise decomposition and normal forms", "minutes": 30},
          {"title": "Solve previous exam questions", "minutes": 60}
        ]
      }
      ''';

      final result = service.parseAndValidateJson(validJson);
      expect(result.length, equals(4));
      expect(result[0].title, equals('Review normalization concepts'));
      expect(result[0].minutes, equals(30));
      expect(result[3].title, equals('Solve previous exam questions'));
      expect(result[3].minutes, equals(60));
    });

    test('valid 6 subtasks JSON parses successfully', () {
      const validJson = '''
      {
        "subtasks": [
          {"title": "Task 1", "minutes": 10},
          {"title": "Task 2", "minutes": 20},
          {"title": "Task 3", "minutes": 30},
          {"title": "Task 4", "minutes": 40},
          {"title": "Task 5", "minutes": 50},
          {"title": "Task 6", "minutes": 60}
        ]
      }
      ''';

      final result = service.parseAndValidateJson(validJson);
      expect(result.length, equals(6));
    });

    test('json wrapped in markdown code blocks parses successfully', () {
      const markdownJson = '''
      ```json
      {
        "subtasks": [
          {"title": "Task 1", "minutes": 15},
          {"title": "Task 2", "minutes": 25},
          {"title": "Task 3", "minutes": 35},
          {"title": "Task 4", "minutes": 45}
        ]
      }
      ```
      ''';

      final result = service.parseAndValidateJson(markdownJson);
      expect(result.length, equals(4));
    });

    test('throws when subtasks count is fewer than 4', () {
      const invalidJson = '''
      {
        "subtasks": [
          {"title": "Task 1", "minutes": 10},
          {"title": "Task 2", "minutes": 20},
          {"title": "Task 3", "minutes": 30}
        ]
      }
      ''';

      expect(
        () => service.parseAndValidateJson(invalidJson),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });

    test('throws when subtasks count is more than 6', () {
      const invalidJson = '''
      {
        "subtasks": [
          {"title": "Task 1", "minutes": 10},
          {"title": "Task 2", "minutes": 20},
          {"title": "Task 3", "minutes": 30},
          {"title": "Task 4", "minutes": 40},
          {"title": "Task 5", "minutes": 50},
          {"title": "Task 6", "minutes": 60},
          {"title": "Task 7", "minutes": 70}
        ]
      }
      ''';

      expect(
        () => service.parseAndValidateJson(invalidJson),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });

    test('throws when a subtask title is empty', () {
      const invalidJson = '''
      {
        "subtasks": [
          {"title": "", "minutes": 10},
          {"title": "Task 2", "minutes": 20},
          {"title": "Task 3", "minutes": 30},
          {"title": "Task 4", "minutes": 40}
        ]
      }
      ''';

      expect(
        () => service.parseAndValidateJson(invalidJson),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });

    test('throws when subtask minutes are 0 or negative', () {
      const invalidJson = '''
      {
        "subtasks": [
          {"title": "Task 1", "minutes": 0},
          {"title": "Task 2", "minutes": -15},
          {"title": "Task 3", "minutes": 30},
          {"title": "Task 4", "minutes": 40}
        ]
      }
      ''';

      expect(
        () => service.parseAndValidateJson(invalidJson),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });

    test('throws when json is malformed', () {
      const malformedJson = '{ "subtasks": [ {"title": "Task 1" ';

      expect(
        () => service.parseAndValidateJson(malformedJson),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });

    test('throws when subtasks field is missing', () {
      const missingSubtasks = '{"tasks": []}';

      expect(
        () => service.parseAndValidateJson(missingSubtasks),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI returned an invalid task breakdown.'),
          ),
        ),
      );
    });
  });

  group('AiTaskPlannerService - Inputs & API Key Handling', () {
    test('throws error when title is empty', () async {
      final service = AiTaskPlannerService(apiKey: 'TEST_KEY');
      expect(
        () => service.deconstructTaskStream('   ').first,
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('Enter a task title first.'),
          ),
        ),
      );
    });

    test('returns default fallback subtasks when API key is missing or empty', () async {
      final service = AiTaskPlannerService(apiKey: '');
      final subtasks = await service.deconstructTaskStream('Prepare for exam').first;
      expect(subtasks.length, 4);
      expect(subtasks.first.title, contains('Prepare for exam'));
    });

    test('streams generated subtasks successfully with mocked HTTP client', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        const sseBody = '''
data: {"candidates": [{"content": {"parts": [{"text": "{\\n  \\"subtasks\\": [\\n    {\\"title\\": \\"Review normalization concepts\\", \\"minutes\\": 30},\\n"}]}}]}

data: {"candidates": [{"content": {"parts": [{"text": "    {\\"title\\": \\"Practice functional dependency problems\\", \\"minutes\\": 45},\\n"}]}}]}

data: {"candidates": [{"content": {"parts": [{"text": "    {\\"title\\": \\"Revise decomposition and normal forms\\", \\"minutes\\": 30},\\n    {\\"title\\": \\"Solve previous exam questions\\", \\"minutes\\": 60}\\n  ]\\n}"}]}}]}

''';
        return http.StreamedResponse(
          Stream.value(utf8.encode(sseBody)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = AiTaskPlannerService(
        client: mockClient,
        apiKey: 'TEST_VALID_KEY',
      );

      final events = await service.deconstructTaskStream('Prepare for exam').toList();

      expect(events.isNotEmpty, isTrue);
      final finalSubtasks = events.last;
      expect(finalSubtasks.length, equals(4));
      expect(finalSubtasks[0].title, equals('Review normalization concepts'));
      expect(finalSubtasks[0].minutes, equals(30));
    });

    test('handles HTTP 500 error from API gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AiTaskPlannerService(
        client: mockClient,
        apiKey: 'TEST_KEY',
      );

      expect(
        () => service.deconstructTask('Prepare for exam'),
        throwsA(
          isA<AiTaskPlannerException>().having(
            (e) => e.message,
            'message',
            equals('AI task generation failed. Please try again.'),
          ),
        ),
      );
    });
  });
}
