import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sePlayer = AudioPlayer();

  bool _bgmEnabled = true;
  bool _seEnabled = true;
  bool _vibrationEnabled = true;
  double _bgmVolume = 0.3;
  double _seVolume = 0.8;
  String? _currentBgm;
  bool _wasPlayingBeforeBackground = false;
  bool _isAppInBackground = false;
  bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_instance._isInitialized) {
      print('🔊 SoundService は既に初期化済みです');
      return;
    }
    
    try {
      await _instance._loadSettings();
      _instance._isInitialized = true;
      print('🔊 SoundService 初期化完了');
    } catch (error) {
      print('🔊 SoundService 初期化エラー: $error');
      _instance._isInitialized = true; // エラーでも初期化完了として扱う
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _bgmEnabled = prefs.getBool('bgm_enabled') ?? true;
    _seEnabled = prefs.getBool('se_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _bgmVolume = prefs.getDouble('bgm_volume') ?? 0.3;
    _seVolume = prefs.getDouble('se_volume') ?? 0.8;

    print('🔸 Settings loaded - BGM: $_bgmEnabled, SE: $_seEnabled, Vibration: $_vibrationEnabled');

    await _bgmPlayer.setVolume(_bgmVolume);
    await _sePlayer.setVolume(_seVolume);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bgm_enabled', _bgmEnabled);
    await prefs.setBool('se_enabled', _seEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setDouble('bgm_volume', _bgmVolume);
    await prefs.setDouble('se_volume', _seVolume);
  }

  bool get bgmEnabled => _bgmEnabled;
  bool get seEnabled => _seEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  double get bgmVolume => _bgmVolume;
  double get seVolume => _seVolume;

  Future<void> toggleBgm() async {
    _bgmEnabled = !_bgmEnabled;
    await _saveSettings();

    if (!_bgmEnabled) {
      await stopBgm();
    }
  }

  Future<void> toggleSe() async {
    _seEnabled = !_seEnabled;
    await _saveSettings();
  }

  Future<void> toggleVibration() async {
    _vibrationEnabled = !_vibrationEnabled;
    await _saveSettings();
  }

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    await _saveSettings();

    if (!_bgmEnabled) {
      await stopBgm();
    }
  }

  Future<void> setSeEnabled(bool enabled) async {
    _seEnabled = enabled;
    await _saveSettings();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    print('🔸 Setting vibration enabled: $enabled');
    _vibrationEnabled = enabled;
    await _saveSettings();
    print('🔸 Vibration setting saved: $_vibrationEnabled');
  }

  Future<void> setBgmVolume(double volume) async {
    _bgmVolume = volume.clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(_bgmVolume);
    await _saveSettings();
  }

  Future<void> setSeVolume(double volume) async {
    _seVolume = volume.clamp(0.0, 1.0);
    await _sePlayer.setVolume(_seVolume);
    await _saveSettings();
  }

  Future<void> playMenuBgm() async {
    await _playBgm('audio/bgm/menu_bgm.mp3');
  }

  Future<void> ensureMenuBgm() async {
    if (!_bgmEnabled || _isAppInBackground) return;

    final targetBgm = 'audio/bgm/menu_bgm.mp3';
    if (_currentBgm == targetBgm) {
      // 既に同じBGMが設定されている場合、再生状態を確認
      final state = _bgmPlayer.state;
      if (state == PlayerState.playing) {
        print('🎵 メニューBGMは既に再生中です');
        return;
      }
    }

    print('🎵 メニューBGMを開始します');
    await playMenuBgm();
  }

  Future<void> playGameBgm() async {
    await _playBgm('audio/bgm/game_bgm.mp3');
  }

  Future<void> playResultBgm() async {
    await _playBgm('audio/bgm/result_bgm.mp3');
  }

  Future<void> _playBgm(String assetPath) async {
    if (!_bgmEnabled || _isAppInBackground) return;

    if (_currentBgm == assetPath) {
      // 既に同じBGMが設定されている場合、再生状態を確認
      final state = _bgmPlayer.state;
      if (state == PlayerState.playing) return;
    }

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(AssetSource(assetPath));
      _currentBgm = assetPath;
      print('🎵 BGM開始: $assetPath');
    } catch (e) {
      print('BGM再生エラー: $e');
    }
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.release);
      _currentBgm = null;
      print('🔇 BGM停止完了');
    } catch (e) {
      print('BGM停止エラー: $e');
    }
  }

  Future<void> playButtonClick() async {
    await _playSe('audio/se/button_click.mp3');
    await _playVibration([50, 0]);
  }

  Future<void> playBuzzer() async {
    await _playSe('audio/se/buzzer.mp3');
    await _playVibration([300, 100, 300, 0]);
  }

  Future<void> playWin() async {
    await _playSe('audio/se/win.mp3');
    await _playVibration([100, 50, 100, 50, 200, 0]);
  }

  Future<void> playLose() async {
    await _playSe('audio/se/lose.mp3');
    await _playVibration([500, 200, 500, 0]);
  }

  Future<void> playSafeTap() async {
    await _playSe('audio/se/safe_tap.mp3');
    await _playVibration([100, 0]);
  }

  Future<void> playSwipe() async {
    await _playSe('audio/se/swipe.mp3');
    await _playVibration([150, 50, 150, 0]);
  }

  Future<void> playCountdown() async {
    await _playSe('audio/se/countdown.mp3');
    await _playVibration([200, 0]);
  }

  Future<void> playRoundStart() async {
    await _playSe('audio/se/round_start.mp3');
    await _playVibration([300, 0]);
  }

  Future<void> playRoomJoin() async {
    await _playSe('audio/se/room_join.mp3');
    await _playVibration([200, 100, 200]);
  }

  Future<void> playClear() async {
    await _playSe('audio/se/clear.mp3');
    await _playVibration([100, 50, 100, 50, 100, 50, 300, 0]);
  }

  Future<void> _playSe(String assetPath) async {
    if (!_seEnabled || _isAppInBackground) return;

    try {
      await _sePlayer.stop();
      await _sePlayer.setReleaseMode(ReleaseMode.stop);
      await _sePlayer.setVolume(_seVolume);
      await _sePlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('SE再生エラー: $e');
    }
  }

  Future<void> _playVibration(List<int> pattern) async {
    print('🔸 Vibration requested - Enabled: $_vibrationEnabled, Background: $_isAppInBackground');
    print('🔸 Platform: ${Platform.operatingSystem}');

    if (!_vibrationEnabled || _isAppInBackground) {
      print('🔸 Vibration skipped - Settings disabled or app in background');
      return;
    }

    // プラットフォームチェック: モバイル端末のみ対応
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('🔸 Vibration not supported on ${Platform.operatingSystem}');
      return;
    }

    try {
      final hasVibrator = await Vibration.hasVibrator();
      print('🔸 Device has vibrator: $hasVibrator');

      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: pattern);
        print('🔸 Vibration executed with pattern: $pattern');
      } else {
        print('🔸 No vibrator available on device');
      }
    } catch (e) {
      print('🔸 振動エラー: $e');
    }
  }

  // アプリライフサイクル管理メソッド
  Future<void> onAppPaused() async {
    print('🔇 アプリがバックグラウンドになりました - 音声を停止');
    _isAppInBackground = true;

    // BGMが再生中かチェック
    final bgmState = _bgmPlayer.state;
    _wasPlayingBeforeBackground = bgmState == PlayerState.playing;

    // すべての音声を停止
    try {
      await _bgmPlayer.pause();
      await _sePlayer.stop();
      print('🔇 BGM一時停止、SE停止完了');
    } catch (e) {
      print('音声停止エラー: $e');
    }
  }

  Future<void> onAppResumed() async {
    print('🔊 アプリがフォアグラウンドに復帰しました');
    _isAppInBackground = false;

    // BGMが再生中だった場合、少し遅延してから再開
    if (_wasPlayingBeforeBackground && _bgmEnabled && _currentBgm != null) {
      print('🎵 BGMを再開します: $_currentBgm');
      // 少し遅延して再開（システムが安定するまで待つ）
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await _bgmPlayer.resume();
        print('✅ BGM再開完了');
      } catch (e) {
        print('BGM再開エラー: $e');
        // エラーの場合は再度設定し直す
        if (_currentBgm != null) {
          await _playBgm(_currentBgm!);
        }
      }
    }
    _wasPlayingBeforeBackground = false;
  }

  Future<void> onAppInactive() async {
    print('📱 アプリが非アクティブ状態になりました');
    // 非アクティブ状態では音声は停止しない（通知などで一時的に非アクティブになる場合があるため）
  }

  void dispose() {
    _bgmPlayer.dispose();
    _sePlayer.dispose();
  }
}