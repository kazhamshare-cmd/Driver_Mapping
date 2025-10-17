import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_settings.dart';
import '../services/sound_service.dart';
import '../services/simple_room_service.dart';
import '../services/i18n_service.dart';

enum OnlineGamePhase { waiting, countdown, playing, result, gameEnd }

enum BellState { safe, danger }

class OnlineGameScreen extends StatefulWidget {
  final GameSettings gameSettings;
  final String roomId;
  final String playerId;
  final String playerName;
  final VoidCallback onBackToLobby;

  const OnlineGameScreen({
    super.key,
    required this.gameSettings,
    required this.roomId,
    required this.playerId,
    required this.playerName,
    required this.onBackToLobby,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with TickerProviderStateMixin {
  final SimpleRoomService _roomService = SimpleRoomService();

  OnlineGamePhase _gamePhase = OnlineGamePhase.waiting;
  BellState _bellState = BellState.safe;
  Map<String, int> _playerScores = {};
  int _countdownNumber = 3;
  Timer? _gameTimer;
  Timer? _countdownTimer;
  int _remainingTime = 0;
  late AnimationController _bellAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _bellScaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  double _actionTimeRemaining = 1.0;
  final SoundService _soundService = SoundService();
  final Random _random = Random();

  SimpleRoom? _currentRoom;
  StreamSubscription<SimpleRoom?>? _roomSubscription;
  bool _isGameActive = false;
  String? _roundWinner;
  List<String> _players = [];

  // ターン制用の変数
  bool _isMyTurn = false;
  String? _currentTurnPlayerName;

  @override
  void initState() {
    super.initState();
    _applyGameSettings();
    _initializeAnimations();
    _startListeningToRoom();
  }

  Future<void> _applyGameSettings() async {
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
      duration: Duration(seconds: widget.gameSettings.timeLimit),
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
  }

  void _startListeningToRoom() {
    _roomSubscription = _roomService.watchRoom(widget.roomId).listen(
      (room) {
        if (mounted && room != null) {
          setState(() {
            _currentRoom = room;
            _players = room.players.map((p) => p.name).toList();

            // Firebaseからスコアを同期
            _playerScores.clear();
            for (var player in room.players) {
              final score = room.playerScores[player.id] ?? 0;
              _playerScores[player.name] = score;
            }

            // ターン情報を更新
            _updateTurnInfo(room);
          });

          // 2人揃ったらゲーム開始
          if (room.players.length == 2 && !_isGameActive && _gamePhase == OnlineGamePhase.waiting) {
            _startOnlineGame();
          }

          // 準備状態の変化をチェック
          if (_gamePhase == OnlineGamePhase.waiting && _roomService.areAllPlayersReady(room)) {
            _checkAllPlayersReady();
          }

          // ラウンド終了を検知
          if (room.roundEnd && _gamePhase == OnlineGamePhase.playing) {
            print('🏁 ラウンド終了を検知: ${room.roundWinner}');
            _endRound(room.roundWinner ?? '');
          }
        }
      },
      onError: (error) {
        print('🚨 ルーム監視エラー: $error');
      },
    );
  }

  void _updateTurnInfo(SimpleRoom room) {
    if (room.currentTurnPlayerId != null) {
      final currentTurnPlayer = room.players.firstWhere(
        (p) => p.id == room.currentTurnPlayerId,
        orElse: () => SimplePlayer(id: '', name: '', isHost: false, joinedAt: DateTime.now()),
      );

      _currentTurnPlayerName = currentTurnPlayer.name;
      final wasMyTurn = _isMyTurn;
      _isMyTurn = room.currentTurnPlayerId == widget.playerId;
      
      // ベルの状態を同期
      final newBellState = room.bellState == 'danger' ? BellState.danger : BellState.safe;
      if (_bellState != newBellState) {
        setState(() {
          _bellState = newBellState;
        });
      }
      
      // 自分のターンになった場合
      if (!wasMyTurn && _isMyTurn && _gamePhase == OnlineGamePhase.playing) {
        // 既存のタイマーを停止
        _gameTimer?.cancel();
        _gameTimer = null;
        
        // 時間制限をリセット
        setState(() {
          _remainingTime = widget.gameSettings.timeLimit * 10;
        });
        
        _progressAnimationController.reset();
        _progressAnimationController.forward();
        
        // 新しいタイマーを開始
        _startGameTimer();
        
        print('🎮 ターン切り替え - 制限時間: ${widget.gameSettings.timeLimit}秒, 残り時間: $_remainingTime');
      }
    } else {
      _currentTurnPlayerName = null;
      _isMyTurn = false;
    }
  }

  void _startOnlineGame() async {
    if (_isGameActive) return;

    // 既存のタイマーを停止
    _gameTimer?.cancel();
    _gameTimer = null;

    _isGameActive = true;
    print('🎮 オンラインターン制ゲーム開始');

    // ホストがターン初期化
    if (_currentRoom != null && _currentRoom!.players.isNotEmpty) {
      final myPlayer = _currentRoom!.players.firstWhere(
        (player) => player.id == widget.playerId,
        orElse: () => SimplePlayer(id: '', name: '', isHost: false, joinedAt: DateTime.now()),
      );

      if (myPlayer.isHost) {
        await _roomService.initializeTurn(widget.roomId);
      }
    }

    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      _gamePhase = OnlineGamePhase.countdown;
      _countdownNumber = 3;
    });

    // リアルタイム性を高めるため、カウントダウンを高速化（1秒→0.6秒）
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
        _soundService.playCountdown();
      } else {
        timer.cancel();
        _soundService.playRoundStart();
        _startRound();
      }
    });
  }

  void _startRound() {
    // 既存のタイマーを停止
    _gameTimer?.cancel();
    _gameTimer = null;

    setState(() {
      _gamePhase = OnlineGamePhase.playing;
      _bellState = BellState.safe; // 常にペットケージから開始
      _remainingTime = widget.gameSettings.timeLimit * 10; // 100ms単位なので10倍
      _roundWinner = null;
    });

    print('🎮 ラウンド開始 - 制限時間: ${widget.gameSettings.timeLimit}秒, 残り時間: $_remainingTime');

    // プレイヤーのアクション制限時間タイマー（自分のターンの時のみ）
    if (_isMyTurn) {
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    }

    // ゲーム全体の時間タイマーを開始
    _startGameTimer();
  }

  void _startGameTimer() {
    // ゲーム全体の時間タイマー（100msごとに更新）
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_remainingTime <= 0) {
        timer.cancel();
        print('⏰ 制限時間到達 - 残り時間: $_remainingTime, 自分のターン: $_isMyTurn, フェーズ: $_gamePhase');
        // タイムアップ時、自分のターンなら負け判定
        if (_isMyTurn && _gamePhase == OnlineGamePhase.playing) {
          print('⏰ 制限時間経過 - プレイヤー負け');
          // プログレスバーを停止
          _progressAnimationController.stop();
          _playerLosesRound('timeout');
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingTime -= 1; // 100ms単位なので1減らす
            // プログレスバーの更新（自分のターンの時のみ）
            if (_isMyTurn) {
              _actionTimeRemaining = _remainingTime / (widget.gameSettings.timeLimit * 10);
            }
          });
        }
      }
    });
  }

  void _onTap() {
    if (_gamePhase != OnlineGamePhase.playing) return;
    if (!_isMyTurn) return;

    _progressAnimationController.stop();

    _bellAnimationController.forward().then((_) {
      if (mounted) {
        _bellAnimationController.reverse();
      }
    });

    if (_bellState == BellState.safe) {
      // 安全状態でタップ - OK（ラリー継続）
      _soundService.playSafeTap();
      _sendToOpponent(BellState.safe);
    } else {
      // 危険状態でタップ - 負け
      _soundService.playBuzzer();
      _playerLosesRound('tap');
    }
  }

  void _onVerticalSwipe() {
    if (_gamePhase != OnlineGamePhase.playing) return;
    if (!_isMyTurn) return;

    _progressAnimationController.stop();

    if (_bellState == BellState.safe) {
      // 安全状態で上下スワイプ - ベルを危険状態にして相手に送る（ラリー継続）
      _soundService.playSwipe();
      setState(() {
        _bellState = BellState.danger;
      });
      _sendToOpponent(BellState.danger);
    } else {
      // 危険状態で上下スワイプ - 負け
      _soundService.playBuzzer();
      _playerLosesRound('verticalSwipe');
    }
  }

  void _onHorizontalSwipe() {
    if (_gamePhase != OnlineGamePhase.playing) return;
    if (!_isMyTurn) return;

    _progressAnimationController.stop();

    if (_bellState == BellState.danger) {
      // 危険状態で左右スワイプ - 回避成功、ベルを安全状態にして相手に送る（ラリー継続）
      _soundService.playSwipe();
      setState(() {
        _bellState = BellState.safe;
      });
      _sendToOpponent(BellState.safe);
    } else {
      // 安全状態で左右スワイプ - 負け
      _soundService.playBuzzer();
      _playerLosesRound('horizontalSwipe');
    }
  }

  Future<void> _sendToOpponent(BellState newState) async {
    // 相手にターンを送る処理（ベルの状態も同期）
    final bellStateStr = newState == BellState.safe ? 'safe' : 'danger';
    await _roomService.switchTurn(widget.roomId, newBellState: bellStateStr);
  }

  void _playerLosesRound(String reason) async {
    print('💥 プレイヤー負け: $reason, フェーズ: $_gamePhase, 自分のターン: $_isMyTurn');
    
    // ゲームが進行中でない場合は処理しない
    if (_gamePhase != OnlineGamePhase.playing) {
      print('⚠️ ゲームが進行中でないため負け処理をスキップ');
      return;
    }
    
    // 負けの音声を再生
    try {
      _soundService.playLose();
    } catch (e) {
      print('Sound service error: $e');
    }
    
    // プレイヤーが負けた場合、相手（負けていないプレイヤー）のスコアを増やす
    if (_currentRoom != null) {
      // 相手のプレイヤーIDを取得
      final opponent = _currentRoom!.players.firstWhere(
        (p) => p.id != widget.playerId,
        orElse: () => SimplePlayer(
          id: '',
          name: '相手',
          isHost: false,
          joinedAt: DateTime.now()
        ),
      );

      if (opponent.id.isNotEmpty) {
        print('🏆 相手のスコアを増加: ${opponent.name}');
        // Firebaseのスコアを更新（ホストのみ）
        final isHost = _currentRoom!.players.first.id == widget.playerId;
        if (isHost) {
          await _roomService.incrementPlayerScore(widget.roomId, opponent.id);
        }
        // ラウンド終了を全員に通知
        await _notifyRoundEnd(opponent.name);
        _endRound(opponent.name);
      }
    }
  }

  void _endRound(String result) async {
    _gameTimer?.cancel();
    _progressAnimationController.stop();
    _pulseAnimationController.stop();

    setState(() {
      _gamePhase = OnlineGamePhase.result;
      _roundWinner = result;
    });

    // サウンド再生
    if (result == widget.playerName) {
      _soundService.playWin();
    }

    // ゲーム終了判定（Firebaseのスコアを参照）
    bool gameEnded = false;
    if (_currentRoom != null) {
      for (var score in _currentRoom!.playerScores.values) {
        if (score >= widget.gameSettings.maxWins) {
          gameEnded = true;
          break;
        }
      }
    }

    if (gameEnded || (_currentRoom?.currentRound ?? 0) >= widget.gameSettings.maxWins * 2) {
      Timer(const Duration(seconds: 1), () {
        _showGameEndDialog();
      });
    } else {
      // リアルタイム性を高めるため、結果表示時間を短縮（2秒→1秒）
      Timer(const Duration(seconds: 1), () {
        _nextTurn();
      });
    }
  }

  // ラウンド終了を全員に通知（Firebase経由）
  Future<void> _notifyRoundEnd(String winner) async {
    if (_currentRoom != null) {
      // ラウンド終了フラグをFirebaseに設定
      await _roomService.setRoundEnd(widget.roomId, winner);
    }
  }

  void _nextTurn() async {
    // ラウンド終了後は待機状態にして、全員が準備完了するまで待つ
    if (mounted) {
      setState(() {
        _gamePhase = OnlineGamePhase.waiting;
      });
      
      // ホストのみが準備状態をリセット
      if (_currentRoom != null) {
        final myPlayer = _currentRoom!.players.firstWhere(
          (player) => player.id == widget.playerId,
          orElse: () => SimplePlayer(id: '', name: '', isHost: false, joinedAt: DateTime.now()),
        );
        
        if (myPlayer.isHost) {
          // 準備状態をリセット
          await _roomService.resetPlayerReady(widget.roomId);
          
          // ラウンド終了フラグをクリア
          await _roomService.clearRoundEnd(widget.roomId);
        }
      }
      
      _showNextRoundDialog();
    }
  }

  void _showNextRoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a4e),
          title: Text(
            t('online.game.nextRound'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            t('online.game.nextRoundMessage'),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _roomService.setPlayerReady(widget.roomId, widget.playerId, true);
                _checkAllPlayersReady();
              },
              child: Text(
                t('online.game.startNextRound'),
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameEndDialog() {
    setState(() {
      _gamePhase = OnlineGamePhase.gameEnd;
    });

    // 勝者を決定（Firebaseのスコアを使用）
    String winner = t('online.game.draw');
    int maxScore = 0;
    List<String> winners = [];

    if (_currentRoom != null) {
      for (var player in _currentRoom!.players) {
        final score = _currentRoom!.playerScores[player.id] ?? 0;
        if (score > maxScore) {
          maxScore = score;
          winners = [player.name];
        } else if (score == maxScore) {
          winners.add(player.name);
        }
      }
    }

    if (winners.length == 1) {
      winner = winners.first;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a4e),
          title: Text(
            t('game.gameEnd'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winner == t('online.game.draw') ? t('online.game.draw') : t('online.game.opponentVictory', params: {'player': winner}),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ...(_playerScores.entries.map((entry) => Text(
                '${entry.key}: ${t('online.game.wins', params: {'count': entry.value})}',
                style: const TextStyle(color: Colors.white70),
              )).toList()),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startRematch();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(t('online.game.startRematch'), style: const TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onBackToLobby();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(t('online.lobby.backToLobby'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _checkAllPlayersReady() {
    if (_currentRoom != null && _roomService.areAllPlayersReady(_currentRoom!)) {
      // 既にゲームが開始されている場合は重複を防ぐ
      if (_gamePhase == OnlineGamePhase.playing) {
        print('⚠️ 既にゲームが開始されているため、重複開始を回避');
        return;
      }
      
      print('✅ 全プレイヤー準備完了 - 次のラウンドを開始');
      // 既存のタイマーを停止
      _gameTimer?.cancel();
      _gameTimer = null;
      _startRound();
    } else {
      print('⏳ 他のプレイヤーの準備を待機中...');
    }
  }

  void _startRematch() {
    // スコアをリセット
    if (_currentRoom != null) {
      _roomService.resetGame(_currentRoom!.id).then((_) {
        // ゲームを再開
        setState(() {
          _gamePhase = OnlineGamePhase.waiting;
          _playerScores.clear();
          _roundWinner = null;
        });
        _startOnlineGame();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTurnIndicator(),
            _buildScoreBoard(),
            Expanded(
              child: _buildGameArea(),
            ),
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          _soundService.playButtonClick();
          widget.onBackToLobby();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          t('online.lobby.backToLobby'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            t('online.game.turnBasedBell'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('online.game.round', params: {'round': _currentRoom?.currentRound ?? 1}),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _gamePhase == OnlineGamePhase.playing
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _getPhaseText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _isMyTurn ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: _isMyTurn ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isMyTurn ? Icons.touch_app : Icons.visibility,
            color: _isMyTurn ? Colors.blue : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _isMyTurn
                  ? t('online.game.yourTurn')
                  : t('online.game.opponentTurn', params: {'player': _currentTurnPlayerName ?? t('online.game.waiting')}),
              style: TextStyle(
                color: _isMyTurn ? Colors.blue : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _playerScores.entries.map((entry) {
          final playerName = entry.key;
          final score = entry.value;
          final isMe = playerName == widget.playerName;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  playerName,
                  style: TextStyle(
                    color: isMe ? Colors.blue : Colors.white,
                    fontSize: 11,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t('online.game.wins', params: {'count': score}),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGameArea() {
    switch (_gamePhase) {
      case OnlineGamePhase.waiting:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                t('online.game.waitingForPlayers'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );

      case OnlineGamePhase.countdown:
        return Center(
          child: Text(
            _countdownNumber.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 120,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

      case OnlineGamePhase.playing:
        return _buildPlayingArea();

      case OnlineGamePhase.result:
        return _buildResultArea();

      case OnlineGamePhase.gameEnd:
        return Center(
          child: Text(
            t('game.gameEnd'),
            style: const TextStyle(color: Colors.white, fontSize: 24),
          ),
        );

      default:
        return Container();
    }
  }

  Widget _buildPlayingArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // プログレスバー
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _bellState == BellState.danger ? Colors.red : Colors.green,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 30),

        // ベル/ペットケージ（タップ・スワイプ可能）
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
            animation: _bellState == BellState.danger ? _pulseAnimation : _bellScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bellState == BellState.danger
                    ? _pulseAnimation.value
                    : _bellScaleAnimation.value,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _isMyTurn
                        ? (_bellState == BellState.danger ? Colors.red : Colors.green)
                        : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isMyTurn
                            ? (_bellState == BellState.danger ? Colors.red : Colors.green)
                            : Colors.grey)
                            .withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: _bellState == BellState.safe
                      ? Image.asset(
                          'assets/images/cage.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        )
                      : Image.asset(
                          'assets/images/bell.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),
        
        // ゲーム説明
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                _bellState == BellState.safe ? '安全状態（箱の中）' : '危険状態（蓋を取られた）',
                style: TextStyle(
                  color: _bellState == BellState.danger ? Colors.red : Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _bellState == BellState.safe 
                    ? 'タップ: OK\n上下スワイプ: 危険状態に変化\n左右スワイプ: 負け'
                    : '左右スワイプ: 回避成功\n上下スワイプ: 負け\nタップ: 負け',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildResultArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getRoundResultText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('online.game.nextTurnSoon'),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_gamePhase) {
      case OnlineGamePhase.waiting:
        return t('online.game.waiting');
      case OnlineGamePhase.countdown:
        return t('online.game.countdown');
      case OnlineGamePhase.playing:
        return t('online.game.playing');
      case OnlineGamePhase.result:
        return t('online.game.result');
      case OnlineGamePhase.gameEnd:
        return t('online.game.finished');
    }
  }

  String _getRoundResultText() {
    if (_roundWinner == widget.playerName) {
      return t('online.game.victory');
    } else if (_roundWinner == 'フライング') {
      return 'Flying Start!';
    } else if (_roundWinner != null) {
      return t('online.game.opponentVictory', params: {'player': _roundWinner!});
    }
    return t('online.game.result');
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _countdownTimer?.cancel();
    _bellAnimationController.dispose();
    _pulseAnimationController.dispose();
    _progressAnimationController.dispose();
    _roomSubscription?.cancel();
    super.dispose();
  }
}