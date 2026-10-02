import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/ui/widgets/quick_capture_sheet.dart';

void main() {
  testWidgets('QuickCaptureSheet renders single input field and headers', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuickCaptureSheet(),
        ),
      ),
    );

    expect(find.text('Quick Capture'), findsOneWidget);
    expect(find.text('More options'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save Task'), findsOneWidget);
  });
}
