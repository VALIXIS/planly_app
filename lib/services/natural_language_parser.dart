class ParsedTaskResult {
  final String title;
  final DateTime? dueDate;
  final DateTime? reminderTime;
  final List<String> matchedTokens;
  final bool hasTime;

  const ParsedTaskResult({
    required this.title,
    this.dueDate,
    this.reminderTime,
    this.matchedTokens = const [],
    this.hasTime = false,
  });
}

class NaturalLanguageParser {
  /// Parses standard text like "Dentist tomorrow at 3pm" or "Submit report next monday at 10:30am"
  static ParsedTaskResult parse(String input, [DateTime? baseTime]) {
    final now = baseTime ?? DateTime.now();
    if (input.trim().isEmpty) {
      return const ParsedTaskResult(title: '');
    }

    String text = input;
    final List<String> tokens = [];
    DateTime? parsedDate;
    int? hour;
    int? minute;
    bool hasTime = false;

    // 1. Check relative duration phrases like "in X hours", "in X mins", "in X minutes"
    final inDurationRegex = RegExp(
      r'\bin\s+(\d+)\s*(hours?|hrs?|minutes?|mins?)\b',
      caseSensitive: false,
    );
    final inDurationMatch = inDurationRegex.firstMatch(text);
    if (inDurationMatch != null) {
      final amount = int.parse(inDurationMatch.group(1)!);
      final unit = inDurationMatch.group(2)!.toLowerCase();
      final tokenStr = inDurationMatch.group(0)!;
      tokens.add(tokenStr);

      if (unit.startsWith('h')) {
        parsedDate = now.add(Duration(hours: amount));
      } else {
        parsedDate = now.add(Duration(minutes: amount));
      }
      hour = parsedDate.hour;
      minute = parsedDate.minute;
      hasTime = true;
      text = text.replaceFirst(inDurationMatch.group(0)!, ' ');
    }

    // 2. Check time of day phrases if date not fully specified by "in X duration"
    if (!hasTime) {
      // Standard time formats: "at 3pm", "3:30pm", "15:00", "at 10:45 am"
      final timeRegex = RegExp(
        r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\b(?:at\s+)(\d{1,2}):(\d{2})\b',
        caseSensitive: false,
      );
      final timeMatch = timeRegex.firstMatch(text);
      if (timeMatch != null) {
        final tokenStr = timeMatch.group(0)!;
        tokens.add(tokenStr);

        if (timeMatch.group(3) != null) {
          // 12-hour format with am/pm
          int h = int.parse(timeMatch.group(1)!);
          final m = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
          final amPm = timeMatch.group(3)!.toLowerCase();
          if (amPm == 'pm' && h < 12) h += 12;
          if (amPm == 'am' && h == 12) h = 0;
          hour = h;
          minute = m;
          hasTime = true;
        } else if (timeMatch.group(4) != null) {
          // 24-hour format e.g. "at 15:30"
          hour = int.parse(timeMatch.group(4)!);
          minute = int.parse(timeMatch.group(5)!);
          hasTime = true;
        }
        text = text.replaceFirst(timeMatch.group(0)!, ' ');
      }
    }

    // 3. Time keywords if no specific numeric time was found yet
    if (!hasTime) {
      final timeKeywords = {
        r'\b(this\s+)?morning\b': const [9, 0],
        r'\b(this\s+)?noon\b|\bmidday\b': const [12, 0],
        r'\b(this\s+)?afternoon\b': const [14, 0],
        r'\b(this\s+)?evening\b': const [18, 0],
        r'\btonight\b|\b(this\s+)?night\b': const [20, 0],
      };

      for (final entry in timeKeywords.entries) {
        final match = RegExp(entry.key, caseSensitive: false).firstMatch(text);
        if (match != null) {
          tokens.add(match.group(0)!);
          hour = entry.value[0];
          minute = entry.value[1];
          hasTime = true;
          text = text.replaceFirst(match.group(0)!, ' ');
          break;
        }
      }
    }

    // 4. Date keywords / Days
    if (parsedDate == null) {
      DateTime baseDay = DateTime(now.year, now.month, now.day);

      // Relative day keywords
      if (RegExp(r'\bday\s+after\s+tomorrow\b', caseSensitive: false).hasMatch(text)) {
        final m = RegExp(r'\bday\s+after\s+tomorrow\b', caseSensitive: false).firstMatch(text)!;
        tokens.add(m.group(0)!);
        baseDay = baseDay.add(const Duration(days: 2));
        parsedDate = baseDay;
        text = text.replaceFirst(m.group(0)!, ' ');
      } else if (RegExp(r'\btomorrow\b|\btmrw\b|\btmr\b', caseSensitive: false).hasMatch(text)) {
        final m = RegExp(r'\btomorrow\b|\btmrw\b|\btmr\b', caseSensitive: false).firstMatch(text)!;
        tokens.add(m.group(0)!);
        baseDay = baseDay.add(const Duration(days: 1));
        parsedDate = baseDay;
        text = text.replaceFirst(m.group(0)!, ' ');
      } else if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(text)) {
        final m = RegExp(r'\btoday\b', caseSensitive: false).firstMatch(text)!;
        tokens.add(m.group(0)!);
        parsedDate = baseDay;
        text = text.replaceFirst(m.group(0)!, ' ');
      } else {
        // Weekdays: "next monday", "this friday", "monday", etc.
        final weekdayMatch = RegExp(
          r'\b(next\s+|this\s+)?(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\b',
          caseSensitive: false,
        ).firstMatch(text);

        if (weekdayMatch != null) {
          tokens.add(weekdayMatch.group(0)!);
          final isNext = weekdayMatch.group(1)?.toLowerCase().contains('next') ?? false;
          final dayName = weekdayMatch.group(2)!.toLowerCase();
          final targetWeekday = _parseWeekday(dayName);

          int daysDiff = targetWeekday - baseDay.weekday;
          if (daysDiff <= 0 || isNext) {
            daysDiff += 7;
          }
          parsedDate = baseDay.add(Duration(days: daysDiff));
          text = text.replaceFirst(weekdayMatch.group(0)!, ' ');
        } else {
          // Specific date matching e.g. "Oct 15", "15th Oct", "15/10"
          final monthDateMatch = RegExp(
            r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})(?:st|nd|rd|th)?\b|\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b',
            caseSensitive: false,
          ).firstMatch(text);

          if (monthDateMatch != null) {
            tokens.add(monthDateMatch.group(0)!);
            int mMonth = 1;
            int mDay = 1;
            if (monthDateMatch.group(1) != null) {
              mMonth = _parseMonth(monthDateMatch.group(1)!);
              mDay = int.parse(monthDateMatch.group(2)!);
            } else {
              mMonth = _parseMonth(monthDateMatch.group(4)!);
              mDay = int.parse(monthDateMatch.group(3)!);
            }
            int mYear = now.year;
            var calculated = DateTime(mYear, mMonth, mDay);
            if (calculated.isBefore(DateTime(now.year, now.month, now.day))) {
              mYear += 1;
              calculated = DateTime(mYear, mMonth, mDay);
            }
            parsedDate = calculated;
            text = text.replaceFirst(monthDateMatch.group(0)!, ' ');
          }
        }
      }
    }

    // Combine date and time if date was specified or time was specified
    DateTime? finalDueDate;
    if (parsedDate != null || hasTime) {
      final base = parsedDate ?? DateTime(now.year, now.month, now.day);
      final h = hour ?? 9; // Default 9:00 AM if date specified without time
      final m = minute ?? 0;
      finalDueDate = DateTime(base.year, base.month, base.day, h, m);
    }

    // Clean up title text
    String cleanedTitle = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Remove trailing/leading preposition artifacts like "at", "on", "for", "by" left over
    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'^(at|on|for|by)\s+', caseSensitive: false), '');
    cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\s+(at|on|for|by)$', caseSensitive: false), '');

    if (cleanedTitle.isEmpty) {
      cleanedTitle = input.trim();
    }

    return ParsedTaskResult(
      title: cleanedTitle,
      dueDate: finalDueDate,
      reminderTime: finalDueDate,
      matchedTokens: tokens,
      hasTime: hasTime,
    );
  }

  static int _parseWeekday(String name) {
    if (name.startsWith('mon')) return DateTime.monday;
    if (name.startsWith('tue')) return DateTime.tuesday;
    if (name.startsWith('wed')) return DateTime.wednesday;
    if (name.startsWith('thu')) return DateTime.thursday;
    if (name.startsWith('fri')) return DateTime.friday;
    if (name.startsWith('sat')) return DateTime.saturday;
    if (name.startsWith('sun')) return DateTime.sunday;
    return DateTime.monday;
  }

  static int _parseMonth(String name) {
    final lower = name.toLowerCase();
    if (lower.startsWith('jan')) return 1;
    if (lower.startsWith('feb')) return 2;
    if (lower.startsWith('mar')) return 3;
    if (lower.startsWith('apr')) return 4;
    if (lower.startsWith('may')) return 5;
    if (lower.startsWith('jun')) return 6;
    if (lower.startsWith('jul')) return 7;
    if (lower.startsWith('aug')) return 8;
    if (lower.startsWith('sep')) return 9;
    if (lower.startsWith('oct')) return 10;
    if (lower.startsWith('nov')) return 11;
    if (lower.startsWith('dec')) return 12;
    return 1;
  }
}
