import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 本番環境用の広告ユニットID（アプリ承認後にAdMob管理画面で自動的に有効化されます）
  // iOS
  static const String _bannerAdUnitIdIOS = 'ca-app-pub-1116360810482665/4160402860';
  static const String _interstitialAdUnitIdIOS = 'ca-app-pub-1116360810482665/8373801381';

  // Android
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-1116360810482665/4844075322';
  static const String _interstitialAdUnitIdAndroid = 'ca-app-pub-1116360810482665/1256184106';

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _interstitialAdLoadAttempts = 0;
  static const int _maxInterstitialAdLoadAttempts = 3;

  // ゲームプレイ回数をカウント（Google判断で表示頻度を調整）
  int _gamePlayCount = 0;
  static const int _gamesUntilInterstitial = 3; // 3回に1回表示

  /// AdMobを初期化
  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      
      // テストデバイスIDを設定（開発中のみ）
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['b00382b3304c065d906c38ac134aab9a'], // ログに表示されたデバイスID
        ),
      );
      
      print('✅ AdMob initialized');
      _loadInterstitialAd();
    } catch (e) {
      print('❌ AdMob initialization failed: $e');
    }
  }

  /// バナー広告のユニットIDを取得
  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      return _bannerAdUnitIdIOS;
    } else if (Platform.isAndroid) {
      return _bannerAdUnitIdAndroid;
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// インタースティシャル広告のユニットIDを取得
  static String get interstitialAdUnitId {
    if (Platform.isIOS) {
      return _interstitialAdUnitIdIOS;
    } else if (Platform.isAndroid) {
      return _interstitialAdUnitIdAndroid;
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// バナー広告を作成
  BannerAd createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('📱 Banner ad opened');
        },
        onAdClosed: (ad) {
          print('📱 Banner ad closed');
        },
      ),
    );

    _bannerAd!.load();
    return _bannerAd!;
  }

  /// インタースティシャル広告を読み込み
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ Interstitial ad loaded');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _interstitialAdLoadAttempts = 0;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('📱 Interstitial ad showed');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('📱 Interstitial ad dismissed');
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd(); // 次の広告を事前読み込み
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Interstitial ad failed to show: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Interstitial ad failed to load: $error');
          _interstitialAdLoadAttempts++;
          _isInterstitialAdReady = false;

          // リトライ（最大3回）
          if (_interstitialAdLoadAttempts < _maxInterstitialAdLoadAttempts) {
            Future.delayed(
              Duration(seconds: _interstitialAdLoadAttempts * 2),
              () => _loadInterstitialAd(),
            );
          }
        },
      ),
    );
  }

  /// インタースティシャル広告を表示（Google判断で適時表示）
  void showInterstitialAd() {
    _gamePlayCount++;

    // 一定回数ごとに表示判定
    if (_gamePlayCount % _gamesUntilInterstitial != 0) {
      print('📊 Game count: $_gamePlayCount - Skipping interstitial');
      return;
    }

    if (!_isInterstitialAdReady || _interstitialAd == null) {
      print('⚠️ Interstitial ad not ready');
      _loadInterstitialAd(); // 次回に備えて読み込み
      return;
    }

    print('📺 Showing interstitial ad');
    _interstitialAd!.show();
    _isInterstitialAdReady = false;
    _interstitialAd = null;
  }

  /// ゲーム終了時に呼び出す（インタースティシャル広告表示のトリガー）
  void onGameEnd() {
    showInterstitialAd();
  }

  /// バナー広告を破棄
  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  /// インタースティシャル広告を破棄
  void disposeInterstitial() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  /// すべての広告を破棄
  void dispose() {
    disposeBanner();
    disposeInterstitial();
  }
}
