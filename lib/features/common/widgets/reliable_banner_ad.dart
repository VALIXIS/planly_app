import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../services/admob_service.dart';

class ReliableBannerAd extends StatefulWidget {
  const ReliableBannerAd({super.key, this.adUnitId});

  final String? adUnitId;

  static bool get isSupportedPlatform => AdMobService.isSupportedPlatform;

  @override
  State<ReliableBannerAd> createState() => _ReliableBannerAdState();
}

class _ReliableBannerAdState extends State<ReliableBannerAd>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoading = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerAd();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLoaded && !_isLoading) {
      _scheduleRetry(const Duration(milliseconds: 300));
    }
  }

  void _loadBannerAd() {
    if (!ReliableBannerAd.isSupportedPlatform || _isLoading) return;

    _isLoading = true;
    _retryTimer?.cancel();

    _bannerAd?.dispose();
    _bannerAd = null;

    final ad = BannerAd(
      adUnitId: widget.adUnitId ?? AdMobService.bannerAdUnitId,
      size: AdSize.banner,
      request: AdMobService.buildBannerRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          _isLoading = false;
          _retryCount = 0;

          if (!mounted) {
            loadedAd.dispose();
            return;
          }

          setState(() {
            _bannerAd = loadedAd as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (failedAd, _) {
          failedAd.dispose();
          _isLoading = false;

          if (!mounted) return;
          setState(() {
            _isLoaded = false;
          });

          _scheduleRetry(_nextRetryDelay());
        },
      ),
    );

    _bannerAd = ad;
    ad.load();
  }

  Duration _nextRetryDelay() {
    final seconds = 1 << _retryCount.clamp(1, 6);
    return Duration(seconds: seconds > 60 ? 60 : seconds);
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryCount += 1;
    _retryTimer = Timer(delay, _loadBannerAd);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AdSize.banner.width.toDouble(),
      height: AdSize.banner.height.toDouble(),
      child: _isLoaded && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : Container(
              color: Colors.transparent,
            ),
    );
  }
}