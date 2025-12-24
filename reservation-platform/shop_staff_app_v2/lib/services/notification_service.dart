import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知音タイプ
enum NotificationSoundType {
  /// シンプル（落ち着いた雰囲気向け）
  chime('chime', 'シンプル', '落ち着いた雰囲気のお店向け'),

  /// わかりやすい（一般的な飲食店向け）
  bell('bell', 'わかりやすい', '一般的な飲食店向け'),

  /// 音声（賑やかな店舗向け）
  alert('alert', '音声', '賑やかな店舗・注文が多い店向け');

  final String fileName;
  final String displayName;
  final String description;

  const NotificationSoundType(this.fileName, this.displayName, this.description);

  /// ファイル名から取得
  static NotificationSoundType fromFileName(String? fileName) {
    return NotificationSoundType.values.firstWhere(
      (type) => type.fileName == fileName,
      orElse: () => NotificationSoundType.bell,
    );
  }
}

/// 通知サービス（音とバイブレーション）
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String _soundTypeKey = 'notification_sound_type';
  static const String _soundEnabledKey = 'notification_sound_enabled';
  static const String _vibrationEnabledKey = 'notification_vibration_enabled';

  /// 現在選択中の通知音タイプ
  NotificationSoundType _currentSoundType = NotificationSoundType.bell;

  /// 通知音が有効か
  bool _soundEnabled = true;

  /// バイブレーションが有効か
  bool _vibrationEnabled = true;

  /// 初期化（設定を読み込み）
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 通知音タイプを読み込み
      final soundTypeFileName = prefs.getString(_soundTypeKey);
      _currentSoundType = NotificationSoundType.fromFileName(soundTypeFileName);

      // 通知音有効/無効を読み込み
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;

      // バイブレーション有効/無効を読み込み
      _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;

      print('🔔 NotificationService 初期化完了');
      print('   - 通知音: ${_currentSoundType.displayName}');
      print('   - 音声: ${_soundEnabled ? "ON" : "OFF"}');
      print('   - バイブ: ${_vibrationEnabled ? "ON" : "OFF"}');
    } catch (e) {
      print('❌ NotificationService 初期化エラー: $e');
    }
  }

  /// 現在の通知音タイプを取得
  NotificationSoundType get currentSoundType => _currentSoundType;

  /// 通知音が有効かを取得
  bool get soundEnabled => _soundEnabled;

  /// バイブレーションが有効かを取得
  bool get vibrationEnabled => _vibrationEnabled;

  /// 通知音タイプを設定
  Future<void> setSoundType(NotificationSoundType type) async {
    _currentSoundType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundTypeKey, type.fileName);
    print('🔔 通知音を変更: ${type.displayName}');
  }

  /// 通知音の有効/無効を設定
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
    print('🔔 通知音: ${enabled ? "ON" : "OFF"}');
  }

  /// バイブレーションの有効/無効を設定
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
    print('📳 バイブレーション: ${enabled ? "ON" : "OFF"}');
  }

  /// 新規注文通知（音 + バイブレーション）
  Future<void> notifyNewOrder() async {
    print('🔔 NotificationService.notifyNewOrder() 開始');
    try {
      final futures = <Future>[];

      if (_soundEnabled) {
        futures.add(_playNotificationSound());
      }

      if (_vibrationEnabled) {
        futures.add(_vibrate());
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      print('✅ NotificationService.notifyNewOrder() 完了');
    } catch (e) {
      print('❌ NotificationService.notifyNewOrder() エラー: $e');
      rethrow;
    }
  }

  /// 通知音を再生
  Future<void> _playNotificationSound() async {
    try {
      print('🔊 通知音再生を試行: ${_currentSoundType.displayName}');

      // 選択された通知音ファイルを再生
      final soundFile = 'sounds/${_currentSoundType.fileName}.mp3';

      try {
        await _audioPlayer.play(AssetSource(soundFile));
        print('✅ 通知音再生成功: $soundFile');
        return;
      } catch (e) {
        print('⚠️ 音声ファイル再生エラー ($soundFile): $e');
      }

      // フォールバック: デフォルトのnotification.mp3を試す
      try {
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
        print('✅ フォールバック通知音再生成功');
        return;
      } catch (e) {
        print('⚠️ フォールバック音声ファイルも見つかりません: $e');
      }

      // 音声ファイルがない場合はシステムサウンドで代替
      print('ℹ️ システムサウンドの代わりにHaptic Feedbackで対応');
    } catch (e) {
      print('❌ 通知音再生エラー: $e');
    }
  }

  /// 通知音をプレビュー再生
  Future<void> playPreview(NotificationSoundType type) async {
    try {
      print('🔊 プレビュー再生: ${type.displayName}');

      final soundFile = 'sounds/${type.fileName}.mp3';

      try {
        await _audioPlayer.play(AssetSource(soundFile));
        print('✅ プレビュー再生成功: $soundFile');
        return;
      } catch (e) {
        print('⚠️ プレビュー再生エラー ($soundFile): $e');
      }

      // フォールバック
      try {
        await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
        print('✅ フォールバックプレビュー再生成功');
      } catch (e) {
        print('⚠️ フォールバック音声ファイルも見つかりません: $e');
        // Haptic Feedbackで代替
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('❌ プレビュー再生エラー: $e');
    }
  }

  /// バイブレーションを実行
  Future<void> _vibrate() async {
    try {
      print('📳 バイブレーション開始');
      // iOSのハプティックフィードバック
      await HapticFeedback.heavyImpact();

      // 複数回振動
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      print('✅ バイブレーション完了');
    } catch (e) {
      print('❌ バイブレーションエラー: $e');
    }
  }

  /// リソースを解放
  void dispose() {
    _audioPlayer.dispose();
  }
}
