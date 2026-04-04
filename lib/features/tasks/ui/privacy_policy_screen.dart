import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Planly stores your tasks, reminders, theme settings, onboarding state, and preference toggles locally on your device using Hive.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Notification permission is used only to schedule and deliver your task reminders. Turning reminders off for a task stops future reminder scheduling for that task.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Ads',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Planly shows Google Mobile Ads on supported mobile platforms by default. You can disable Support Ads in Settings, and you can keep Personalized Ads off so ad requests are sent as non-personalized.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Analytics in this build are local debug logs only and are not sent to a third-party analytics provider. You can disable local analytics logging from Settings.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Feedback',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'If you use Send Feedback, your default email app opens with your message so you can review and send it manually.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
