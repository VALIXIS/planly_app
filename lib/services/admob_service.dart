import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';

class AdMobService {
  AdMobService._();

  static const String _androidBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get personalizedAdsEnabled {
    if (!Hive.isBoxOpen('settings')) return false;
    return Hive.box('settings').get(
      'adsPersonalizationEnabled',
      defaultValue: false,
    ) as bool;
  }

  static bool get supportAdsEnabled {
    if (!Hive.isBoxOpen('settings')) return false;
    return Hive.box('settings').get(
      'supportAdsEnabled',
      defaultValue: true,
    ) as bool;
  }

  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const String.fromEnvironment(
          'IOS_BANNER_AD_UNIT_ID',
          defaultValue: _iosBannerTestAdUnitId,
        );
      case TargetPlatform.android:
      default:
        return const String.fromEnvironment(
          'ANDROID_BANNER_AD_UNIT_ID',
          defaultValue: _androidBannerTestAdUnitId,
        );
    }
  }

  static AdRequest buildBannerRequest() {
    return AdRequest(nonPersonalizedAds: !personalizedAdsEnabled);
  }

  static Future<void> setPersonalizedAdsEnabled(bool enabled) async {
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').put('adsPersonalizationEnabled', enabled);
    }
  }

  static Future<void> setSupportAdsEnabled(bool enabled) async {
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').put('supportAdsEnabled', enabled);
    }
  }

  static Future<void> initialize() async {
    if (!isSupportedPlatform) return;

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.pg,
        testDeviceIds: kReleaseMode ? const <String>[] : const <String>['EMULATOR'],
      ),
    );

    await MobileAds.instance.initialize();
  }
}
