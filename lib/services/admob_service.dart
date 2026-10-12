import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdMobService {
  AdMobService._();

  static const String _androidBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidBannerReleaseAdUnitId = String.fromEnvironment(
    'ANDROID_BANNER_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-6059224677913709/5151958786',
  );
  static const String _iosBannerReleaseAdUnitId = String.fromEnvironment(
    'IOS_BANNER_AD_UNIT_ID',
  );

  static const String _androidInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _androidInterstitialReleaseAdUnitId = String.fromEnvironment(
    'ANDROID_INTERSTITIAL_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-6059224677913709/1913248780',
  );
  static const String _iosInterstitialReleaseAdUnitId = String.fromEnvironment(
    'IOS_INTERSTITIAL_AD_UNIT_ID',
  );

  static const String _androidRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTestAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _androidRewardedReleaseAdUnitId = String.fromEnvironment(
    'ANDROID_REWARDED_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-6059224677913709/4115303503',
  );
  static const String _iosRewardedReleaseAdUnitId = String.fromEnvironment(
    'IOS_REWARDED_AD_UNIT_ID',
  );

  static const String _creditsKey = 'ai_deconstruct_credits';
  static const int defaultInitialCredits = 3;
  static const int rewardBonusCredits = 5;

  static RewardedAd? _rewardedAd;
  static bool _isRewardedAdLoading = false;

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoading = false;
  static DateTime? _lastInterstitialShowTime;
  static const Duration _interstitialCooldown = Duration(minutes: 2);

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          releaseAdUnitId: _iosBannerReleaseAdUnitId,
          testAdUnitId: _iosBannerTestAdUnitId,
          platformLabel: 'IOS_BANNER_AD_UNIT_ID',
        );
      case TargetPlatform.android:
      default:
        return _resolveAdUnitId(
          releaseAdUnitId: _androidBannerReleaseAdUnitId,
          testAdUnitId: _androidBannerTestAdUnitId,
          platformLabel: 'ANDROID_BANNER_AD_UNIT_ID',
        );
    }
  }

  static String get interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          releaseAdUnitId: _iosInterstitialReleaseAdUnitId,
          testAdUnitId: _iosInterstitialTestAdUnitId,
          platformLabel: 'IOS_INTERSTITIAL_AD_UNIT_ID',
        );
      case TargetPlatform.android:
      default:
        return _resolveAdUnitId(
          releaseAdUnitId: _androidInterstitialReleaseAdUnitId,
          testAdUnitId: _androidInterstitialTestAdUnitId,
          platformLabel: 'ANDROID_INTERSTITIAL_AD_UNIT_ID',
        );
    }
  }

  static String get rewardedAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _resolveAdUnitId(
          releaseAdUnitId: _iosRewardedReleaseAdUnitId,
          testAdUnitId: _iosRewardedTestAdUnitId,
          platformLabel: 'IOS_REWARDED_AD_UNIT_ID',
        );
      case TargetPlatform.android:
      default:
        return _resolveAdUnitId(
          releaseAdUnitId: _androidRewardedReleaseAdUnitId,
          testAdUnitId: _androidRewardedTestAdUnitId,
          platformLabel: 'ANDROID_REWARDED_AD_UNIT_ID',
        );
    }
  }

  static String _resolveAdUnitId({
    required String releaseAdUnitId,
    required String testAdUnitId,
    required String platformLabel,
  }) {
    if (!kReleaseMode) return testAdUnitId;

    final adUnitId = releaseAdUnitId.trim();
    if (adUnitId.isEmpty || adUnitId.startsWith('ca-app-pub-3940256099942544/')) {
      debugPrint('AdMob notice: Real $platformLabel not provided. Using safe fallback.');
      return testAdUnitId;
    }

    return adUnitId;
  }

  static AdRequest buildBannerRequest() {
    return const AdRequest();
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
    loadRewardedAd();
    loadInterstitialAd();
  }

  // ---------------------------------------------------------------------------
  // Credit Balance Tracking (SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Retrieves the current AI deconstruct credit balance from SharedPreferences.
  static Future<int> getCredits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_creditsKey)) {
        await prefs.setInt(_creditsKey, defaultInitialCredits);
        return defaultInitialCredits;
      }
      return prefs.getInt(_creditsKey) ?? defaultInitialCredits;
    } catch (e) {
      debugPrint('Error getting AI credits: $e');
      return defaultInitialCredits;
    }
  }

  /// Explicitly sets the credit balance in SharedPreferences.
  static Future<void> setCredits(int amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_creditsKey, amount < 0 ? 0 : amount);
    } catch (e) {
      debugPrint('Error setting AI credits: $e');
    }
  }

  /// Consumes 1 credit if balance > 0, returns the updated credit balance.
  static Future<int> consumeCredit() async {
    final current = await getCredits();
    if (current <= 0) return 0;
    final updated = current - 1;
    await setCredits(updated);
    return updated;
  }

  /// Adds [amount] credits to balance and returns the updated credit balance.
  static Future<int> addCredits(int amount) async {
    final current = await getCredits();
    final updated = current + amount;
    await setCredits(updated);
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Rewarded Video Ad Handling
  // ---------------------------------------------------------------------------

  /// Preloads a RewardedAd for seamless display.
  static Future<void> loadRewardedAd() async {
    if (!isSupportedPlatform || _isRewardedAdLoading || _rewardedAd != null) {
      return;
    }

    _isRewardedAdLoading = true;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          debugPrint('RewardedAd loaded successfully.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  /// Shows the RewardedAd. When the user earns a reward, [onRewardGranted] is
  /// called with the updated credit balance (+5 credits).
  static Future<void> showRewardedAd({
    required void Function(int newCredits) onRewardGranted,
    void Function(String error)? onError,
  }) async {
    if (!isSupportedPlatform) {
      // In unsupported environments (e.g. desktop/web/simulators without AdMob),
      // simulate rewarded ad view for testing.
      final newCredits = await addCredits(rewardBonusCredits);
      onRewardGranted(newCredits);
      return;
    }

    if (_rewardedAd == null) {
      // Attempt to load and show on demand
      _isRewardedAdLoading = true;
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedAdLoading = false;
            _presentRewardedAd(onRewardGranted: onRewardGranted, onError: onError);
          },
          onAdFailedToLoad: (LoadAdError error) async {
            _rewardedAd = null;
            _isRewardedAdLoading = false;
            debugPrint('RewardedAd on-demand load failed: $error');
            // Fallback for test/offline mode so user can still test & receive credits
            final newCredits = await addCredits(rewardBonusCredits);
            onRewardGranted(newCredits);
          },
        ),
      );
      return;
    }

    _presentRewardedAd(onRewardGranted: onRewardGranted, onError: onError);
  }

  static void _presentRewardedAd({
    required void Function(int newCredits) onRewardGranted,
    void Function(String error)? onError,
  }) {
    if (_rewardedAd == null) {
      onError?.call('Rewarded ad not available');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        debugPrint('RewardedAd failed to show: $error');
        // Grant credits on show failure so user flow is not broken
        final newCredits = await addCredits(rewardBonusCredits);
        onRewardGranted(newCredits);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        final newCredits = await addCredits(rewardBonusCredits);
        onRewardGranted(newCredits);
      },
    );

    _rewardedAd = null;
  }

  // ---------------------------------------------------------------------------
  // Interstitial Ad Handling (High-Yield Placements)
  // ---------------------------------------------------------------------------

  /// Preloads an InterstitialAd for instantaneous presentation.
  static Future<void> loadInterstitialAd() async {
    if (!isSupportedPlatform || _isInterstitialAdLoading || _interstitialAd != null) {
      return;
    }

    _isInterstitialAdLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;
            debugPrint('InterstitialAd loaded successfully.');
          },
          onAdFailedToLoad: (LoadAdError error) {
            _interstitialAd = null;
            _isInterstitialAdLoading = false;
            debugPrint('InterstitialAd failed to load: $error');
          },
        ),
      );
    } catch (e) {
      _isInterstitialAdLoading = false;
      debugPrint('Error loading interstitial ad: $e');
    }
  }

  /// Displays the Interstitial Ad with frequency capping to maximize eCPM.
  static Future<void> showInterstitialAd({
    VoidCallback? onDismissed,
  }) async {
    if (!isSupportedPlatform) {
      onDismissed?.call();
      return;
    }

    // Cooldown check (minimum 2 minutes between interstitial impressions)
    if (_lastInterstitialShowTime != null &&
        DateTime.now().difference(_lastInterstitialShowTime!) < _interstitialCooldown) {
      onDismissed?.call();
      return;
    }

    if (_interstitialAd == null) {
      loadInterstitialAd();
      onDismissed?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShowTime = DateTime.now();
        loadInterstitialAd(); // Preload next interstitial
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        debugPrint('InterstitialAd failed to show: $error');
        onDismissed?.call();
      },
    );

    await _interstitialAd!.show();
    _interstitialAd = null;
  }
}
