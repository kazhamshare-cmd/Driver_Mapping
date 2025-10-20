import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _effectPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _bgmEnabled = true;
  bool _isBgmInitialized = false;

  // 効果音ON/OFF設定
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  // バイブレーションON/OFF設定
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get bgmEnabled => _bgmEnabled;

  // バイブレーション実行
  Future<void> _vibrate({int duration = 100}) async {
    if (!_vibrationEnabled) return;
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(duration: duration);
    }
  }

  // BGM初期化
  Future<void> _initializeBgm() async {
    if (_isBgmInitialized) return;

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.8); // 80%のボリューム
      _isBgmInitialized = true;
    } catch (e) {
      print('Failed to initialize BGM: $e');
    }
  }

  // BGM再生開始
  Future<void> playBgm() async {
    if (!_bgmEnabled) return;

    // 初期化されていない場合は初期化を実行
    if (!_isBgmInitialized) {
      await _initializeBgm();
    }

    try {
      final state = _bgmPlayer.state;
      if (state != PlayerState.playing) {
        await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
      }
    } catch (e) {
      print('Failed to play BGM: $e');
    }
  }

  // BGM停止
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (e) {
      print('Failed to stop BGM: $e');
    }
  }

  // BGM ON/OFF切り替え
  Future<void> toggleBgm() async {
    _bgmEnabled = !_bgmEnabled;
    if (_bgmEnabled) {
      await playBgm();
    } else {
      await stopBgm();
    }
  }

  // ホーム画面用BGM（100%ボリューム）
  Future<void> playBgmFull() async {
    if (!_bgmEnabled) return;

    // 初期化されていない場合は初期化を実行
    if (!_isBgmInitialized) {
      await _initializeBgm();
    }

    try {
      await _bgmPlayer.setVolume(1.0); // 100%のボリューム
      final state = _bgmPlayer.state;
      if (state != PlayerState.playing) {
        await _bgmPlayer.play(AssetSource('sounds/bgm.mp3'));
      }
    } catch (e) {
      print('Failed to play BGM: $e');
    }
  }

  // ゲーム画面用BGM（80%ボリューム）
  Future<void> setBgmVolumeForGame() async {
    try {
      await _bgmPlayer.setVolume(0.8); // 80%のボリューム
    } catch (e) {
      print('Failed to set BGM volume: $e');
    }
  }

  // ゲーム開始音 (1秒)
  Future<void> playGameStart() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/game_start_1s.mp3'));
      } catch (e) {
        print('Failed to play game start sound: $e');
      }
    }
    await _vibrate(duration: 50);
  }

  // 正解音 (1秒)
  Future<void> playCorrect() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/correct_1s.mp3'));
      } catch (e) {
        print('Failed to play correct sound: $e');
      }
    }
    await _vibrate(duration: 200);
  }

  // 不正解音 (1秒)
  Future<void> playIncorrect() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/incorrect_1s.mp3'));
      } catch (e) {
        print('Failed to play incorrect sound: $e');
      }
    }
    await _vibrate(duration: 400);
  }

  // ボタンクリック音 (0.5秒)
  Future<void> playClick() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/click_0.5s.mp3'));
      } catch (e) {
        print('Failed to play click sound: $e');
      }
    }
    await _vibrate(duration: 30);
  }

  // タイムアップ音 (2秒)
  Future<void> playTimeUp() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/time_up_2s.mp3'));
      } catch (e) {
        print('Failed to play time up sound: $e');
      }
    }
    await _vibrate(duration: 500);
  }

  // ゲームオーバー音 (2秒)
  Future<void> playGameOver() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/game_over_2s.mp3'));
      } catch (e) {
        print('Failed to play game over sound: $e');
      }
    }
    await _vibrate(duration: 300);
  }

  // クリア音 (2秒)
  Future<void> playClear() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/clear_2s.mp3'));
      } catch (e) {
        print('Failed to play clear sound: $e');
      }
    }
    await _vibrate(duration: 200);
  }

  // 文字配置音 (0.3秒) - 新規追加
  Future<void> playDrop() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/drop_0.3s.mp3'));
      } catch (e) {
        print('Failed to play drop sound: $e');
      }
    }
    await _vibrate(duration: 20);
  }

  // スタート音 - タイムアタックモード開始時
  Future<void> playStart() async {
    if (_soundEnabled) {
      try {
        await _effectPlayer.stop(); // 前の音を停止
        await _effectPlayer.play(AssetSource('sounds/start.mp3'));
      } catch (e) {
        print('Failed to play start sound: $e');
      }
    }
    await _vibrate(duration: 100);
  }

  // リソース解放
  void dispose() {
    _effectPlayer.dispose();
    _bgmPlayer.dispose();
  }
}
