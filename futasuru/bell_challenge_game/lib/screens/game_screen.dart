import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_settings.dart';
import '../services/sound_service.dart';
import '../services/i18n_service.dart';

enum GamePhase { countdown, playing, result, gameEnd }

enum BellState { safe, danger }

enum PlayerTurn { player, cpu }

enum RallyState { waiting, playerAction, cpuThinking, cpuAction }

class GameScreen extends StatefulWidget {
  final GameSettings gameSettings;
  final VoidCallback onBackToSettings;

  const GameScreen({
    super.key,
    required this.gameSettings,
    required this.onBackToSettings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  GamePhase _gamePhase = GamePhase.countdown;
  BellState _bellState = BellState.safe;
  int _player1Score = 0;
  int _cpuScore = 0;
  int _countdownNumber = 3;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  Timer? _actionTimer;
  PlayerTurn _currentTurn = PlayerTurn.player;
  RallyState _rallyState = RallyState.waiting;
  int _totalGameTime = 0;
  int _remainingTime = 0;
  late AnimationController _bellAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _progressAnimationController;
  late AnimationController _swipeAnimationController;
  late Animation<double> _bellScaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  late Animation<Offset> _swipeAnimation;
  double _actionTimeRemaining = 1.0;
  final SoundService _soundService = SoundService();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _applyGameSettings();
    _initializeAnimations();
    _startGame();
  }

  Future<void> _applyGameSettings() async {
    // GameSettingsの設定をSoundServiceに適用
    try {
      await _soundService.setVibrationEnabled(widget.gameSettings.hapticFeedback);
      await _soundService.setBgmEnabled(widget.gameSettings.bgmEnabled);
      await _soundService.setSeEnabled(widget.gameSettings.soundEffects);
      await _soundService.setBgmVolume(widget.gameSettings.bgmVolume);
      await _soundService.setSeVolume(widget.gameSettings.seVolume);
      print('🎮 GameSettings applied to SoundService');
    } catch (e) {
      print('❌ Error applying GameSettings: $e');
    }
  }

  void _initializeAnimations() {
    _bellAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
      duration: Duration(seconds: widget.gameSettings.selectedDifficulty.timeLimit),
      vsync: this,
    );
    _swipeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bellScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bellAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.linear,
    ));

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimationController.repeat(reverse: true);

    _progressAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _actionTimeRemaining = _progressAnimation.value;
        });
      }
    });
  }

  void _startGame() {
    try {
      // 先にメニューBGMを停止してからゲームBGMを開始
      _soundService.stopBgm();
      // 少し遅延してからゲームBGMを開始
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _soundService.playGameBgm();
        }
      });
    } catch (e) {
      print('Sound service error: $e');
    }
    // ゲーム時間を十分長く設定（10分 = 600秒）
    // スコアベース終了が主で、これは安全装置として機能
    _totalGameTime = 600;
    _remainingTime = _totalGameTime;
    _startCountdown();
  }

  void _startCountdown() {
    if (!mounted) return;

    setState(() {
      _gamePhase = GamePhase.countdown;
      _countdownNumber = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        _soundService.playCountdown();
      } catch (e) {
        print('Sound service error: $e');
      }

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownNumber--;
      });

      if (_countdownNumber <= 0) {
        timer.cancel();
        // 「Go!」を表示してからゲーム開始
        Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            _startRound();
          }
        });
      }
    });
  }

  void _startRound() {
    if (!mounted) return;

    setState(() {
      _gamePhase = GamePhase.playing;
      _bellState = BellState.safe; // 最初は常にペットケージ
      _currentTurn = PlayerTurn.player;
      _rallyState = RallyState.waiting;
    });

    try {
      _soundService.playRoundStart();
    } catch (e) {
      print('Sound service error: $e');
    }

    _startMainGameTimer();
    _startPlayerTurn();
  }

  void _startMainGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingTime--;
      });

      if (_remainingTime <= 0) {
        timer.cancel();
        if (mounted) {
          // 時間切れの場合は現在のスコアで勝敗判定
          print('⏰ Game ended by timeout - Score: $_player1Score - $_cpuScore');
          _endGame();
        }
      }
    });
  }

  void _startPlayerTurn() {
    if (!mounted) {
      print('⚠️ Cannot start player turn - widget not mounted');
      return;
    }

    // 既存のタイマーを安全にキャンセル
    _actionTimer?.cancel();
    _actionTimer = null;

    // アニメーションコントローラーが既に実行中の場合はスキップ
    if (_progressAnimationController.isAnimating) {
      print('⚠️ Animation already running, skipping duplicate turn start');
      return;
    }

    print('🎮 Starting player turn - Phase: $_gamePhase');
    setState(() {
      _rallyState = RallyState.playerAction;
      _actionTimeRemaining = 1.0;
    });
    print('✅ Player turn started - Rally state now: $_rallyState');

    // プログレスバーアニメーション開始
    try {
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    } catch (e) {
      print('Animation controller error: $e');
      return;
    }

    // プレイヤーのアクション制限時間
    _actionTimer = Timer(Duration(seconds: widget.gameSettings.selectedDifficulty.timeLimit), () {
      // 制限時間内にアクションしなかった場合、プレイヤーの負け
      if (mounted && _gamePhase == GamePhase.playing && _rallyState == RallyState.playerAction) {
        _playerLosesRally('timeout');
      }
    });
  }

  void _startCpuTurn() {
    if (mounted) {
      setState(() {
        _currentTurn = PlayerTurn.cpu;
        _rallyState = RallyState.cpuThinking;
      });
    }

    // CPUの思考時間（0.2-0.8秒のランダム）
    final int thinkingTime = 200 + _random.nextInt(600);

    Timer(Duration(milliseconds: thinkingTime), () {
      if (mounted && _gamePhase == GamePhase.playing) {
        _performCpuAction();
      }
    });
  }

  void _performCpuAction() {
    if (mounted) {
      setState(() {
        _rallyState = RallyState.cpuAction;
      });
    }

    if (_bellState == BellState.safe) {
      // ペットケージを受け取った時のCPU行動
      final chance = _random.nextInt(100);

      if (chance < 5) {
        // 5%: そのままペットケージを保持
        _cpuKeepsPetCage();
      } else if (chance < 95) {
        // 90%: ベルに変化させる（上下スワイプ）
        _cpuSendsBeii();
      } else {
        // 5%: 間違えて横スライド
        _cpuMakesWrongMove('horizontalSwipe');
      }
    } else {
      // ベルを受け取った時のCPU行動
      final chance = _random.nextInt(100);

      if (chance < 95) {
        // 95%: ペットケージに変化（左右スワイプ）
        _cpuReturnsToPetCage();
      } else if (chance < 98) {
        // 3%: そのままベルを保持（上下スワイプ）
        _cpuKeepsBell();
      } else if (chance < 99) {
        // 1%: 間違えて上下スワイプ
        _cpuMakesWrongMove('verticalSwipe');
      } else {
        // 1%: 間違えてタップ
        _cpuMakesWrongMove('tap');
      }
    }
  }

  void _cpuKeepsPetCage() {
    // CPUがペットケージを保持（何もしない）
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _gamePhase == GamePhase.playing) {
        _startPlayerTurn();
      }
    });
  }

  void _cpuKeepsBell() {
    // CPUがベルを保持（何もしない）
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _gamePhase == GamePhase.playing) {
        _startPlayerTurn();
      }
    });
  }

  void _cpuSendsBeii() {
    // CPUがベルに変化させる
    if (!mounted) return;

    try {
      _soundService.playSwipe();
    } catch (e) {
      print('Sound service error: $e');
    }

    setState(() {
      _bellState = BellState.danger;
    });

    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _gamePhase == GamePhase.playing) {
        _startPlayerTurn();
      }
    });
  }

  void _cpuReturnsToPetCage() {
    // CPUがベルをペットケージに戻す
    if (!mounted) return;

    try {
      _soundService.playSwipe();
    } catch (e) {
      print('Sound service error: $e');
    }

    setState(() {
      _bellState = BellState.safe;
    });

    Timer(const Duration(milliseconds: 500), () {
      if (mounted && _gamePhase == GamePhase.playing) {
        _startPlayerTurn();
      }
    });
  }

  void _cpuMakesWrongMove(String moveType) {
    // CPUが間違った行動をする（CPUの負け）
    try {
      if (moveType == 'tap') {
        _soundService.playBuzzer();
      } else {
        _soundService.playSwipe();
      }
    } catch (e) {
      print('Sound service error: $e');
    }

    _cpuLosesRally(moveType);
  }

  void _playerWinsRally() {
    setState(() {
      _player1Score++;
    });
    
    // 勝利の音声を再生
    try {
      _soundService.playWin();
    } catch (e) {
      print('Sound service error: $e');
    }
    
    _showResult(true, t('game.correct'));
  }

  void _playerLosesRally(String reason) {
    setState(() {
      _cpuScore++;
    });

    // 負けの音声を再生
    try {
      _soundService.playLose();
    } catch (e) {
      print('Sound service error: $e');
    }

    String message;
    switch (reason) {
      case 'tap':
        message = t('game.bellTapped');
        break;
      case 'timeout':
        message = t('game.timeUp');
        break;
      default:
        message = t('game.wrong');
    }

    _showResult(false, message);
  }

  void _cpuLosesRally(String reason) {
    setState(() {
      _player1Score++;
    });
    
    // 勝利の音声を再生
    try {
      _soundService.playWin();
    } catch (e) {
      print('Sound service error: $e');
    }
    
    _showResult(true, t('game.correct'));
  }

  void _onTap() {
    print('🔘 Tap detected - Phase: $_gamePhase, Rally: $_rallyState');
    if (_gamePhase != GamePhase.playing || _rallyState != RallyState.playerAction) {
      print('⚠️ Tap ignored - invalid game state');
      return;
    }

    _actionTimer?.cancel(); // アクションタイマーをキャンセル

    try {
      _progressAnimationController.stop(); // プログレスバーを停止

      _bellAnimationController.forward().then((_) {
        if (mounted) {
          _bellAnimationController.reverse();
        }
      });
    } catch (e) {
      print('Animation controller error: $e');
    }

    if (_bellState == BellState.safe) {
      // ペットケージをタップ - CPUにペットケージを送る
      try {
        _soundService.playSafeTap();
      } catch (e) {
        print('Sound service error: $e');
      }
      _startCpuTurn(); // ラリー継続
    } else {
      // ベルをタップ（NG - プレイヤーの負け）
      try {
        _soundService.playBuzzer();
      } catch (e) {
        print('Sound service error: $e');
      }
      _playerLosesRally('tap');
    }
  }

  void _onVerticalSwipe() {
    print('↕️ Vertical swipe detected - Phase: $_gamePhase, Rally: $_rallyState, Bell: $_bellState');
    if (_gamePhase != GamePhase.playing || _rallyState != RallyState.playerAction) {
      print('⚠️ Vertical swipe ignored - invalid game state');
      return;
    }

    _actionTimer?.cancel(); // アクションタイマーをキャンセル

    try {
      _progressAnimationController.stop(); // プログレスバーを停止
    } catch (e) {
      print('Animation controller error: $e');
    }

    // 上下スワイプアニメーションを実行
    _performSwipeAnimation(Offset(0, -50), () {
      if (_bellState == BellState.safe) {
        // ペットケージを上下スワイプ - CPUにベルを送る
        try {
          _soundService.playSwipe();
        } catch (e) {
          print('Sound service error: $e');
        }
        setState(() {
          _bellState = BellState.danger;
        });
        _startCpuTurn();
      } else {
        // ベル表示時の上下スワイプ（NG - プレイヤーの負け）
        try {
          _soundService.playBuzzer();
        } catch (e) {
          print('Sound service error: $e');
        }
        _playerLosesRally('wrong');
      }
    });
  }

  void _onHorizontalSwipe() {
    print('↔️ Horizontal swipe detected - Phase: $_gamePhase, Rally: $_rallyState, Bell: $_bellState');
    if (_gamePhase != GamePhase.playing || _rallyState != RallyState.playerAction) {
      print('⚠️ Horizontal swipe ignored - invalid game state');
      return;
    }

    _actionTimer?.cancel(); // アクションタイマーをキャンセル

    try {
      _progressAnimationController.stop(); // プログレスバーを停止
    } catch (e) {
      print('Animation controller error: $e');
    }

    // 左右スワイプアニメーションを実行
    _performSwipeAnimation(Offset(50, 0), () {
      if (_bellState == BellState.danger) {
        // ベルを左右スワイプ（正解アクション - ペットケージに戻してCPUにターンを渡す）
        try {
          _soundService.playSwipe();
        } catch (e) {
          print('Sound service error: $e');
        }
        setState(() {
          _bellState = BellState.safe;
        });
        _startCpuTurn(); // ラリー継続
      } else {
        // ペットケージを左右スワイプ（NG - プレイヤーの負け）
        try {
          _soundService.playBuzzer();
        } catch (e) {
          print('Sound service error: $e');
        }
        _playerLosesRally('wrong');
      }
    });
  }

  void _performSwipeAnimation(Offset direction, VoidCallback onComplete) {
    // スワイプアニメーションを設定
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: direction,
    ).animate(CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeInOut,
    ));

    // アニメーション開始
    _swipeAnimationController.forward().then((_) {
      // アニメーション完了後、元の位置に戻す
      _swipeAnimationController.reverse().then((_) {
        // コールバック実行
        onComplete();
      });
    });
  }

  void _showResult(bool success, String message) {
    if (!mounted) {
      print('⚠️ Cannot show result - widget not mounted');
      return;
    }

    print('🏆 Showing result: $success, message: $message');

    // 全てのタイマーを停止
    _actionTimer?.cancel();
    _actionTimer = null;

    try {
      _progressAnimationController.stop();
      _progressAnimationController.reset();
    } catch (e) {
      print('Animation controller error: $e');
    }

    setState(() {
      _gamePhase = GamePhase.result;
    });

    // 3秒後に次のラウンドまたはゲーム終了
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      if (_player1Score >= widget.gameSettings.maxWins ||
          _cpuScore >= widget.gameSettings.maxWins) {
        print('🏆 Game ended by score - Player: $_player1Score, CPU: $_cpuScore, MaxWins: ${widget.gameSettings.maxWins}');
        _endGame();
      } else {
        print('🎮 Continuing game - Player: $_player1Score, CPU: $_cpuScore, Need: ${widget.gameSettings.maxWins} wins');
        _startRound(); // カウントダウンをスキップしてすぐに次のラウンド開始
      }
    });
  }

  void _endGame() {
    if (!mounted) {
      print('⚠️ Cannot end game - widget not mounted');
      return;
    }

    print('🏁 Ending game - Final score: $_player1Score - $_cpuScore');

    // 全てのタイマーを停止
    _gameTimer?.cancel();
    _gameTimer = null;
    _actionTimer?.cancel();
    _actionTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;

    try {
      _progressAnimationController.stop();
      _progressAnimationController.reset();
    } catch (e) {
      print('Animation controller error: $e');
    }

    // ゲーム終了時にBGMを停止
    try {
      _soundService.stopBgm();
    } catch (e) {
      print('Sound service error stopping BGM: $e');
    }

    setState(() {
      _gamePhase = GamePhase.gameEnd;
    });

    try {
      if (_player1Score > _cpuScore) {
        _soundService.playClear();
      } else {
        _soundService.playLose();
      }
    } catch (e) {
      print('Sound service error: $e');
    }
  }

  void _restartGame() {
    // ゲームをリセット
    setState(() {
      _gamePhase = GamePhase.countdown;
      _bellState = BellState.safe;
      _player1Score = 0;
      _cpuScore = 0;
      _countdownNumber = 3;
      _currentTurn = PlayerTurn.player;
      _rallyState = RallyState.waiting;
      _actionTimeRemaining = 1.0;
    });

    // タイマーをリセット
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _actionTimer?.cancel();
    _progressAnimationController.reset();

    // 全時間をリセット（10分 = 600秒の安全装置）
    _totalGameTime = 600;
    _remainingTime = _totalGameTime;

    // ゲーム開始
    _startCountdown();
  }

  Color _getBellColor() {
    switch (_bellState) {
      case BellState.safe:
        return Colors.green;
      case BellState.danger:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    print('🗑️ Disposing GameScreen - cleaning up resources');

    // Cancel all timers first to prevent memory leaks
    try {
      _gameTimer?.cancel();
      _gameTimer = null;
    } catch (e) {
      print('Error canceling game timer: $e');
    }

    try {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    } catch (e) {
      print('Error canceling countdown timer: $e');
    }

    try {
      _actionTimer?.cancel();
      _actionTimer = null;
    } catch (e) {
      print('Error canceling action timer: $e');
    }

    // Stop all animations safely
    try {
      if (_bellAnimationController.isAnimating) {
        _bellAnimationController.stop();
      }
      _bellAnimationController.dispose();
    } catch (e) {
      print('Error disposing bell animation controller: $e');
    }

    try {
      if (_pulseAnimationController.isAnimating) {
        _pulseAnimationController.stop();
      }
      _pulseAnimationController.dispose();
    } catch (e) {
      print('Error disposing pulse animation controller: $e');
    }

    try {
      if (_progressAnimationController.isAnimating) {
        _progressAnimationController.stop();
      }
      _progressAnimationController.dispose();
    } catch (e) {
      print('Error disposing progress animation controller: $e');
    }

    try {
      if (_swipeAnimationController.isAnimating) {
        _swipeAnimationController.stop();
      }
      _swipeAnimationController.dispose();
    } catch (e) {
      print('Error disposing swipe animation controller: $e');
    }

    // Stop background music safely
    try {
      _soundService.stopBgm();
    } catch (e) {
      print('Error stopping BGM: $e');
    }

    print('✅ GameScreen disposed successfully');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // スコア表示
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScoreCard(t('game.player'), _player1Score, Colors.blue),
                  Column(
                    children: [
                      Text(
                        t('game.remainingRounds', params: {'count': _getRemainingRounds()}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        t('game.score', params: {
                          'player1': _player1Score,
                          'player2': _cpuScore,
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _buildScoreCard(t('game.cpu'), _cpuScore, Colors.orange),
                ],
              ),
            ),

            // メインゲームエリア
            Expanded(
              child: Center(
                child: _buildGameContent(),
              ),
            ),

            // 操作説明（常時表示）
            _buildInstructionsPanel(),

            // 戻るボタン
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  try {
                    _soundService.playButtonClick();
                    _soundService.stopBgm();
                  } catch (e) {
                    print('Sound service error: $e');
                  }
                  widget.onBackToSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  t('game.backToSettings'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(String playerName, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            playerName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            score.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    switch (_gamePhase) {
      case GamePhase.countdown:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('game.countdown'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _countdownNumber > 0 ? _countdownNumber.toString() : t('game.go'),
              style: TextStyle(
                color: _countdownNumber > 0 ? Colors.orange : Colors.green,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );

      case GamePhase.playing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ラリー状態表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getRallyStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 15),
            // プレイヤーターン時のプログレスバー
            if (_rallyState == RallyState.playerAction)
              Container(
                width: 200,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _actionTimeRemaining,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _actionTimeRemaining > 0.3 ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 30),
            // ゲームアイコン
            GestureDetector(
              onTap: _onTap,
              onVerticalDragEnd: (details) {
                // 上下スワイプ検出
                try {
                  final velocity = details.velocity.pixelsPerSecond;
                  print('↕️ Vertical drag end - velocity: ${velocity.dy}, Phase: $_gamePhase, Rally: $_rallyState');
                  if (velocity.dy.abs() > 50) { // さらに速度を下げる
                    print('↕️ Vertical swipe detected with velocity: ${velocity.dy}');
                    _onVerticalSwipe();
                  } else {
                    print('↕️ Vertical swipe too slow: ${velocity.dy.abs()} < 50');
                  }
                } catch (e) {
                  print('Vertical gesture handling error: $e');
                }
              },
              onVerticalDragUpdate: (details) {
                // ドラッグ中のログも追加
                print('↕️ Vertical drag update - delta: ${details.delta.dy}');
              },
              onHorizontalDragEnd: (details) {
                // 左右スワイプ検出
                try {
                  final velocity = details.velocity.pixelsPerSecond;
                  print('↔️ Horizontal drag end - velocity: ${velocity.dx}, Phase: $_gamePhase, Rally: $_rallyState');
                  if (velocity.dx.abs() > 100) { // 最小速度を下げる
                    print('↔️ Horizontal swipe detected with velocity: ${velocity.dx}');
                    _onHorizontalSwipe();
                  } else {
                    print('↔️ Horizontal swipe too slow: ${velocity.dx.abs()} < 100');
                  }
                } catch (e) {
                  print('Horizontal gesture handling error: $e');
                }
              },
              child: AnimatedBuilder(
                animation: _bellScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bellScaleAnimation.value,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _bellState == BellState.danger
                              ? _pulseAnimation.value
                              : 1.0,
                          child: AnimatedBuilder(
                            animation: _swipeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: _swipeAnimation.value,
                                child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getBellColor(),
                          boxShadow: [
                            BoxShadow(
                              color: _getBellColor().withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: _bellState == BellState.safe
                            ? Center(
                                child: Image.asset(
                                  'assets/images/cage.png',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Center(
                                child: Image.asset(
                                  'assets/images/bell.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case GamePhase.result:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _player1Score > _cpuScore ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 80,
              color: _player1Score > _cpuScore ? Colors.yellow : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              _getResultMessage(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case GamePhase.gameEnd:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('game.gameEnd'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _player1Score > _cpuScore ? t('game.youWin') : t('game.youLose'),
              style: TextStyle(
                color: _player1Score > _cpuScore ? Colors.green : Colors.red,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              '${_player1Score} - ${_cpuScore}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    try {
                      _soundService.playButtonClick();
                    } catch (e) {
                      print('Sound service error: $e');
                    }
                    _restartGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t('game.playAgain'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    try {
                      _soundService.playButtonClick();
                      _soundService.stopBgm();
                    } catch (e) {
                      print('Sound service error: $e');
                    }
                    widget.onBackToSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t('game.backToSettings'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  String _getResultMessage() {
    if (_gamePhase == GamePhase.result) {
      return t('game.nextRound');
    }
    return '';
  }

  String _getRallyStatusText() {
    switch (_rallyState) {
      case RallyState.waiting:
        return t('game.rallyStart');
      case RallyState.playerAction:
        return t('game.yourTurn');
      case RallyState.cpuThinking:
        return t('game.cpuThinking');
      case RallyState.cpuAction:
        return t('game.cpuAction');
    }
  }

  int _getRemainingRounds() {
    // 最大勝利数から現在の最高スコアを引いた値が残りラウンド数
    final int maxScore = max(_player1Score, _cpuScore);
    return widget.gameSettings.maxWins - maxScore;
  }

  Widget _buildInstructionsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 緑の箱（ペットケージ）の操作説明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 緑の箱アイコン
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/cage.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // タップOK
                Column(
                  children: [
                    Text(
                      t('game.tapOk'),
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '👆',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                // 上下矢印で赤ベル変換
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.green,
                          size: 14,
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.green,
                          size: 14,
                        ),
                      ],
                    ),
                    Text(
                      t('game.toBell'),
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // 左右矢印でスワイプNG
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.keyboard_arrow_left,
                          color: Colors.red,
                          size: 14,
                        ),
                        Icon(
                          Icons.keyboard_arrow_right,
                          color: Colors.red,
                          size: 14,
                        ),
                      ],
                    ),
                    Text(
                      t('game.swipeNg'),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 赤のベルの操作説明
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 赤のベルアイコン
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/bell.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // タップNG
                Column(
                  children: [
                    Text(
                      t('game.tapNg'),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '👆',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                // 上下矢印でスワイプNG
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.red,
                          size: 14,
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.red,
                          size: 14,
                        ),
                      ],
                    ),
                    Text(
                      t('game.swipeNg'),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // 左右矢印で緑の箱変換
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.keyboard_arrow_left,
                          color: Colors.green,
                          size: 14,
                        ),
                        Icon(
                          Icons.keyboard_arrow_right,
                          color: Colors.green,
                          size: 14,
                        ),
                      ],
                    ),
                    Text(
                      t('game.toCage'),
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}