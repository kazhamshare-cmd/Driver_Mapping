import 'package:flutter/material.dart';
import 'dart:async';
import '../models/room_models.dart';
import '../models/game_models.dart' as game_models;
import '../services/room_service.dart';
import '../services/game_logic_service.dart';
import '../services/speech_service.dart';
import '../services/sound_service.dart';

/// オンラインゲームプレイ画面
class OnlineGamePlayScreen extends StatefulWidget {
  final Room room;

  const OnlineGamePlayScreen({
    super.key,
    required this.room,
  });

  @override
  State<OnlineGamePlayScreen> createState() => _OnlineGamePlayScreenState();
}

class _OnlineGamePlayScreenState extends State<OnlineGamePlayScreen> with TickerProviderStateMixin {
  final RoomService _roomService = RoomService.instance;
  final GameLogicService _gameLogic = GameLogicService.instance;
  final SpeechService _speech = SpeechService.instance;
  final SoundService _sound = SoundService.instance;

  late Stream<Room?> _roomStream;
  Room? _currentRoom;
  
  // ゲーム状態
  game_models.GameState _gameState = game_models.GameState.ready;
  bool _isListening = false;
  String _recognizedText = '';
  String _intermediateText = '';
  double _answerSeconds = 8.0;
  Timer? _answerTimer;
  
  // 現在のプレイヤー
  int _currentPlayerIndex = 0;
  game_models.Challenge? _currentChallenge;

  @override
  void initState() {
    super.initState();
    _currentRoom = widget.room;
    _roomStream = _roomService.getRoom(widget.room.id);
    _setupSpeechService();
    _startGame();
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
        print('🎤 音声認識開始');
      }
    };

    _speech.onListeningStopped = () {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        print('🎤 音声認識停止');

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

  void _startGame() {
    setState(() {
      _gameState = game_models.GameState.ready;
    });
    
    // 新しいお題を生成
    _currentChallenge = _gameLogic.generateChallenge();
    
    // 最初のプレイヤーのターン開始
    _startPlayerTurn();
  }

  void _startPlayerTurn() {
    if (_currentRoom == null) return;
    
    setState(() {
      _gameState = game_models.GameState.answering;
    });
    
    final currentPlayer = _currentRoom!.players[_currentPlayerIndex];
    print('🎮 ${currentPlayer.name}のターン開始');
    
    // 音声認識を開始
    _speech.startListening(timeout: const Duration(seconds: 8));
    
    // タイマー開始
    _answerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _answerSeconds -= 0.1;
        if (_answerSeconds <= 0) {
          _answerSeconds = 0;
        }
      });
      
      if (_answerSeconds <= 0) {
        timer.cancel();
        _speech.stopListening();
        _judgeAnswer();
      }
    });
  }

  void _judgeAnswer() async {
    if (_currentRoom == null || _currentChallenge == null) return;
    
    setState(() {
      _gameState = game_models.GameState.judging;
    });
    
    print('⚖️ 回答を判定: "$_recognizedText"');
    
    final result = _gameLogic.validateAnswer(
      word: _recognizedText,
      challenge: _currentChallenge!,
      usedWords: {}, // オンラインでは使用済み単語の管理は別途必要
    );
    
    final isValid = result['isValid'] as bool;
    final points = result['points'] as int;
    final message = result['message'] as String;
    
    if (isValid) {
      _sound.playCorrect();
      print('✅ 正解: $message');
    } else {
      _sound.playIncorrect();
      print('❌ 不正解: $message');
    }
    
    setState(() {
      _gameState = game_models.GameState.showResult;
    });
    
    // 5秒待ってから次のプレイヤーに移る
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _moveToNextPlayer();
      }
    });
  }

  void _moveToNextPlayer() {
    if (_currentRoom == null) return;
    
    setState(() {
      _gameState = game_models.GameState.waitingForOpponent;
    });
    
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _currentRoom!.players.length;
    
    // 新しいお題を生成
    _currentChallenge = _gameLogic.generateChallenge();
    
    // 次のプレイヤーのターン開始
    _answerSeconds = 8.0;
    _recognizedText = '';
    _intermediateText = '';
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startPlayerTurn();
      }
    });
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

  @override
  void dispose() {
    _answerTimer?.cancel();
    _speech.stopListening();
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
        return _buildReadyState();
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

  Widget _buildAnsweringState() {
    final currentPlayer = _currentRoom!.players[_currentPlayerIndex];
    
    return Column(
      children: [
        // お題表示
        _buildChallengeCard(),
        
        const SizedBox(height: 20),
        
        // 現在のプレイヤー表示
        _buildCurrentPlayerCard(currentPlayer),
        
        const SizedBox(height: 20),
        
        // 音声認識結果表示
        _buildSpeechResultCard(),
        
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag, size: 80, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'ゲーム終了！',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
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
    if (_currentChallenge == null) return const SizedBox.shrink();
    
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
              _buildCharacterCircle(_currentChallenge!.head),
              const SizedBox(width: 16),
              const Text(
                'で始まり',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 16),
              _buildCharacterCircle(_currentChallenge!.tail),
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
    final isCurrentPlayer = _currentRoom!.players.indexOf(player) == _currentPlayerIndex;
    
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
