import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// サウンドエフェクト管理サービス
class SoundService {
  static SoundService? _instance;
  static SoundService get instance => _instance ??= SoundService._();

  SoundService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  /// サービスの初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // AudioPlayerの設定
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
      print('✅ SoundService初期化完了');
    } catch (e) {
      print('❌ SoundService初期化エラー: $e');
    }
  }

  /// カウントダウン音を再生（短い効果音）
  Future<void> playCountdown() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 音声ファイルを再生
      await _audioPlayer.play(AssetSource('sounds/countdown.mp3'));
      print('🔊 カウントダウン音を再生');
    } catch (e) {
      print('❌ カウントダウン音の再生エラー: $e');
    }
  }

  /// 10秒カウントダウンBGMを再生
  Future<void> playCountdown10sec() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 10秒BGMを再生
      await _audioPlayer.play(AssetSource('sounds/countdown_10sec.mp3'));
      print('🔊 10秒カウントダウンBGMを再生');
    } catch (e) {
      print('❌ 10秒カウントダウンBGMの再生エラー: $e');
    }
  }

  /// オープニング音楽を再生
  Future<void> playOpening() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 音声ファイルを再生
      await _audioPlayer.play(AssetSource('sounds/opening.mp3'));
      print('🔊 オープニング音楽を再生');
    } catch (e) {
      print('❌ オープニング音楽の再生エラー: $e');
    }
  }

  /// 正解音を再生
  Future<void> playCorrect() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _audioPlayer.play(AssetSource('sounds/correct.mp3'));
      print('効果音再生: sounds/correct.mp3');
    } catch (e) {
      print('❌ 正解音の再生エラー: $e');
    }
  }

  /// 不正解音を再生
  Future<void> playIncorrect() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _audioPlayer.play(AssetSource('sounds/incorrect.mp3'));
      print('効果音再生: sounds/incorrect.mp3');
    } catch (e) {
      print('❌ 不正解音の再生エラー: $e');
    }
  }

  /// ゲームオーバー音を再生
  Future<void> playGameOver() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _audioPlayer.play(AssetSource('sounds/game_over.mp3'));
      print('効果音再生: sounds/game_over.mp3');
    } catch (e) {
      print('❌ ゲームオーバー音の再生エラー: $e');
    }
  }

  /// 音声を停止
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('❌ 音声停止エラー: $e');
    }
  }

  /// バイブレーションを実行（短い振動）
  Future<void> vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 100);
        print('📳 バイブレーション実行');
      }
    } catch (e) {
      print('❌ バイブレーションエラー: $e');
    }
  }

  /// バイブレーションを実行（長い振動）
  Future<void> vibrateLong() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 300);
        print('📳 長いバイブレーション実行');
      }
    } catch (e) {
      print('❌ バイブレーションエラー: $e');
    }
  }

  /// リソースの解放
  void dispose() {
    _audioPlayer.dispose();
  }
}
