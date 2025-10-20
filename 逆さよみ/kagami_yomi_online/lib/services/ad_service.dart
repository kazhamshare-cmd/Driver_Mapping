import 'dart:io';
import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // iOS AdMob IDs
  static const String _iosAppId = 'ca-app-pub-1116360810482665~5332934959';
  static const String _iosBannerId = 'ca-app-pub-1116360810482665/4343286916';
  static const String _iosInterstitialId =
      'ca-app-pub-1116360810482665/7115762244';

  // Android AdMob IDs
  static const String _androidAppId = 'ca-app-pub-1116360810482665~8430065102';
  static const String _androidBannerId = 'ca-app-pub-1116360810482665/6753827836';
  static const String _androidInterstitialId =
      'ca-app-pub-1116360810482665/6980030874';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // AdMob初期化
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // バナー広告ID取得
  String get bannerAdUnitId {
    if (Platform.isIOS) {
      return _iosBannerId;
    } else if (Platform.isAndroid) {
      return _androidBannerId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  // インタースティシャル広告ID取得
  String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return _iosInterstitialId;
    } else if (Platform.isAndroid) {
      return _androidInterstitialId;
    }
    throw UnsupportedError('Unsupported platform');
  }

  // バナー広告作成
  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded.');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
  }

  // インタースティシャル広告ロード
  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              // 次の広告をプリロード
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              // エラー時も次の広告をプリロード
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  // インタースティシャル広告表示（確率付き）
  // percentage: 表示確率（0-100）
  Future<void> showInterstitialAd({int percentage = 100}) async {
    // 確率判定
    final random = Random();
    final shouldShow = random.nextInt(100) < percentage;

    if (!shouldShow) {
      print('Interstitial ad skipped by probability ($percentage%)');
      return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      await _interstitialAd!.show();
    } else {
      print('Interstitial ad is not ready yet.');
      // 広告が準備できていない場合は、ロードを試みる
      await loadInterstitialAd();
    }
  }

  // リソース解放
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
