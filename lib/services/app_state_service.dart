import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppStateService {
  AppStateService._();

  static const Color defaultAccentColor = Color(0xFF7C4DFF);
  static const String reliabilityWizardSeenKey =
      'notificationReliabilityWizardSeen';

  static final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static final ValueNotifier<Color> accentColorNotifier =
      ValueNotifier<Color>(defaultAccentColor);

  static Box<dynamic> get _settingsBox => Hive.box('settings');

  static void loadPersistedSettings() {
    final isDark = _settingsBox.get('isDarkMode', defaultValue: false) as bool;
    final savedColor =
        _settingsBox.get('accentColor', defaultValue: defaultAccentColor.toARGB32())
            as int;

    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    accentColorNotifier.value = Color(savedColor);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    await _settingsBox.put('isDarkMode', mode == ThemeMode.dark);
  }

  static Future<void> toggleTheme() async {
    final nextMode =
        themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  static Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    await _settingsBox.put('accentColor', color.toARGB32());
  }

  static Future<void> setOnboardingDone() async {
    await _settingsBox.put('onboardingDone', true);
  }

  static bool get isReliabilityWizardSeen =>
      _settingsBox.get(reliabilityWizardSeenKey, defaultValue: false) as bool;

  static Future<void> setReliabilityWizardSeen(bool value) async {
    await _settingsBox.put(reliabilityWizardSeenKey, value);
  }
}
