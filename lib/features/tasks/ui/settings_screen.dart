import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../services/app_state_service.dart';
import '../../../services/admob_service.dart';
import '../../../services/notification_service.dart';
import '../models/task_model.dart';
import 'feedback_screen.dart';
import 'notification_reliability_wizard_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<Map<String, dynamic>> _colors = [
    {'label': 'Violet', 'color': const Color(0xFF7C4DFF)},
    {'label': 'Lavender', 'color': const Color(0xFF9575CD)},
    {'label': 'Indigo', 'color': const Color(0xFF3D5AFE)},
    {'label': 'Ocean', 'color': const Color(0xFF1565C0)},
    {'label': 'Teal', 'color': const Color(0xFF00695C)},
    {'label': 'Forest', 'color': const Color(0xFF2E7D32)},
    {'label': 'Amber', 'color': const Color(0xFFE65100)},
    {'label': 'Rose', 'color': const Color(0xFFC2185B)},
    {'label': 'Coral', 'color': const Color(0xFFD84315)},
    {'label': 'Slate', 'color': const Color(0xFF37474F)},
    {'label': 'Navy', 'color': const Color(0xFF1A237E)},
    {'label': 'Midnight', 'color': const Color(0xFF1C1C3A)},
  ];

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  final NotificationService _notificationService = NotificationService();

  AndroidNotificationHealth? _androidNotificationHealth;
  bool _isCheckingNotificationHealth = false;

  Box<dynamic> get _settings => Hive.box('settings');

  bool get _showSplashQuote =>
      _settings.get('showSplashQuote', defaultValue: true) as bool;

  bool get _showHomeQuote =>
      _settings.get('showHomeQuote', defaultValue: true) as bool;

  String get _selectedLanguage =>
      _settings.get('language', defaultValue: 'English') as String;

  Color get _selectedAccentColor =>
      Color(_settings.get('accentColor', defaultValue: 0xFF7C4DFF) as int);

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadNotificationHealth();
  }

  Future<void> _loadNotificationHealth() async {
    if (!NotificationService.isAndroidDevice) return;

    if (mounted) {
      setState(() => _isCheckingNotificationHealth = true);
    }

    final health = await _notificationService.getAndroidNotificationHealth();

    if (!mounted) return;
    setState(() {
      _androidNotificationHealth = health;
      _isCheckingNotificationHealth = false;
    });
  }

  String _notificationHealthSummary() {
    if (_isCheckingNotificationHealth) {
      return 'Checking battery and alarm permissions...';
    }

    final health = _androidNotificationHealth;
    if (health == null) {
      return 'Could not read device battery restrictions. You can still open settings manually.';
    }

    final summary = <String>[
      health.isIgnoringBatteryOptimizations
          ? 'Battery optimization is unrestricted'
          : 'Battery optimization is restricted',
      health.canScheduleExactAlarms
          ? 'exact alarms are allowed'
          : 'exact alarms are blocked',
      health.isPowerSaveModeEnabled
          ? 'power saver is on'
          : 'power saver is off',
    ];

    return '${health.deviceLabel}: ${summary.join(', ')}.';
  }

  Future<void> _openBatteryOptimizationSettings() async {
    final opened = await _notificationService.openBatteryOptimizationSettings();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened battery settings. Set Planly to Unrestricted and return to refresh.'
              : 'Could not open battery settings on this device.',
        ),
      ),
    );
  }

  Future<void> _requestExactAlarmPermission() async {
    final granted = await _notificationService.requestExactAlarmPermission();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Exact alarm permission is allowed.'
              : 'Exact alarms are still blocked. Please allow Exact alarms in app settings.',
        ),
      ),
    );

    await _loadNotificationHealth();
  }

  Future<void> _openAutoStartSettings() async {
    final opened = await _notificationService.openAutoStartSettings();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened Auto-start settings. Allow Planly and return to refresh.'
              : 'Could not open Auto-start settings on this device.',
        ),
      ),
    );
  }

  Future<void> _openReliabilityWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationReliabilityWizardScreen(),
      ),
    );

    if (!mounted) return;
    await _loadNotificationHealth();
  }

  Future<void> _checkReliabilityLater() async {
    await AppStateService.setReliabilityWizardSeen(false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reliability wizard will open again on next app start.'),
      ),
    );
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;

    if (!AdMobService.isSupportedPlatform) {
      if (mounted) setState(() {});
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: AdMobService.buildBannerRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _isBannerLoaded = false);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _saveSetting(String key, dynamic value) {
    _settings.put(key, value);
    if (mounted) setState(() {});
  }

  void _setAccentColor(Color color) {
    AppStateService.setAccentColor(color);
    if (mounted) setState(() {});
  }

  Future<void> _confirmClearAllTasks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Tasks'),
        content: const Text(
          'This will permanently delete all tasks and reminders. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final taskBox = Hive.box<Task>('tasks');
    await taskBox.clear();
    await NotificationService().cancelAll();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All tasks cleared')));
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }

  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: child,
    );
  }

  Widget _settingsHeader(bool isDark, Color primary) {
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: isDark ? 0.28 : 0.14),
            primary.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
        ),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.38 : 0.22),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.26 : 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize Planly',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Theme, colors, quotes, and app preferences',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorPalette(bool isDark, Color primary) {
    final selected = _selectedAccentColor.toARGB32();
    final labelColor = isDark ? Colors.white54 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accent Color',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pick a color that fits your workflow mood.',
          style: TextStyle(fontSize: 12, color: labelColor),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((entry) {
            final color = entry['color'] as Color;
            final label = entry['label'] as String;
            final isSelected = color.toARGB32() == selected;

            return GestureDetector(
              onTap: () => _setAccentColor(color),
              child: SizedBox(
                width: 66,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: labelColor,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;
    final notificationHealth = _androidNotificationHealth;
    final showVivoHelp = notificationHealth?.isVivoOrIqoo ?? false;
    final hasDeliveryRisk = notificationHealth?.hasDeliveryRisk ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                _settingsHeader(isDark, primary),
                const SizedBox(height: 20),

                _sectionTitle('Appearance', isDark),
                _card(
                  isDark: isDark,
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppStateService.themeNotifier,
                    builder: (context, mode, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.dark_mode_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        title: const Text('Dark Mode'),
                        subtitle: Text(
                          'Reduce eye strain in low-light environments',
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        value: mode == ThemeMode.dark,
                        onChanged: (value) {
                          AppStateService.setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle('Personalization', isDark),
                _card(isDark: isDark, child: _colorPalette(isDark, primary)),
                const SizedBox(height: 10),
                _card(
                  isDark: isDark,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.auto_awesome_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        title: const Text('Quote on Launch Screen'),
                        subtitle: Text(
                          'Show a motivational quote when the app opens',
                          style:
                              TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        value: _showSplashQuote,
                        onChanged: (value) =>
                            _saveSetting('showSplashQuote', value),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          Icons.format_quote_rounded,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        title: const Text('Quote on Home Screen'),
                        subtitle: Text(
                          'Show a daily quote card on the home view',
                          style:
                              TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        value: _showHomeQuote,
                        onChanged: (value) =>
                            _saveSetting('showHomeQuote', value),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle('General', isDark),
                _card(
                  isDark: isDark,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.language_outlined,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    title: const Text('Language'),
                    subtitle: Text(
                      'More languages coming soon',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedLanguage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ),

                if (NotificationService.isAndroidDevice) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Notifications', isDark),
                  _card(
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            hasDeliveryRisk
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                            color: hasDeliveryRisk
                                ? Colors.orange
                                : (isDark ? Colors.lightGreenAccent : Colors.green),
                          ),
                          title: const Text('Notification Reliability Check'),
                          subtitle: Text(
                            _notificationHealthSummary(),
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openBatteryOptimizationSettings,
                              icon: const Icon(Icons.battery_saver_outlined),
                              label: const Text('Battery Settings'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _requestExactAlarmPermission,
                              icon: const Icon(Icons.alarm_on_outlined),
                              label: const Text('Exact Alarm'),
                            ),
                            if (showVivoHelp)
                              OutlinedButton.icon(
                                onPressed: _openAutoStartSettings,
                                icon: const Icon(Icons.rocket_launch_outlined),
                                label: const Text('Auto-start'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _loadNotificationHealth,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                        if (showVivoHelp)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'For iQOO/vivo devices, allow Planly in Auto-start and set battery mode to Unrestricted for reliable reminders.',
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.shield_outlined,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          title: const Text('Reliability Wizard'),
                          subtitle: Text(
                            'Run guided checks now, or schedule it for next app open.',
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openReliabilityWizard,
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Run Now'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _checkReliabilityLater,
                              icon: const Icon(Icons.schedule_outlined),
                              label: const Text('Check Later'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _sectionTitle('Support', isDark),
                _card(
                  isDark: isDark,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.privacy_tip_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.feedback_outlined,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        title: const Text('Send Feedback'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FeedbackScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                _sectionTitle('Danger Zone', isDark),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: isDark ? 0.4 : 0.22),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clear All Tasks',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This removes every task and scheduled reminder permanently.',
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: Colors.red.withValues(alpha: 0.45),
                          ),
                        ),
                        onPressed: _confirmClearAllTasks,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete All Tasks'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (AdMobService.isSupportedPlatform)
            Container(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Support Planly',
                    style: TextStyle(fontSize: 11, color: subtitleColor),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: AdSize.banner.width.toDouble(),
                    height: AdSize.banner.height.toDouble(),
                    child: _isBannerLoaded && _bannerAd != null
                        ? AdWidget(ad: _bannerAd!)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
