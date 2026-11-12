import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Uses Google's official test banner by default.
/// Supply ADMOB_BANNER_AD_UNIT_ID at build time for a production ad unit.
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  static const String _adUnitId = String.fromEnvironment(
    'ADMOB_BANNER_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );

  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _banner = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
          failedAd.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (banner == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
