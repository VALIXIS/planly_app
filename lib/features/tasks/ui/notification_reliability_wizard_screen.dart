import 'package:flutter/material.dart';

import '../../../services/app_state_service.dart';
import '../../../services/notification_service.dart';

class NotificationReliabilityWizardScreen extends StatefulWidget {
  final bool fromFirstLaunch;

  const NotificationReliabilityWizardScreen({
    super.key,
    this.fromFirstLaunch = false,
  });

  @override
  State<NotificationReliabilityWizardScreen> createState() =>
      _NotificationReliabilityWizardScreenState();
}

class _NotificationReliabilityWizardScreenState
    extends State<NotificationReliabilityWizardScreen> {
  final NotificationService _notificationService = NotificationService();

  AndroidNotificationHealth? _health;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshHealth();
  }

  Future<void> _refreshHealth() async {
    setState(() => _isLoading = true);
    final health = await _notificationService.getAndroidNotificationHealth();
    if (!mounted) return;
    setState(() {
      _health = health;
      _isLoading = false;
    });
  }

  Future<void> _openBatterySettings() async {
    final opened = await _notificationService.openBatteryOptimizationSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened battery settings. Set Planly to Unrestricted.'
              : 'Could not open battery settings on this device.',
        ),
      ),
    );
  }

  Future<void> _allowExactAlarm() async {
    final granted = await _notificationService.requestExactAlarmPermission();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Exact alarm permission is enabled.'
              : 'Exact alarm is still blocked. Please allow it in app settings.',
        ),
      ),
    );

    await _refreshHealth();
  }

  Future<void> _openAutoStartSettings() async {
    final opened = await _notificationService.openAutoStartSettings();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened Auto-start settings. Allow Planly there.'
              : 'Could not open Auto-start settings on this device.',
        ),
      ),
    );
  }

  Future<void> _closeWizard() async {
    await AppStateService.setReliabilityWizardSeen(true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _statusRow({
    required String label,
    required bool ok,
  }) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          color: ok ? Colors.green : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final health = _health;
    final isVivoOrIqoo = health?.isVivoOrIqoo ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reliability Wizard'),
        automaticallyImplyLeading: !widget.fromFirstLaunch,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Keep reminders reliable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow these quick checks so reminders continue working after long idle periods, app updates, or device restarts.',
              style: TextStyle(color: subtitleColor, height: 1.35),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current status',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          _statusRow(
                            label: 'Battery optimization is unrestricted',
                            ok: health?.isIgnoringBatteryOptimizations ?? false,
                          ),
                          const SizedBox(height: 8),
                          _statusRow(
                            label: 'Exact alarm permission is enabled',
                            ok: health?.canScheduleExactAlarms ?? false,
                          ),
                          const SizedBox(height: 8),
                          _statusRow(
                            label: 'Power saver mode is off',
                            ok: !(health?.isPowerSaveModeEnabled ?? true),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openBatterySettings,
                  icon: const Icon(Icons.battery_saver_outlined),
                  label: const Text('Battery Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: _allowExactAlarm,
                  icon: const Icon(Icons.alarm_on_outlined),
                  label: const Text('Enable Exact Alarm'),
                ),
                OutlinedButton.icon(
                  onPressed: _refreshHealth,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Status'),
                ),
                if (isVivoOrIqoo)
                  OutlinedButton.icon(
                    onPressed: _openAutoStartSettings,
                    icon: const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Auto-start'),
                  ),
              ],
            ),
            if (isVivoOrIqoo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'iQOO/vivo tip: also allow Planly in Auto-start and set app battery mode to Unrestricted.',
                  style: TextStyle(color: subtitleColor),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _closeWizard,
                    child: const Text('Check Later'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _closeWizard,
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
