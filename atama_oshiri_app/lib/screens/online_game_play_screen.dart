import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/room_models.dart';
import '../models/game_models.dart' as game_models;
import '../services/room_service.dart';
import '../services/game_logic_service.dart';
import '../services/speech_service.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';
import 'online_game_screen.dart';

/// オンラインゲームプレイ画面
class OnlineGamePlayScreen extends StatefulWidget {
  final Room room;
  final String currentPlayerId;

  const OnlineGamePlayScreen({
    super.key,
    required this.room,
    required this.currentPlayerId,
  });

  @override
  State<OnlineGamePlayScreen> createState() => _OnlineGamePlayScreenState();
}

class _OnlineGamePlayScreenState extends State<OnlineGamePlayScreen> with TickerProviderStateMixin {
  final RoomService _roomService = RoomService.instance;
  final GameLogicService _gameLogic = GameLogicService.instance;
  final SpeechService _speech = SpeechService.instance;
  final SoundService _sound = SoundService.instance;
  final AdService _ad = AdService.instance;

  late Stream<Room?> _roomStream;
  Room? _currentRoom;
  StreamSubscription<Room?>? _roomSubscription;
  
  // ゲーム状態
  game_models.GameState _gameState = game_models.GameState.ready;
  bool _isListening = false;
  String _recognizedText = '';
  String _intermediateText = '';
  double _countdownSeconds = 7.8;
  double _answerSeconds = 8.0;
  double _timerProgress = 0.0;
  Timer? _countdownTimer;
  Timer? _answerTimer;
  
  // 現在のお題（シンプルなターン制）
  game_models.Challenge? _currentChallenge;
  int _currentTurnIndex = 0; // 現在のターン

  // 判定結果
  bool _isCorrect = false;
  int _earnedPoints = 0;
  String _resultMessage = '';

  // 最後に処理したターンインデックス（重複防止）
  int? _lastProcessedTurnIndex;
  
  // ゲーム開始フラグ（重複実行防止）
  bool _gameStarted = false;
  
  // ターンチェック実行中フラグ（重複実行防止）
  bool _isCheckingTurn = false;
  
  // 最後にFirestoreを更新した時刻
  DateTime? _lastFirestoreUpdate;

  /// Firestoreの更新頻度を制限するヘルパーメソッド
  bool _canUpdateFirestore() {
    if (_lastFirestoreUpdate == null) return true;
    
    final now = DateTime.now();
    final timeSinceLastUpdate = now.difference(_lastFirestoreUpdate!);
    
    // 500ms以内の連続更新は制限
    return timeSinceLastUpdate.inMilliseconds > 500;
  }

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _roomStream = _roomService.getRoom(widget.room.id);
    _setupSpeechService();
    _setupRoomListener();

