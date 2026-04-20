import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  AdMobService._();

  static const String _androidBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidBannerReleaseAdUnitId =
      String.fromEnvironment(
        'ANDROID_BANNER_AD_UNIT_ID',
        defaultValue: 'ca-app-pub-6059224677913709/7889542039',
      );
  static const String _iosBannerReleaseAdUnitId =
      String.fromEnvironment('IOS_BANNER_AD_UNIT_ID');

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _resolveBannerAdUnitId(
          releaseAdUnitId: _iosBannerReleaseAdUnitId,
          testAdUnitId: _iosBannerTestAdUnitId,
          platformLabel: 'IOS_BANNER_AD_UNIT_ID',
        );
      case TargetPlatform.android:
      default:
        return _resolveBannerAdUnitId(
          releaseAdUnitId: _androidBannerReleaseAdUnitId,
          testAdUnitId: _androidBannerTestAdUnitId,
          platformLabel: 'ANDROID_BANNER_AD_UNIT_ID',
        );
    }
  }

  static String _resolveBannerAdUnitId({
    required String releaseAdUnitId,
    required String testAdUnitId,
    required String platformLabel,
  }) {
    if (!kReleaseMode) return testAdUnitId;

    final adUnitId = releaseAdUnitId.trim();
    if (adUnitId.isEmpty || adUnitId.startsWith('ca-app-pub-3940256099942544/')) {
      throw StateError(
        'Missing real $platformLabel. Pass it with --dart-define when building the Play Store bundle.',
      );
    }

    return adUnitId;
  }

  static AdRequest buildBannerRequest() {
    return AdRequest();
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
