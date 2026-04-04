import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/ui/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding calls onFinish on the last page', (tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onFinish: () {
            finished = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(finished, isTrue);
  });
}
