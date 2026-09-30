import 'package:flutter_test/flutter_test.dart';
import 'package:planly/services/notification_service.dart';

void main() {
  test('notification action constants match specification', () {
    expect(notificationActionComplete, 'action_complete');
    expect(notificationActionSnooze, 'action_snooze');
  });
}
