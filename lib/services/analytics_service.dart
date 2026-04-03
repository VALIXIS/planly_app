import 'package:flutter/foundation.dart';

class AnalyticsService {
  static bool _initialized = false;

  static Future<void> init() async {
    _initialized = true;
  }

  static bool get isInitialized => _initialized;

  static Future<void> logAppOpen() async {
    if (kDebugMode) {
      debugPrint('[analytics] app_open');
    }
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (kDebugMode) {
      debugPrint('[analytics] $name ${parameters ?? const {}}');
    }
  }
}
