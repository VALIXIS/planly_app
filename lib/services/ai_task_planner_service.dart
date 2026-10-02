import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/tasks/models/task_model.dart';

class AiTaskPlannerException implements Exception {
  final String message;
  final Object? originalError;

  AiTaskPlannerException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class AiTaskPlannerService {
  final http.Client _client;
  final String? _apiKeyOverride;

  AiTaskPlannerService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKeyOverride = apiKey;

  String get _apiKey {
    final override = _apiKeyOverride;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  /// Deconstructs a high-level task title into 4-6 subtasks with minute estimates.
  /// Emits progressive updates as subtasks become available, followed by the
  /// validated final list of 4-6 subtasks.
  Stream<List<TaskSubtask>> deconstructTaskStream(String taskTitle) async* {
    final trimmedTitle = taskTitle.trim();
    if (trimmedTitle.isEmpty) {
      throw AiTaskPlannerException('Enter a task title first.');
    }

    final key = _apiKey;
    if (key.trim().isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      yield [
        TaskSubtask(title: '1. Prepare & set up $trimmedTitle', minutes: 15),
        TaskSubtask(title: '2. Execute core steps for $trimmedTitle', minutes: 30),
        TaskSubtask(title: '3. Review and verify results', minutes: 15),
        TaskSubtask(title: '4. Finalize $trimmedTitle', minutes: 10),
      ];
      return;
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=$key&alt=sse',
    );

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Deconstruct the following task into 4 to 6 concrete subtasks with estimated completion time in minutes:\n\nTask Goal: "$trimmedTitle"',
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'subtasks': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'title': {'type': 'STRING'},
                  'minutes': {'type': 'INTEGER'}
                },
                'required': ['title', 'minutes']
              }
            }
          },
          'required': ['subtasks']
        }
      }
    });

    http.StreamedResponse response;
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = requestBody;

      response = await _client.send(request).timeout(const Duration(seconds: 30));
    } catch (e) {
      if (e is AiTaskPlannerException) rethrow;
      throw AiTaskPlannerException('AI task generation failed. Please try again.', e);
    }

    if (response.statusCode != 200) {
      throw AiTaskPlannerException('AI task generation failed. Please try again.');
    }

    final StringBuffer accumulatedText = StringBuffer();
    final List<TaskSubtask> progressiveSubtasks = [];

    try {
      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') continue;
          try {
            final Map<String, dynamic> chunkJson = jsonDecode(dataStr) as Map<String, dynamic>;
            final candidates = chunkJson['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final firstCandidate = candidates.first as Map<String, dynamic>;
              final content = firstCandidate['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final textPart = parts.first['text'] as String?;
                if (textPart != null) {
                  accumulatedText.write(textPart);
                  _tryExtractPartialSubtasks(accumulatedText.toString(), progressiveSubtasks);
                  if (progressiveSubtasks.isNotEmpty) {
                    yield List<TaskSubtask>.from(progressiveSubtasks);
                  }
                }
              }
            }
          } catch (_) {
            // Unparseable SSE line, keep buffering
          }
        } else if (line.trim().isNotEmpty && !line.startsWith('data:')) {
          accumulatedText.write(line);
          _tryExtractPartialSubtasks(accumulatedText.toString(), progressiveSubtasks);
          if (progressiveSubtasks.isNotEmpty) {
            yield List<TaskSubtask>.from(progressiveSubtasks);
          }
        }
      }
    } catch (e) {
      if (e is AiTaskPlannerException) rethrow;
      throw AiTaskPlannerException('AI task generation failed. Please try again.', e);
    }

    final rawJsonText = accumulatedText.toString().trim();
    final finalSubtasks = parseAndValidateJson(rawJsonText);
    yield finalSubtasks;
  }

  /// Non-streaming deconstruct method for direct calls / testing
  Future<List<TaskSubtask>> deconstructTask(String taskTitle) async {
    List<TaskSubtask> result = [];
    await for (final subtasks in deconstructTaskStream(taskTitle)) {
      result = subtasks;
    }
    return result;
  }

  void _tryExtractPartialSubtasks(String accumulatedText, List<TaskSubtask> targetList) {
    final matches = RegExp(r'\{\s*"title"\s*:\s*"([^"]+)"\s*,\s*"minutes"\s*:\s*(\d+)\s*\}').allMatches(accumulatedText);
    final newlyParsed = <TaskSubtask>[];
    for (final match in matches) {
      final title = match.group(1)?.trim();
      final minutesStr = match.group(2);
      final minutes = int.tryParse(minutesStr ?? '');
      if (title != null && title.isNotEmpty && minutes != null && minutes > 0) {
        newlyParsed.add(TaskSubtask(title: title, minutes: minutes));
      }
    }
    if (newlyParsed.length > targetList.length) {
      targetList.clear();
      targetList.addAll(newlyParsed);
    }
  }

  List<TaskSubtask> parseAndValidateJson(String rawText) {
    String cleaned = rawText.trim();
    if (cleaned.isEmpty) {
      throw AiTaskPlannerException('AI task generation failed. Please try again.');
    }

    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      throw AiTaskPlannerException('AI returned an invalid task breakdown.');
    }

    if (!decoded.containsKey('subtasks') || decoded['subtasks'] is! List) {
      throw AiTaskPlannerException('AI returned an invalid task breakdown.');
    }

    final rawSubtasks = decoded['subtasks'] as List;

    if (rawSubtasks.length < 4 || rawSubtasks.length > 6) {
      throw AiTaskPlannerException('AI returned an invalid task breakdown.');
    }

    final List<TaskSubtask> validated = [];

    for (final item in rawSubtasks) {
      if (item is! Map<String, dynamic>) {
        throw AiTaskPlannerException('AI returned an invalid task breakdown.');
      }

      final title = item['title'];
      final minutes = item['minutes'];

      if (title is! String || title.trim().isEmpty) {
        throw AiTaskPlannerException('AI returned an invalid task breakdown.');
      }

      if (minutes == null || minutes is! num || minutes <= 0 || minutes.isNaN || minutes.isInfinite) {
        throw AiTaskPlannerException('AI returned an invalid task breakdown.');
      }

      validated.add(TaskSubtask(
        title: title.trim(),
        minutes: minutes.toInt(),
      ));
    }

    return validated;
  }
}
