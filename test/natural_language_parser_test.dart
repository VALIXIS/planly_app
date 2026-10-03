import 'package:flutter_test/flutter_test.dart';
import 'package:planly/services/natural_language_parser.dart';

void main() {
  final baseTime = DateTime(2026, 10, 2, 10, 0); // Friday Oct 2, 2026 10:00 AM

  test('Parses relative day and time correctly', () {
    final result = NaturalLanguageParser.parse('Dentist tomorrow at 3pm', baseTime);
    expect(result.title, equals('Dentist'));
    expect(result.dueDate, equals(DateTime(2026, 10, 3, 15, 0)));
    expect(result.matchedTokens, containsAll(['tomorrow', 'at 3pm']));
    expect(result.hasTime, isTrue);
  });

  test('Parses relative duration in hours', () {
    final result = NaturalLanguageParser.parse('Call Bob in 2 hours', baseTime);
    expect(result.title, equals('Call Bob'));
    expect(result.dueDate, equals(DateTime(2026, 10, 2, 12, 0)));
    expect(result.matchedTokens, contains('in 2 hours'));
  });

  test('Parses weekday and time keyword', () {
    final result = NaturalLanguageParser.parse('Meeting next monday evening', baseTime);
    expect(result.title, equals('Meeting'));
    expect(result.dueDate?.weekday, equals(DateTime.monday));
    expect(result.dueDate?.hour, equals(18));
    expect(result.matchedTokens, containsAll(['next monday', 'evening']));
  });

  test('Parses simple text with no date tokens', () {
    final result = NaturalLanguageParser.parse('Buy groceries', baseTime);
    expect(result.title, equals('Buy groceries'));
    expect(result.dueDate, isNull);
    expect(result.matchedTokens, isEmpty);
  });
}