    // ホストの場合のみゲームを開始（お題を生成してFirestoreに保存）
    // ゲストはFirestoreの更新を監視して自動的にゲームが開始される
    if (_isHost()) {
      print('🎮 [オンライン] initState: ホストとしてゲーム開始を呼び出します');
      _startGame();
    }
  }

  bool _isHost() {
    final currentPlayer = _currentRoom?.players.firstWhere(
      (p) => p.id == widget.currentPlayerId,
      orElse: () => _currentRoom!.players.first,
    );
    return currentPlayer?.isHost ?? false;
  }

  void _setupRoomListener() {
    // ルームの変更を監視
    _roomSubscription = _roomStream.listen((room) {
      if (!mounted) return;

      if (room == null) {
        // ルームが削除された場合
        print('🚪 ルームが削除されました');
        Navigator.pop(context);
        Navigator.pop(context);
        return;
      }

      final previousStatus = _currentRoom?.status;
      final previousChallenge = _currentRoom?.currentChallenge;
      _currentRoom = room;

      // お題が設定されている場合、お題を更新
      if (room.currentChallenge != null) {
        _currentChallenge = room.currentChallenge;
      }

      // ゲーム中の場合、プレイヤーインデックスが変更された場合のみチェック
      if (room.status == RoomStatus.playing) {
        final previousPlayerIndex = _currentRoom?.currentPlayerIndex;
        final currentPlayerIndex = room.currentPlayerIndex;
        
        // プレイヤーインデックスが変更された場合のみチェック
        if (previousPlayerIndex != currentPlayerIndex) {
          print('🔄 [オンライン] プレイヤーインデックスが変更されました: $previousPlayerIndex → $currentPlayerIndex');
          // 少し遅延させてからチェック（無限ループ防止）
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _checkMyTurn();
            }
          });
        }
      }

      // ステータスが playing から finished に変わった場合（ゲーム終了）
      if (previousStatus == RoomStatus.playing && room.status == RoomStatus.finished) {
        print('🏁 ゲームが終了しました（Firestore検知）');
        if (mounted && _gameState != game_models.GameState.gameOver) {
          setState(() {
            _gameState = game_models.GameState.gameOver;
          });
          print('✅ ゲームオーバー画面に遷移');
        }
      }

      // ステータスが finished から waiting に変わった場合（もう一度遊ぶ）
      if (previousStatus == RoomStatus.finished && room.status == RoomStatus.waiting) {
        print('🔄 ルームがリセットされました。準備画面に戻ります。');
        // ルームから退室せず、準備画面に戻る
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(
              room: room,
              currentPlayerId: widget.currentPlayerId,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ホストがルームをリセットしました'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // プレイヤーステータスの変更を監視（誰かが脱落した場合）
      if (room.status == RoomStatus.playing) {
        final activePlayers = room.activePlayers;
        if (activePlayers.length <= 1 && _gameState != game_models.GameState.gameOver) {
          print('🏁 アクティブプレイヤーが1人以下になりました');
          // ゲーム終了処理は既に実行されているはずだが、念のため確認
          if (room.status != RoomStatus.finished) {
            print('⚠️ ルームステータスがまだfinishedではありません');
          }
        }
      }
    });
  }

  /// 自分のターンかチェックし、待機中なら新しいターンを開始
  void _checkMyTurn() {
    // 重複実行を防ぐ
    if (_isCheckingTurn) {
      print('⚠️ [オンライン] ターンチェックが既に実行中です');
      return;
    }
    
    if (_currentRoom == null || _currentChallenge == null) return;

    _isCheckingTurn = true;
    
    try {
      final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];
      final isMyTurn = currentPlayer.id == widget.currentPlayerId;
      final currentTurnIndex = _currentRoom!.currentPlayerIndex;

      // 自分のターンで、かつ待機中またはready状態で、まだ処理していないターンの場合のみ開始
      if (isMyTurn &&
          (_gameState == game_models.GameState.ready || _gameState == game_models.GameState.waitingForOpponent) &&
          _lastProcessedTurnIndex != currentTurnIndex) {
        print('🎮 [オンライン] 自分のターン検知 (インデックス: $currentTurnIndex, 前回: $_lastProcessedTurnIndex)');

        // 即座にインデックスを更新して重複実行を防ぐ
        _lastProcessedTurnIndex = currentTurnIndex;

        // ターン開始
        _startPlayerTurn();
      } else if (!isMyTurn) {
        // 他人のターンになったら、強制的に待機状態に戻す
        if (_gameState != game_models.GameState.waitingForOpponent) {
          print('🔄 [オンライン] 他のプレイヤーのターンになったので待機状態に戻ります');
          setState(() {
            _gameState = game_models.GameState.waitingForOpponent;
          });
        }
      } else {
        // デバッグ用：なぜターンが開始されないかをログ出力
        print('🔍 [オンライン] ターン開始条件を満たしていません: isMyTurn=$isMyTurn, gameState=$_gameState, lastProcessed=$_lastProcessedTurnIndex, current=$currentTurnIndex');
      }
    } finally {
      _isCheckingTurn = false;
    }
  }

  void _setupSpeechService() {
    _speech.onResult = (text) {
      if (mounted && _gameState == game_models.GameState.answering) {
        setState(() {
          _recognizedText = text;
        });
        print('🎤 音声認識結果（リアルタイム）: $_recognizedText');
      }
    };

    _speech.onListeningStarted = () {
      if (mounted) {
        setState(() {
          _isListening = true;
        });
        print('🎤 マイク起動: UIを「音声認識中」に更新');
      }
    };

    _speech.onListeningStopped = () {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        print('🎤 マイク停止: UIを「認識停止」に更新');

        // 音声認識が早期に停止した場合、再開する（タイマーがまだ残っている場合）
        if (_gameState == game_models.GameState.answering && _answerSeconds > 3.0) {
          print('⚠️ 音声認識が早期停止 - 再開します (残り時間: ${_answerSeconds.toStringAsFixed(1)}秒)');
          _restartListening();
        }
      }
    };

    _speech.onError = (error) {
      print('❌ 音声認識エラー: $error');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    };
  }

  void _startGame() async {
    print('🎮 [オンライン] _startGame()が呼ばれました - _gameStarted: $_gameStarted');
    
    // 重複実行を防ぐ
    if (_gameStarted) {
      print('⚠️ [オンライン] ゲームは既に開始済みです');
      return;
    }
    
    _gameStarted = true;
    print('🎮 [オンライン] ゲーム開始処理を実行します');
    
    setState(() {
      _gameState = game_models.GameState.ready;
    });
    
    // 新しいお題を生成
    final newChallenge = _gameLogic.generateChallenge();
    _currentChallenge = newChallenge;

    // お題をFirestoreに保存
    if (_currentRoom != null) {
      final updatedRoom = Room(
        id: _currentRoom!.id,
        name: _currentRoom!.name,
        hostName: _currentRoom!.hostName,
        password: _currentRoom!.password,
        createdAt: _currentRoom!.createdAt,
        updatedAt: DateTime.now(),
        players: _currentRoom!.players,
        status: _currentRoom!.status,
        maxPlayers: _currentRoom!.maxPlayers,
        currentPlayerIndex: _currentRoom!.currentPlayerIndex,
        usedWords: [], // ゲーム開始時は空
        currentChallenge: newChallenge, // 最初のお題を設定
      );

      await _roomService.updateRoom(updatedRoom);
      print('🎲 [オンライン/ホスト] 最初のお題を設定: 頭=${newChallenge.head}, お尻=${newChallenge.tail}');

      // お題設定後、自分のターンをチェック
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkMyTurn();
        }
      });
    }
  }

  void _startPlayerTurn() {
    if (_currentRoom == null) return;
    
    final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];
    print('🎮 [オンライン] ${currentPlayer.name}のターン開始 (インデックス: ${_currentRoom!.currentPlayerIndex})');

    // 音声認識リソースを解放
    _speech.stopListening();
    _speech.cancel();

    // カウントダウン開始（ready状態を使用）
    setState(() {
      _gameState = game_models.GameState.ready;
      _countdownSeconds = 7.8;
      _timerProgress = 0.0;
      _recognizedText = '';
      _isListening = false;
    });

    // カウントダウン音を再生
    _sound.playCountdown10sec();

    const double incrementPerTick = 1 / 78; // 7.8秒 = 78 * 0.1秒
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds -= 0.1;
        _timerProgress += incrementPerTick;

        if (_countdownSeconds <= 0) {
          _countdownSeconds = 0;
          _timerProgress = 1.0;
        }
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _startAnswering();
      }
    });
  }

  void _startAnswering() {
    if (_currentRoom == null) return;

    // 現在のターンのプレイヤーを取得
    final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];
    final isMyTurn = currentPlayer.id == widget.currentPlayerId;

    setState(() {
      _gameState = game_models.GameState.answering;
      _answerSeconds = 8.0;
      _timerProgress = 0.0;
      _recognizedText = '';
      // _isListeningはonListeningStartedコールバックで更新される
    });

    // 自分のターンの場合のみ音声認識を開始
    if (isMyTurn) {
      print('🎤 自分のターンです - 音声認識を開始します');
      // _isListeningの更新はonListeningStartedで行われる
    _speech.startListening(timeout: const Duration(seconds: 8));
    } else {
      print('👀 他のプレイヤーのターンです - 観戦モード');
    }
    
    const double incrementPerTick = 1 / 80; // 8秒 = 80 * 0.1秒
    _answerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _answerSeconds -= 0.1;
        _timerProgress += incrementPerTick;

        if (_answerSeconds <= 0) {
          _answerSeconds = 0;
          _timerProgress = 1.0;
        }
      });
      
      if (_answerSeconds <= 0) {
        timer.cancel();
        _speech.stopListening();
        _sound.vibrate();

        // 最終認識結果を待つために300ms遅延
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
        _judgeAnswer();
          }
        });
      }
    });
  }

  void _judgeAnswer() async {
    if (_currentRoom == null || _currentChallenge == null) return;
    
    setState(() {
      _gameState = game_models.GameState.judging;
    });
    
    print('⚖️ 回答を判定: "$_recognizedText"');

    // Roomから使用済み単語とお題を取得
    final usedWords = Set<String>.from(_currentRoom?.usedWords ?? []);
    final challenge = _currentRoom?.currentChallenge ?? _currentChallenge!;
    
    final result = _gameLogic.validateAnswer(
      word: _recognizedText,
      challenge: challenge,
      usedWords: usedWords,
    );
    
    final isValid = result['isValid'] as bool;
    final points = result['points'] as int;
    final message = result['message'] as String;

    setState(() {
      _isCorrect = isValid;
      _earnedPoints = points;
      _resultMessage = message;
    });
    
    if (isValid) {
      // 正解処理
      _sound.playCorrect();
      print('✅ 正解: $message');

      // 使用済み単語に追加してFirestoreを更新
      final newUsedWords = List<String>.from(_currentRoom!.usedWords)..add(_recognizedText);

      final updatedRoom = Room(
        id: _currentRoom!.id,
        name: _currentRoom!.name,
        hostName: _currentRoom!.hostName,
        password: _currentRoom!.password,
        createdAt: _currentRoom!.createdAt,
        updatedAt: DateTime.now(),
        players: _currentRoom!.players,
        status: _currentRoom!.status,
        maxPlayers: _currentRoom!.maxPlayers,
        currentPlayerIndex: _currentRoom!.currentPlayerIndex,
        usedWords: newUsedWords,
        currentChallenge: _currentRoom!.currentChallenge,
      );

      await _roomService.updateRoom(updatedRoom);
      print('📝 使用済み単語を追加: $_recognizedText (合計: ${newUsedWords.length}個)');
    
    setState(() {
      _gameState = game_models.GameState.showResult;
    });
    
      // 正解したので次のプレイヤーに移る
      // 2秒待ってから次のプレイヤーに移る（毎ターン新しいお題を生成）
      Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _moveToNextPlayer();
      }
    });
    } else {
      // 不正解処理
      _sound.playIncorrect();
      print('❌ 不正解: $message');

      // 現在のプレイヤーを脱落させる
      await _eliminateCurrentPlayer(message);
    }
  }

  Future<void> _moveToNextPlayer() async {
    if (_currentRoom == null) return;
    
    setState(() {
      _gameState = game_models.GameState.waitingForOpponent;
    });
    
    // 次のアクティブなプレイヤーを探す
    int nextIndex = (_currentRoom!.currentPlayerIndex + 1) % _currentRoom!.players.length;
    int attempts = 0;
    while (_currentRoom!.players[nextIndex].status != PlayerStatus.playing && attempts < _currentRoom!.players.length) {
      nextIndex = (nextIndex + 1) % _currentRoom!.players.length;
      attempts++;
    }
    
    // 新しいお題を生成
    final newChallenge = _gameLogic.generateChallenge();
    _currentChallenge = newChallenge;

    // Firestoreのルームを更新して、次のプレイヤーインデックス、新しいお題、使用済み単語をリセット
    final updatedRoom = Room(
      id: _currentRoom!.id,
      name: _currentRoom!.name,
      hostName: _currentRoom!.hostName,
      password: _currentRoom!.password,
      createdAt: _currentRoom!.createdAt,
      updatedAt: DateTime.now(),
      players: _currentRoom!.players,
      status: _currentRoom!.status,
      maxPlayers: _currentRoom!.maxPlayers,
      currentPlayerIndex: nextIndex, // 次のプレイヤーに更新
      usedWords: [], // 新しいお題なので使用済み単語をリセット
      currentChallenge: newChallenge, // 新しいお題を設定
    );

    await _roomService.updateRoom(updatedRoom);
    print('▶️ [オンライン] 次のプレイヤーに移動: インデックス$nextIndex');
    print('🎲 [オンライン] 新しいお題: 頭=${newChallenge.head}, お尻=${newChallenge.tail}');

    // Firestoreの更新により、_setupRoomListener()がトリガーされ、
    // 全プレイヤーが自動的に新しいターンを開始する
  }

  /// 音声認識を再開する
  Future<void> _restartListening() async {
    if (_gameState != game_models.GameState.answering) return;
    
    // 残り時間が短すぎる場合は再開しない
    if (_answerSeconds <= 2.5) {
      print('⚠️ 残り時間が短すぎるため再開をスキップします (残り時間: ${_answerSeconds.toStringAsFixed(1)}秒)');
      return;
    }
    
    print('🔄 音声認識を再開します');
    
    // 音声認識を停止
    await _speech.stopListening();
    
    // 音声認識結果はリセットしない（言い直しを保持）
    // setState(() {
    //   _recognizedText = '';
    //   _intermediateText = '';
    // });
    
    // 少し待ってから再開
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted && _gameState == game_models.GameState.answering && _answerSeconds > 2.5) {
      // 残り時間を計算
      final remainingSeconds = _answerSeconds.ceil().clamp(2, 8);
      print('🎤 音声認識を再開します（残り時間: ${remainingSeconds}秒）');
      
      // 音声認識を再開
      _speech.startListening(timeout: Duration(seconds: remainingSeconds));
    }
  }

  /// プレイヤーを脱落させる（ルームには残る）
  Future<void> _eliminateCurrentPlayer(String reason) async {
    if (_currentRoom == null) return;

    final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];
    print('💀 ${currentPlayer.name}を脱落させます（ルームには残ります）');

    // Firebaseでプレイヤーのステータスを更新（ルームからは削除しない）
    try {
      final updatedRoom = _currentRoom!.updatePlayerStatus(
        currentPlayer.id,
        PlayerStatus.eliminated,
      );
      await _roomService.updateRoom(updatedRoom);

      // ローカルの _currentRoom も更新
      setState(() {
        _currentRoom = updatedRoom;
      });

      // 脱落ダイアログを表示
      if (mounted) {
        await _showEliminationDialog(currentPlayer, reason);
      }

      // 残りアクティブプレイヤー確認
      final activePlayers = _currentRoom!.activePlayers;
      print('📊 残りアクティブプレイヤー数: ${activePlayers.length}');

      if (activePlayers.length <= 1) {
        // 最後の1人またはそれ以下になった場合はゲーム終了
        print('🏁 ゲーム終了');
        await _endGame();
      } else {
        // まだ複数プレイヤーが残っている場合は次のターンへ
        print('▶️ 次のプレイヤーへ');
        _moveToNextPlayer();
      }
    } catch (e) {
      print('❌ プレイヤー脱落処理エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 脱落ダイアログを表示
  Future<void> _showEliminationDialog(Player player, String reason) async {
    // 回答例を取得
    final examples = _currentChallenge != null
        ? _gameLogic.generateAnswerExamples(_currentChallenge!, limit: 3)
        : <String>[];

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.shade100, Colors.red.shade200],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 脱落アイコン
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cancel,
                  size: 50,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // タイトル
              Text(
                '${player.name}が脱落！',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // 回答内容
              if (_recognizedText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Text(
                    '「$_recognizedText」',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 理由
              Text(
                reason,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),

              // 回答例
              if (examples.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '回答例',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...examples.map((example) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_right, color: Colors.grey.shade600, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  example,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).then((_) {
      // ダイアログが閉じられたら何もしない（呼び出し元で処理）
    }).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // 5秒後に自動的にダイアログを閉じる
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  /// ゲーム終了
  Future<void> _endGame() async {
    if (_currentRoom == null) return;

    try {
      await _sound.playGameOver();

      // Firebaseのルームステータスを終了に更新
      await _roomService.endRoom(_currentRoom!.id);

      // 最新のルーム情報を取得
      final roomDoc = await _roomService.getRoom(_currentRoom!.id).first;
      if (roomDoc != null) {
        setState(() {
          _currentRoom = roomDoc;
        });
      }

      print('🏁 ゲーム終了しました');

      // 2秒待機
      await Future.delayed(const Duration(seconds: 2));

      // 20%の確率でインタースティシャル広告を表示
      if (_ad.isInterstitialAdReady && Random().nextDouble() < 0.2) {
        print('📺 インタースティシャル広告を表示します');
        await _ad.showInterstitialAd(
          onAdClosed: () {
            if (mounted) {
              setState(() {
                _gameState = game_models.GameState.gameOver;
              });
            }
          },
        );
      } else {
        // 広告が表示されない場合は直接ゲームオーバー画面へ
        if (mounted) {
          setState(() {
            _gameState = game_models.GameState.gameOver;
          });
        }
      }
    } catch (e) {
      print('❌ ゲーム終了処理エラー: $e');
      if (mounted) {
        setState(() {
          _gameState = game_models.GameState.gameOver;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _speech.stopListening();
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Room?>(
            stream: _roomStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorScreen(snapshot.error.toString());
              }
              
              if (!snapshot.hasData || snapshot.data == null) {
                return _buildRoomNotFoundScreen();
              }
              
              _currentRoom = snapshot.data!;
              return _buildGameScreen();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    if (_currentRoom == null) return _buildErrorScreen('ルーム情報がありません');
    
    return Column(
      children: [
        // ヘッダー
        _buildHeader(),
        
        // メインコンテンツ
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildGameContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    switch (_gameState) {
      case game_models.GameState.ready:
        // カウントダウン中かどうかで表示を切り替え
        if (_countdownSeconds > 0 && _countdownSeconds < 7.8) {
          return _buildCountdownState();
        } else {
        return _buildReadyState();
        }
      case game_models.GameState.waitingForOpponent:
        return _buildWaitingForOpponentState();
      case game_models.GameState.answering:
        return _buildAnsweringState();
      case game_models.GameState.judging:
        return _buildJudgingState();
      case game_models.GameState.showResult:
        return _buildResultState();
      case game_models.GameState.gameOver:
        return _buildGameOverState();
    }
  }

  Widget _buildReadyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'ゲーム準備中...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForOpponentState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt, size: 80, color: Colors.white),
          SizedBox(height: 20),
          Text(
            '相手のターンです',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          Text(
            '回答を待っています...',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownState() {
    final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];

    return Column(
      children: [
        // お題表示
        _buildChallengeCard(),

        const SizedBox(height: 40),

        // 円形タイマー
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // プログレスサークル
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: _timerProgress,
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              // 時間表示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _countdownSeconds.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '秒',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // 現在のプレイヤー表示
        Text(
          '${currentPlayer.name}のターン',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAnsweringState() {
    final currentPlayer = _currentRoom!.players[_currentRoom!.currentPlayerIndex];
    final isMyTurn = currentPlayer.id == widget.currentPlayerId;
    
    return Column(
      children: [
        // お題表示
        _buildChallengeCard(),
        
        const SizedBox(height: 20),
        
        // 現在のプレイヤー表示
        _buildCurrentPlayerCard(currentPlayer),
        
        const SizedBox(height: 20),
        
        // 自分のターンか観戦中かで表示を切り替え
        if (isMyTurn) ...[
          // 音声認識結果表示（自分のターン）
        _buildSpeechResultCard(),
        ] else ...[
          // 観戦モード表示
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.visibility,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                Text(
                  '${currentPlayer.name}が回答中...',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '観戦モード',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // プレイヤー一覧
        _buildPlayerList(),
      ],
    );
  }

  Widget _buildJudgingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            '判定中...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green),
          SizedBox(height: 20),
          Text(
            '結果表示中...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverState() {
    if (_currentRoom == null) {
    return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // アクティブなプレイヤー（脱落していないプレイヤー）を探す
    final activePlayers = _currentRoom!.activePlayers;
    final winner = activePlayers.isNotEmpty ? activePlayers.first : null;

    // 現在のプレイヤーがホストかどうか
    final currentPlayer = _currentRoom!.players.firstWhere(
      (p) => p.id == widget.room.players.first.id,
      orElse: () => _currentRoom!.players.first,
    );
    final isHost = currentPlayer.isHost;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            // 優勝トロフィー
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    offset: const Offset(0, 8),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 80,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // ゲーム終了
            const Text(
            'ゲーム終了！',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 勝者表示
            if (winner != null) ...[
              const Text(
                '🏆 優勝 🏆',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                winner.name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ] else ...[
              const Text(
                '引き分け',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // 全プレイヤーリスト
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '結果',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._currentRoom!.players.map((player) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              player.status == PlayerStatus.eliminated
                                  ? Icons.cancel
                                  : Icons.emoji_events,
                              color: player.status == PlayerStatus.eliminated
                                  ? Colors.red
                                  : Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                player.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: player.status == PlayerStatus.eliminated
                                      ? Colors.white54
                                      : Colors.white,
                                  decoration: player.status == PlayerStatus.eliminated
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            Text(
                              player.status == PlayerStatus.eliminated ? '脱落' : '生き残り',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: player.status == PlayerStatus.eliminated
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // プレイヤーが自分だけの場合
            if (_currentRoom!.players.length == 1) ...[
              // 参加者がいませんメッセージ
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        '参加者がいません',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // メニューに戻るボタンのみ
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => _backToMenu(),
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'メニューに戻る',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
            ] else if (isHost) ...[
              // ホスト: もう一度遊ぶ と ルーム終了
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => _playAgain(),
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    'もう一度遊ぶ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _endRoom(),
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'ルームを終了',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ゲスト: ルーム退出のみ
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: () => _leaveGame(),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text(
                    'ルームから退出',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _leaveGame(),
            icon: Icon(Icons.arrow_back, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'オンライン対戦',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showGameMenu(),
            icon: Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard() {
    // Firestoreから取得したお題を優先、なければローカルのお題を使用
    final challenge = _currentRoom?.currentChallenge ?? _currentChallenge;
    if (challenge == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'お題',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCharacterCircle(challenge.head),
              const SizedBox(width: 16),
              const Text(
                'で始まり',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 16),
              _buildCharacterCircle(challenge.tail),
              const SizedBox(width: 16),
              const Text(
                'で終わる',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCircle(String character) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.deepPurple.shade400, width: 2),
      ),
      child: Center(
        child: Text(
          character,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlayerCard(Player player) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Text(
            '${player.name}のターン',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade800,
            ),
          ),
          const Spacer(),
          Text(
            '残り時間: ${_answerSeconds.toStringAsFixed(1)}秒',
            style: TextStyle(
              fontSize: 16,
              color: Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            '音声認識結果',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _recognizedText.isEmpty ? '認識中...' : _recognizedText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (_isListening) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '音声認識中...',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    if (_currentRoom == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '参加者',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple.shade700,
            ),
          ),
          const SizedBox(height: 12),
          ..._currentRoom!.players.map((player) => _buildPlayerCard(player)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    final isCurrentPlayer = _currentRoom!.players.indexOf(player) == _currentRoom!.currentPlayerIndex;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? Colors.blue.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentPlayer ? Colors.blue.shade400 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            player.isHost ? Icons.star : Icons.person,
            color: player.isHost ? Colors.amber : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            player.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
              color: isCurrentPlayer ? Colors.blue.shade800 : Colors.black87,
            ),
          ),
          if (isCurrentPlayer) ...[
            const Spacer(),
            Text(
              '回答中',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          Text(
            'エラーが発生しました',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomNotFoundScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.meeting_room_outlined, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text(
            'ルームが見つかりません',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ルームが削除されたか、存在しません',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }

  void _leaveGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ゲームを退出しますか？'),
        content: const Text('ゲームを退出すると、他のプレイヤーに影響します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  /// もう一度遊ぶ（ホストのみ）
  Future<void> _playAgain() async {
    if (_currentRoom == null) return;

    try {
      print('🔄 ルームをリセットしてもう一度遊びます');

      // ルームをリセット
      await _roomService.resetRoom(_currentRoom!.id);

      // 最新のルーム情報を取得
      final roomDoc = await _roomService.getRoom(_currentRoom!.id).first;
      if (roomDoc == null) {
        print('❌ ルームが見つかりません');
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // OnlineGameScreenに戻る
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(
              room: roomDoc,
              currentPlayerId: widget.currentPlayerId,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ルームをリセットしました。再度ゲームを開始してください。'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ リプレイエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ルームを終了（ホストのみ）
  Future<void> _endRoom() async {
    if (_currentRoom == null) return;

    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ルームを終了しますか？'),
        content: const Text('ルームを終了すると、全てのプレイヤーが退出し、ルームが削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('終了', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print('🗑️ ルームと履歴を削除します');

      // ルームと使用済みお題履歴を削除
      await _roomService.deleteRoom(_currentRoom!.id);

      // メニュー画面に戻る
      if (mounted) {
        Navigator.pop(context); // OnlineGamePlayScreenを閉じる
        Navigator.pop(context); // OnlineGameScreenを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ルームを終了しました'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ ルーム終了エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// メニューに戻る（自分だけになった場合）
  Future<void> _backToMenu() async {
    if (_currentRoom == null) return;

    try {
      print('🏠 参加者がいないためメニューに戻ります。ルームと履歴を削除します。');

      // ルームと使用済みお題履歴を削除
      await _roomService.deleteRoom(_currentRoom!.id);

      // メニュー画面に戻る
      if (mounted) {
        Navigator.pop(context); // OnlineGamePlayScreenを閉じる
        Navigator.pop(context); // OnlineGameScreenを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('参加者がいなくなったため、ルームを削除しました'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('❌ メニューに戻るエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGameMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('ゲームを退出'),
              onTap: () {
                Navigator.pop(context);
                _leaveGame();
              },
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('メニューに戻る'),
              onTap: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
