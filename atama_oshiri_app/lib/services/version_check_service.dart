import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._internal();
  factory VersionCheckService() => _instance;
  VersionCheckService._internal();

  FirebaseRemoteConfig? _remoteConfig;

  /// バージョンチェックサービスを初期化
  Future<void> initialize() async {
    _remoteConfig = FirebaseRemoteConfig.instance;
    
    // Remote Configの設定（タイムアウトを短縮）
    await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 3),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // デフォルト値を設定
    await _remoteConfig!.setDefaults({
      'min_required_version': '1.0.0',
      'force_update_message': 'アプリを最新バージョンにアップデートしてください。',
      'update_url_ios': 'https://apps.apple.com/app/id1234567890',
      'update_url_android': 'https://play.google.com/store/apps/details?id=co.jp.b19.atamaoshiriapp',
    });

    // リモート設定を取得
    await _fetchRemoteConfig();
  }

  /// リモート設定を取得
  Future<void> _fetchRemoteConfig() async {
    try {
      await _remoteConfig!.fetchAndActivate().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏰ Remote Config取得タイムアウト（デフォルト値を使用）');
          return false;
        },
      );
      print('✅ Remote Config取得完了');
    } catch (e) {
      print('⚠️ Remote Config取得エラー: $e');
    }
  }

  /// 現在のアプリバージョンを取得
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('❌ バージョン取得エラー: $e');
      return '1.0.0';
    }
  }

  /// 最新の必須バージョンを取得
  String getMinRequiredVersion() {
    return _remoteConfig?.getString('min_required_version') ?? '1.0.0';
  }

  /// 強制アップデートメッセージを取得
  String getForceUpdateMessage() {
    return _remoteConfig?.getString('force_update_message') ?? 
           'アプリを最新バージョンにアップデートしてください。';
  }

  /// アップデートURLを取得（プラットフォーム別）
  String getUpdateUrl() {
    // プラットフォーム判定は実際の実装時に追加
    return _remoteConfig?.getString('update_url_ios') ?? 
           'https://apps.apple.com/app/id1234567890';
  }

  /// バージョンチェックを実行
  Future<VersionCheckResult> checkVersion() async {
    try {
      final currentVersion = await getCurrentVersion();
      final minRequiredVersion = getMinRequiredVersion();
      
      print('🔍 バージョンチェック: 現在=$currentVersion, 必須=$minRequiredVersion');
      
      final isUpdateRequired = _compareVersions(currentVersion, minRequiredVersion) < 0;
      
      return VersionCheckResult(
        currentVersion: currentVersion,
        minRequiredVersion: minRequiredVersion,
        isUpdateRequired: isUpdateRequired,
        updateMessage: isUpdateRequired ? getForceUpdateMessage() : '',
        updateUrl: isUpdateRequired ? getUpdateUrl() : '',
      );
    } catch (e) {
      print('❌ バージョンチェックエラー: $e');
      return VersionCheckResult(
        currentVersion: '1.0.0',
        minRequiredVersion: '1.0.0',
        isUpdateRequired: false,
        updateMessage: '',
        updateUrl: '',
        error: e.toString(),
      );
    }
  }

  /// バージョン比較（現在 < 必須 の場合にアップデート必要）
  int _compareVersions(String current, String required) {
    final currentParts = current.split('.').map(int.parse).toList();
    final requiredParts = required.split('.').map(int.parse).toList();
    
    // パディングして同じ長さにする
    while (currentParts.length < requiredParts.length) {
      currentParts.add(0);
    }
    while (requiredParts.length < currentParts.length) {
      requiredParts.add(0);
    }
    
    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] < requiredParts[i]) return -1;
      if (currentParts[i] > requiredParts[i]) return 1;
    }
    
    return 0;
  }

  /// アプリストアを開く
  Future<void> openAppStore() async {
    try {
      final url = getUpdateUrl();
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ アプリストアを開きました: $url');
      } else {
        print('❌ アプリストアを開けませんでした: $url');
      }
    } catch (e) {
      print('❌ アプリストア起動エラー: $e');
    }
  }
}

/// バージョンチェック結果
class VersionCheckResult {
  final String currentVersion;
  final String minRequiredVersion;
  final bool isUpdateRequired;
  final String updateMessage;
  final String updateUrl;
  final String? error;

  VersionCheckResult({
    required this.currentVersion,
    required this.minRequiredVersion,
    required this.isUpdateRequired,
    required this.updateMessage,
    required this.updateUrl,
    this.error,
  });

  bool get hasError => error != null;
}

