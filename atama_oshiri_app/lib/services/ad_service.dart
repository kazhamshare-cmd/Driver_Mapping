import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob広告サービス
class AdService {
  static AdService? _instance;
  static AdService get instance => _instance ??= AdService._();

  AdService._();

  // iOS AdMob IDs
  static const String _iosAppId = 'ca-app-pub-1116360810482665~3898583331';
  static const String _iosBannerId = 'ca-app-pub-1116360810482665/8117029948';
  static const String _iosInterstitialId = 'ca-app-pub-1116360810482665/6216790762';

  // Android AdMob IDs
  static const String _androidAppId = 'ca-app-pub-1116360810482665~1272419990';
  static const String _androidBannerId = 'ca-app-pub-1116360810482665/9699782341';
  static const String _androidInterstitialId = 'ca-app-pub-1116360810482665/3104893333';

  // テスト用ID（開発時のみ使用）
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  /// AdMobを初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      print('AdMob初期化完了');
    } catch (e) {
      print('AdMob初期化エラー: $e');
    }
  }

  /// バナー広告IDを取得
  String getBannerAdUnitId() {
    if (Platform.isIOS) {
      return _iosBannerId;
    } else if (Platform.isAndroid) {
      return _androidBannerId;
    }
    return _testBannerId;
  }

  /// インタースティシャル広告IDを取得
  String getInterstitialAdUnitId() {
    if (Platform.isIOS) {
      return _iosInterstitialId;
    } else if (Platform.isAndroid) {
      return _androidInterstitialId;
    }
    return _testInterstitialId;
  }

  /// インタースティシャル広告を読み込み
  Future<void> loadInterstitialAd() async {
    try {
      await InterstitialAd.load(
        adUnitId: getInterstitialAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
            print('インタースティシャル広告読み込み完了');
          },
          onAdFailedToLoad: (error) {
            print('インタースティシャル広告読み込み失敗: $error');
            _isInterstitialAdReady = false;
          },
        ),
      );
    } catch (e) {
      print('インタースティシャル広告読み込みエラー: $e');
    }
  }

  /// インタースティシャル広告を表示
  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null && _isInterstitialAdReady) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('インタースティシャル広告表示');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('インタースティシャル広告閉じる');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          // 次の広告を読み込み
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('インタースティシャル広告表示失敗: $error');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
        },
      );

      await _interstitialAd!.show();
    } else {
      print('インタースティシャル広告が準備できていません');
    }
  }

  /// インタースティシャル広告が準備できているかチェック
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// リソースクリーンアップ
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
