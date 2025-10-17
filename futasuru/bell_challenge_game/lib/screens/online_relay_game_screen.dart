import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/online_room.dart';
import '../services/online_service.dart';
import '../services/sound_service.dart';
import '../services/i18n_service.dart';

enum GamePhase { countdown, playing, result, gameEnd }
enum BellState { safe, danger }

class OnlineRelayGameScreen extends StatefulWidget {
  final OnlineRoom room;
  final VoidCallback onBackToLobby;

  const OnlineRelayGameScreen({
    super.key,
    required this.room,
    required this.onBackToLobby,
  });

  @override
  State<OnlineRelayGameScreen> createState() => _OnlineRelayGameScreenState();
}

class _OnlineRelayGameScreenState extends State<OnlineRelayGameScreen>
    with TickerProviderStateMixin {
  final OnlineService _onlineService = OnlineService();
  final SoundService _soundService = SoundService();

  StreamSubscription<OnlineRoom>? _roomSubscription;
  OnlineRoom? _currentRoom;

  GamePhase _gamePhase = GamePhase.countdown;
  BellState _bellState = BellState.safe;
  int _countdownNumber = 3;
  Timer? _countdownTimer;
  Timer? _actionTimer;
  int _totalTurns = 0; // 総ターン数

  late AnimationController _bellAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _bellScaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  double _actionTimeRemaining = 1.0;

  bool _isMyTurn = false;
  String _currentPlayerName = '';
  bool _isProcessingTimeout = false; // タイムアウト処理中フラグ
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _watchRoom();
    _startGame();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _countdownTimer?.cancel();
    _actionTimer?.cancel();
    _bellAnimationController.dispose();
    _pulseAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
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
      duration: Duration(seconds: widget.room.gameSettings.selectedDifficulty.timeLimit),
      vsync: this,
    );

    _bellScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bellAnimationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.linear),
    );

    _pulseAnimationController.repeat(reverse: true);

    _progressAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _actionTimeRemaining = _progressAnimation.value;
        });
      }
    });
  }

  void _watchRoom() {
    _roomSubscription = _onlineService.watchRoom(widget.room.id).listen(
      (room) {
        if (mounted) {
          setState(() {
            _currentRoom = room;
            _updateGameState();
          });
        }
      },
      onError: (error) {
        print('Room watch error: $error');
      },
    );
  }

  void _updateGameState() {
    if (_currentRoom == null) return;

    // 現在のプレイヤーを確認
    final currentPlayer = _currentRoom!.currentPlayer;
    if (currentPlayer != null) {
      final wasMyTurn = _isMyTurn;
      _currentPlayerName = currentPlayer.name;
      _isMyTurn = currentPlayer.id == _onlineService.currentPlayerId;

      // ターンが変わった場合のみ処理を実行
      if (_gamePhase == GamePhase.playing && wasMyTurn != _isMyTurn) {
        // 前のターンのタイマーをキャンセル
        _actionTimer?.cancel();
        
        // タイムアウトフラグをリセット
        _isProcessingTimeout = false;
        
        if (_isMyTurn) {
          // 自分のターンになった場合
          _startPlayerTurn();
        } else {
          // 相手のターンになった場合、監視タイマーを開始
          _startOpponentTurnMonitor();
        }
      }
    }
  }

  void _startGame() {
    setState(() {
      _gamePhase = GamePhase.countdown;
      _countdownNumber = 3;
      _totalTurns = 0;
    });

    _soundService.playGameBgm();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _soundService.playCountdown();

      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownNumber--;
      });

      if (_countdownNumber <= 0) {
        timer.cancel();
        Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            _startRound();
          }
        });
      }
    });
  }

  Future<void> _startRound() async {
    setState(() {
      _gamePhase = GamePhase.playing;
      _bellState = BellState.safe; // 最初は安全な状態
    });

    _soundService.playRoundStart();

    // ホストのみがターンを初期化（重複実行を防ぐため）
    if (_currentRoom != null && _currentRoom!.hostId == _onlineService.currentPlayerId) {
      await _onlineService.initializeGameTurn(widget.room.id);
    }
    
    // ゲーム開始後、現在のターンに応じて監視を開始
    // （_updateGameStateで処理されるが、念のため明示的に呼び出す）
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && _gamePhase == GamePhase.playing) {
      if (_isMyTurn) {
        _startPlayerTurn();
      } else {
        _startOpponentTurnMonitor();
      }
    }
  }

  void _startPlayerTurn() {
    if (!mounted || !_isMyTurn) return;
    
    // 既にタイマーが動いている場合は重複起動を防ぐ
    if (_actionTimer != null && _actionTimer!.isActive) {
      print('⚠️ ターンは既に開始されています');
      return;
    }

    _actionTimer?.cancel();

    setState(() {
      _actionTimeRemaining = 1.0;
    });

    try {
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    } catch (e) {
      print('Animation error: $e');
    }

    // プレイヤーの制限時間
    _actionTimer = Timer(
      Duration(seconds: widget.room.gameSettings.selectedDifficulty.timeLimit),
      () {
        if (mounted && _isMyTurn) {
          _playerTimeout();
        }
      },
    );
    
    print('🎯 自分のターン開始');
  }

  void _startOpponentTurnMonitor() {
    if (!mounted || _isMyTurn) return;

    _actionTimer?.cancel();

    setState(() {
      _actionTimeRemaining = 1.0;
    });

    try {
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    } catch (e) {
      print('Animation error: $e');
    }

    // 相手のターンの制限時間（少し余裕を持たせる）
    final monitorTimeout = widget.room.gameSettings.selectedDifficulty.timeLimit + 2;
    
    _actionTimer = Timer(
      Duration(seconds: monitorTimeout),
      () {
        if (mounted && !_isMyTurn && _gamePhase == GamePhase.playing) {
          print('⏰ 相手のターンがタイムアウトしました');
          _opponentTimeout();
        }
      },
    );
    
    print('👀 相手のターンを監視中: $_currentPlayerName');
  }

  void _opponentTimeout() async {
    // 既に処理中の場合はスキップ（重複実行防止）
    if (_isProcessingTimeout) {
      print('⚠️ タイムアウト処理は既に実行中です');
      return;
    }
    
    _isProcessingTimeout = true;
    
    // 相手がタイムアウトした場合、サーバー側でも処理を行う
    // ただし、既に次のターンに進んでいる可能性があるため、
    // 現在のターンインデックスを確認してから処理を行う
    final currentTurnIndex = _currentRoom?.turnIndex ?? 0;
    
    try {
      // タイムアウト時はスコア変更なしで次のターンに進む
      await _onlineService.nextTurn(widget.room.id, currentTurnIndex);
      
      print('⏰ 相手のタイムアウトにより次のターンへ');
    } catch (e) {
      print('❌ 相手タイムアウト処理エラー: $e');
    } finally {
      // 少し遅延してフラグをリセット（連続実行を防ぐ）
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _isProcessingTimeout = false;
        }
      });
    }
  }

  void _playerTimeout() {
    // タイムアウト時は負け扱い
    _handlePlayerAction('timeout', false);
  }

  void _onTap() {
    if (!_isMyTurn || _gamePhase != GamePhase.playing) return;

    _bellAnimationController.forward().then((_) {
      if (mounted) {
        _bellAnimationController.reverse();
      }
    });

    if (_bellState == BellState.safe) {
      // ペットケージをタップ（正解）
      _soundService.playSafeTap();
      _handlePlayerAction('tap', true);
    } else {
      // ベルをタップ（間違い）
      _soundService.playBuzzer();
      _handlePlayerAction('tap', false);
    }
  }

  void _onVerticalSwipe() {
    if (!_isMyTurn || _gamePhase != GamePhase.playing) return;

    if (_bellState == BellState.safe) {
      // ペットケージを上下スワイプ（ベルに変化させる）
      _soundService.playSwipe();
      setState(() {
        _bellState = BellState.danger;
      });
      _handlePlayerAction('vertical_swipe', true);
    } else {
      // ベル表示時の上下スワイプ（間違い）
      _soundService.playBuzzer();
      _handlePlayerAction('vertical_swipe', false);
    }
  }

  void _onHorizontalSwipe() {
    if (!_isMyTurn || _gamePhase != GamePhase.playing) return;

    if (_bellState == BellState.danger) {
      // ベルを左右スワイプ（正解）
      _soundService.playSafeTap();
      setState(() {
        _bellState = BellState.safe;
      });
      _handlePlayerAction('horizontal_swipe', true);
    } else {
      // ペットケージを左右スワイプ（間違い）
      _soundService.playBuzzer();
      _handlePlayerAction('horizontal_swipe', false);
    }
  }

  Future<void> _handlePlayerAction(String action, bool success) async {
    // 自分のターンでない場合は何もしない
    if (!_isMyTurn) return;
    
    _actionTimer?.cancel();
    _progressAnimationController.stop();

    // ローカル状態を更新して、重複したアクションを防ぐ
    setState(() {
      _isMyTurn = false;
      _totalTurns++;
    });

    // 現在のターンインデックスを保存（トランザクション用）
    final currentTurnIndex = _currentRoom?.turnIndex ?? 0;

    // アクションをサーバーに送信
    try {
      await _onlineService.sendPlayerAction(
        roomId: widget.room.id,
        playerId: _onlineService.currentPlayerId,
        action: action,
        success: success,
      );

      if (success) {
        // 成功した場合、スコアを加算
        final currentPlayer = _currentRoom?.players.where((p) => p.id == _onlineService.currentPlayerId).firstOrNull;
        if (currentPlayer != null) {
          final newScore = currentPlayer.score + 1;
          await _onlineService.updatePlayerScore(
            widget.room.id,
            _onlineService.currentPlayerId,
            newScore,
          );
          
          // 勝利判定：maxWinsに到達したか確認
          if (newScore >= widget.room.gameSettings.maxWins) {
            _soundService.playWin();
            if (mounted) {
              setState(() {
                _gamePhase = GamePhase.gameEnd;
              });
            }
            return;
          }
        }
        
        // まだゲームが続く場合、次のプレイヤーに交代
        await _onlineService.nextTurn(widget.room.id, currentTurnIndex);
      } else {
        // 失敗した場合、次のプレイヤーに交代（スコアは変更なし）
        _soundService.playBuzzer();
        await _onlineService.nextTurn(widget.room.id, currentTurnIndex);
      }
    } catch (e) {
      print('❌ アクション処理エラー: $e');
    }
  }

  void _endGame() {
    _actionTimer?.cancel();
    _progressAnimationController.stop();
    _soundService.stopBgm();

    setState(() {
      _gamePhase = GamePhase.gameEnd;
    });
  }

  Color _getBellColor() {
    switch (_bellState) {
      case BellState.safe:
        return Colors.green;
      case BellState.danger:
        return Colors.red;
    }
  }

  String t(String key, {Map<String, dynamic>? params}) {
    return I18nService.translate(key, params: params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // ゲーム情報ヘッダー
            _buildGameHeader(),

            // メインゲームエリア
            Expanded(
              child: Center(
                child: _buildGameContent(),
              ),
            ),

            // 操作説明（プレイ中のみ）
            if (_gamePhase == GamePhase.playing && _isMyTurn)
              _buildInstructionsPanel(),

            // プレイヤー一覧
            _buildPlayersPanel(),

            // 戻るボタン
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            _currentRoom?.name ?? 'リレーゲーム',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '目標: ${widget.room.gameSettings.maxWins}勝 | ターン: $_totalTurns',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_gamePhase == GamePhase.playing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _isMyTurn ? 'あなたのターン!' : '$_currentPlayerNameのターン',
                style: TextStyle(
                  color: _isMyTurn ? Colors.green : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
            const Text(
              'ゲーム開始',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _countdownNumber > 0 ? _countdownNumber.toString() : 'START!',
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
            // プレイヤーターン時のプログレスバー
            if (_isMyTurn)
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
              onTap: _isMyTurn ? _onTap : null,
              onVerticalDragEnd: _isMyTurn ? (details) {
                final velocity = details.velocity.pixelsPerSecond;
                if (velocity.dy.abs() > 300) {
                  _onVerticalSwipe();
                }
              } : null,
              onHorizontalDragEnd: _isMyTurn ? (details) {
                final velocity = details.velocity.pixelsPerSecond;
                if (velocity.dx.abs() > 300) {
                  _onHorizontalSwipe();
                }
              } : null,
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
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getBellColor(),
                              boxShadow: [
                                BoxShadow(
                                  color: _getBellColor().withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: _bellState == BellState.safe
                                ? Center(
                                    child: Image.asset(
                                      'assets/images/cage.png',
                                      width: 120,
                                      height: 120,
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
            ),
          ],
        );

      case GamePhase.gameEnd:
        // 最高スコアのプレイヤーを見つける
        final sortedPlayers = [...?_currentRoom?.players]
          ..sort((a, b) => b.score.compareTo(a.score));
        final winner = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
        final isWinner = winner?.id == _onlineService.currentPlayerId;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ゲーム終了!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (winner != null) ...[
              Text(
                isWinner ? 'あなたの勝利!' : '${winner.name} の勝利!',
                style: TextStyle(
                  color: isWinner ? Colors.amber : Colors.green,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${winner.score} 勝',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ] else ...[
              const Text(
                'お疲れさまでした!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              '総ターン数: $_totalTurns',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: widget.onBackToLobby,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text(
                'ロビーに戻る',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInstructionsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.green.withOpacity(0.3)),
        ),
      ),
      child: const Column(
        children: [
          Text(
            'あなたのターンです！',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '🐾 タップ/上下スワイプ OK | 🔔 左右スワイプ OK',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersPanel() {
    if (_currentRoom == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'プレイヤー',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _currentRoom!.players.map((player) {
              final isCurrentTurn = player.id == _currentRoom!.currentPlayerId;
              final isMe = player.id == _onlineService.currentPlayerId;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentTurn
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentTurn ? Colors.orange : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${player.name} ${isMe ? "(You)" : ""} (${player.score})',
                  style: TextStyle(
                    color: isCurrentTurn ? Colors.orange : Colors.white,
                    fontSize: 12,
                    fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: () {
          _soundService.playButtonClick();
          _soundService.stopBgm();
          widget.onBackToLobby();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'ロビーに戻る',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}