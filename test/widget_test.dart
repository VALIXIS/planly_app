import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/ui/feedback_screen.dart';

void main() {
  testWidgets('Feedback screen renders core UI', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FeedbackScreen()),
    );

    expect(find.text('Send Feedback'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Submit button enables after typing feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FeedbackScreen()),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Great app!');
    await tester.pump();

    final enabledButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(enabledButton.onPressed, isNotNull);
  });
}
