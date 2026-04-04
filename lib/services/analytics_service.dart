import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AnalyticsService {
  AnalyticsService._();

  static bool _initialized = false;
  static bool _enabled = true;

  static Future<void> init() async {
    if (Hive.isBoxOpen('settings')) {
      _enabled = Hive.box('settings').get(
        'analyticsEnabled',
        defaultValue: true,
      ) as bool;
    }
    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static bool get isEnabled => _enabled;

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').put('analyticsEnabled', enabled);
    }
  }

  static Future<void> logAppOpen() async {
    await logEvent('app_open');
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_initialized || !_enabled || !kDebugMode) return;
    debugPrint('[analytics][local] $name ${parameters ?? const {}}');
  }
}
