import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();

  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const String _androidBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerTestAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _iosBannerTestAdUnitId;
      case TargetPlatform.android:
      default:
        return _androidBannerTestAdUnitId;
    }
  }

  static Future<void> initialize() async {
    if (!isSupportedPlatform) return;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: <String>['EMULATOR']),
    );

    await MobileAds.instance.initialize();
  }
}
