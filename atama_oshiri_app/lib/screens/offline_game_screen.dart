import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_models.dart';
import '../services/game_logic_service.dart';
import '../services/speech_service.dart';
import '../services/sound_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

// ゲーム状態の列挙型
enum GameState {
  ready,       // 準備完了
  countdown,   // カウントダウン中
  answering,   // 回答中（音声認識）
  judging,     // 判定中
  showResult,  // 結果表示中
  gameOver,    // ゲーム終了
}

class OfflineGameScreen extends StatefulWidget {
  final int playerCount;
  
  const OfflineGameScreen({
    super.key,
    this.playerCount = 2,
  });

  @override
  _OfflineGameScreenState createState() => _OfflineGameScreenState();
}

class _OfflineGameScreenState extends State<OfflineGameScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final GameLogicService _gameLogic = GameLogicService.instance;
  final SpeechService _speech = SpeechService.instance;
  final SoundService _sound = SoundService.instance;
  final AdService _ad = AdService.instance;

  final List<TextEditingController> _nameControllers = [];

  // ゲーム状態
  bool _isPlayerSetup = false;
  bool _isGameStarted = false;
  late int _playerCount;
  List<Player> _players = [];
  int _currentPlayerIndex = 0;
  Challenge? _currentChallenge;
  Set<String> _usedWords = {};

  // 新しいゲーム状態管理
  GameState _gameState = GameState.ready;
  double _countdownSeconds = 7.8;
  double _answerSeconds = 5.0;
  double _timerProgress = 0.0;
  Timer? _countdownTimer;
  Timer? _answerTimer;

  // 音声認識状態
  bool _isListening = false;
  String _recognizedText = '';
  String _intermediateText = '';

  // 判定結果
  bool _isCorrect = false;
  String _resultMessage = '';
  int _earnedPoints = 0;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerCount = widget.playerCount;
    _initializeNameControllers();
    _setupSpeechService();
    _loadBannerAd();
    _ad.loadInterstitialAd();
  }

  void _initializeNameControllers() {
    for (int i = 0; i < 8; i++) {
      _nameControllers.add(TextEditingController(text: 'プレイヤー${i + 1}'));
    }
  }

  void _setupSpeechService() {
    _speech.onResult = (text) {
      if (mounted && _gameState == GameState.answering) {
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
        if (_gameState == GameState.answering && _answerSeconds > 3.0) {
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

  Future<void> _loadBannerAd() async {
    try {
      _bannerAd = BannerAd(
        adUnitId: _ad.getBannerAdUnitId(),
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('バナー広告読み込み成功');
            setState(() {});
          },
          onAdFailedToLoad: (ad, error) {
            print('バナー広告読み込み失敗: $error');
            print('オフライン環境または広告設定の問題の可能性があります');
            ad.dispose();
            _bannerAd = null; // 広告をnullに設定してエラーを防ぐ
            setState(() {});
          },
        ),
      );
      await _bannerAd!.load();
    } catch (e) {
      print('バナー広告初期化エラー: $e');
      _bannerAd = null; // 広告をnullに設定してエラーを防ぐ
      setState(() {});
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _speech.stopListening();
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // アプリがバックグラウンドになった時、ゲームを終了
        print('📱 アプリがバックグラウンドになりました。オフラインゲームを終了します。');
        _endGameDueToBackground();
        break;
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに戻った時
        print('📱 アプリがフォアグラウンドに戻りました。');
        break;
    }
  }

  /// バックグラウンドによるゲーム終了
  void _endGameDueToBackground() {
    // 音声認識を停止
    _speech.stopListening();
    
    // サウンドを停止
    _sound.stop();
    
    // ゲーム状態を終了に設定
    setState(() {
      _gameState = GameState.gameOver;
    });
    
    // メニュー画面に戻る
    Navigator.pop(context);
  }

  void _startGame() {
    setState(() {
      _isPlayerSetup = true;
    });
  }

  void _beginGame() {
    // プレイヤーリストを作成
    _players = List.generate(_playerCount, (index) {
      return Player(
        id: 'player_$index',
        name: _nameControllers[index].text,
        status: PlayerStatus.playing,
        score: 0,
        wordCount: 0,
      );
    });

    // お題重複防止履歴をリセット
    _gameLogic.resetRecentChallenges();

    setState(() {
      _isGameStarted = true;
      _currentPlayerIndex = 0;
      _currentChallenge = _gameLogic.generateChallenge();
    });

    // ゲーム開始後、最初のターンを開始
    _startTurn();
  }

  void _startTurn() {
    // タイマーをリセット
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _speech.stopListening();

    // 新しいお題を生成
    _currentChallenge = _gameLogic.generateChallenge();

    setState(() {
      _gameState = GameState.ready;
      _recognizedText = '';
      _countdownSeconds = 7.8;
      _answerSeconds = 8.0; // 8秒に統一
      _timerProgress = 0.0;
      _isListening = false;
    });

    // 1秒待ってからカウントダウン開始
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _gameState == GameState.ready) {
        _startCountdown();
      }
    });
  }

  void _startCountdown() {
    // 音声認識リソースを解放
    _speech.stopListening();
    _speech.cancel();

    setState(() {
      _gameState = GameState.countdown;
      _countdownSeconds = 7.8;
      _timerProgress = 0.0;
    });

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

  void _startAnswering() async {
    setState(() {
      _gameState = GameState.answering;
      _answerSeconds = 8.0; // ソロプレイと同じ8秒
      _timerProgress = 0.0;
      _recognizedText = '';
      // _isListeningはonListeningStartedコールバックで更新される
    });

    // 音声認識を開始（ソロプレイと同じ設定）
    // _isListeningの更新はonListeningStartedで行われる
    _speech.startListening(timeout: const Duration(seconds: 8));

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

  /// 音声認識を再開する
  Future<void> _restartListening() async {
    if (_gameState != GameState.answering) return;

    // 残り時間が短すぎる場合は再開しない
    if (_answerSeconds <= 2.5) {
      print('⚠️ 残り時間が短すぎるため再開をスキップします (残り時間: ${_answerSeconds.toStringAsFixed(1)}秒)');
      return;
    }

    print('🔄 音声認識を再開します');

    // 音声認識を停止
    await _speech.stopListening();
    await _speech.cancel(); // リソース解放

    // 音声認識結果はリセットしない（言い直しを保持）
    // setState(() {
    //   _recognizedText = '';
    //   _intermediateText = '';
    // });

    // 少し待ってから再開
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted && _gameState == GameState.answering && _answerSeconds > 2.5) {
      // 残り時間を計算
      final remainingSeconds = _answerSeconds.ceil().clamp(2, 8);
      print('🎤 音声認識を再開します（残り時間: ${remainingSeconds}秒）');
      
      // 音声認識を再開
      _speech.startListening(timeout: Duration(seconds: remainingSeconds));
    }
  }

  void _judgeAnswer() async {
    if (_gameState != GameState.answering) return;

    setState(() {
      _gameState = GameState.judging;
    });

    print('⚖️ 回答を判定: "$_recognizedText"');

    final result = _gameLogic.validateAnswer(
      word: _recognizedText,
      challenge: _currentChallenge!,
      usedWords: _usedWords,
    );

    final isValid = result['isValid'] as bool;
    final points = result['points'] as int;
    final message = result['message'] as String;

    setState(() {
      _isCorrect = isValid;
      _earnedPoints = points;
      _resultMessage = message;
    });

    if (_isCorrect) {
      // 正解処理
      _sound.playCorrect();
      setState(() {
        _usedWords.add(_recognizedText);
        _players[_currentPlayerIndex].score += points;
        _players[_currentPlayerIndex].wordCount++;
        _gameState = GameState.showResult;
      });

      // 2秒待ってから次のプレイヤーのターン
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _moveToNextPlayer();
          _startTurn();
        }
      });
    } else {
      // 不正解処理
      _sound.playIncorrect();

      // プレイヤーを脱落させる
      _players[_currentPlayerIndex].status = PlayerStatus.eliminated;

      // 即座に脱落ダイアログを表示（回答例付き）
      _showEliminationDialog(_players[_currentPlayerIndex], message);
    }
  }

  void _moveToNextPlayer() {
    // 次のアクティブなプレイヤーを探す
    int nextIndex = (_currentPlayerIndex + 1) % _players.length;
    while (_players[nextIndex].status != PlayerStatus.playing) {
      nextIndex = (nextIndex + 1) % _players.length;
    }
    setState(() {
      _currentPlayerIndex = nextIndex;
    });
  }


  void _endGame() async {
    await _sound.playGameOver();

    // 0.5秒待ってから広告表示
    await Future.delayed(const Duration(milliseconds: 500));

    final winner = _players.reduce((a, b) => a.score > b.score ? a : b);

    // インタースティシャル広告を20%の確率で表示（広告が閉じられた後にダイアログを表示）
    if (_ad.isInterstitialAdReady && Random().nextDouble() < 0.2) {
      await _ad.showInterstitialAd(
        onAdClosed: () {
          // 広告が閉じられた後にダイアログを表示
          if (mounted) {
            _showGameResultDialog(winner);
          }
        },
      );
    } else {
      // 広告を表示しない場合は直接ダイアログを表示
      _showGameResultDialog(winner);
    }
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
              Colors.orange.shade100,
              Colors.orange.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー
              _buildHeader(),

              // メインコンテンツ
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: !_isPlayerSetup
                      ? _buildPlayerSetup()
                      : !_isGameStarted
                          ? _buildGameStart()
                          : _buildGameArea(),
                ),
              ),

              // バナー広告（オフライン環境でのエラーハンドリング付き）
              if (_bannerAd != null)
                Container(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: _buildAdWidget(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final currentPlayer = _isGameStarted && _currentPlayerIndex < _players.length
        ? _players[_currentPlayerIndex]
        : null;
    final headerText = _isGameStarted && currentPlayer != null
        ? '${currentPlayer.name}の番'
        : 'オフライン対戦';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.orange.shade800),
          ),
          Expanded(
            child: Text(
              headerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ),
          IconButton(
            onPressed: _showGameMenu,
            icon: Icon(Icons.more_vert, color: Colors.orange.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSetup() {
    return Column(
      children: [
        // 人数選択（プラス・マイナスボタン）
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '参加人数',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              SizedBox(height: 24),
              
              // 人数表示とボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // マイナスボタン
                  _CountButton(
                    icon: Icons.remove,
                    onPressed: _playerCount > 2 ? _decreaseCount : null,
                  ),
                  SizedBox(width: 24),
                  
                  // 人数表示
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.orange,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$_playerCount',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                  
                  // プラスボタン
                  _CountButton(
                    icon: Icons.add,
                    onPressed: _playerCount < 8 ? _increaseCount : null,
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              Text(
                '${_playerCount}人で対戦',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // プレイヤー名入力
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'プレイヤー名を入力',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _playerCount,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _nameControllers[index],
                          decoration: InputDecoration(
                            labelText: 'プレイヤー${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 20),

        // ゲーム開始ボタン
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'ゲーム開始',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameStart() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.people,
          size: 80,
          color: Colors.orange.shade600,
        ),
        SizedBox(height: 20),
        Text(
          'ゲームを開始します',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'ランダムなお題に合う単語を答えましょう',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _beginGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            '開始',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 現在のプレイヤーとスコアヘッダー
          _buildCurrentPlayerHeader(),
          const SizedBox(height: 12),

          // お題表示
          if (_currentChallenge != null) _buildChallengeDisplay(),
          const SizedBox(height: 12),

          // ゲーム状態に応じたコンテンツ
          _buildGameContent(),

          const SizedBox(height: 16),

          // プレイヤー一覧（横スクロール）- 画面下部に配置
          _buildPlayerScores(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 現在のプレイヤーとスコアを表示するヘッダー
  Widget _buildCurrentPlayerHeader() {
    final currentPlayer = _players[_currentPlayerIndex];
    final activePlayers = _players.where((p) => p.status == PlayerStatus.playing).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // プレイヤー名
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                '${currentPlayer.name}の番',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // スコアと正解数
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                '${currentPlayer.score}点',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 12),
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                '${currentPlayer.wordCount}個',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 残りプレイヤー数
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '残り${activePlayers.length}人',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // お題表示
  Widget _buildChallengeDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCharacterCircle(_currentChallenge!.head),
          const SizedBox(width: 8),
          const Text(
            'で始まり',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          _buildCharacterCircle(_currentChallenge!.tail),
          const SizedBox(width: 8),
          const Text(
            'で終わる',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCircle(String character) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Text(
          character,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.blue.shade900,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerScores() {
    return Container(
      height: 65,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _players.length,
        itemBuilder: (context, index) {
          final player = _players[index];
          final isActive = player.status == PlayerStatus.playing;
          final isCurrent = index == _currentPlayerIndex;

          return Container(
            width: 100,
            margin: EdgeInsets.only(right: 10),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrent ? Colors.orange.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrent ? Colors.orange.shade600 : Colors.grey.shade300,
                width: isCurrent ? 2 : 1,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3),
                Text(
                  '${player.score}点',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isActive ? Colors.orange.shade800 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ゲーム状態に応じたコンテンツを表示
  Widget _buildGameContent() {
    switch (_gameState) {
      case GameState.ready:
        return _buildReadyState();
      case GameState.countdown:
        return _buildCountdownState();
      case GameState.answering:
        return _buildAnsweringState();
      case GameState.judging:
        return _buildJudgingState();
      case GameState.showResult:
        return _buildResultModal();
      case GameState.gameOver:
        return _buildGameOverState();
    }
  }

  Widget _buildReadyState() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.play_circle_outline, size: 60, color: Colors.green.shade600),
          const SizedBox(height: 16),
          const Text(
            '準備中...',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownState() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.purple.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade300, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
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
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade400),
                  ),
                ),
                // 時間表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _countdownSeconds.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        '秒',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '準備してください！',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnsweringState() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // 波形エンベロープ
          _buildWaveformEnvelope(),
          const SizedBox(height: 16),

          // タイマー表示（プログレスバー）
          Column(
            children: [
              Text(
                _answerSeconds.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '秒',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 16),
              // プログレスバー
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FractionallySizedBox(
                  widthFactor: 1.0 - _timerProgress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 認識エリア
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _recognizedText.isEmpty
                    ? [Colors.grey.shade100, Colors.grey.shade200]
                    : [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _recognizedText.isEmpty ? Colors.grey.shade400 : Colors.blue.shade400,
                width: _recognizedText.isEmpty ? 2 : 3,
              ),
            ),
            child: Column(
              children: [
                if (_recognizedText.isEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '認識中...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '音声を認識中です...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ] else ...[
                  Text(
                    _recognizedText,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 「音声認識中」ラベル
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.mic, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  '音声認識中',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformEnvelope() {
    return Container(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (index) {
          final time = DateTime.now().millisecondsSinceEpoch / 200;
          final wave1 = sin(time + index * 0.5);
          final wave2 = cos((time * 1.3) + index * 0.7);
          final combined = (wave1 + wave2) / 2;
          final animatedHeight = 10 + (12.5 * (1 + combined));

          return TweenAnimationBuilder<double>(
            key: ValueKey('wave_$index'),
            tween: Tween(begin: 10, end: _isListening ? animatedHeight : 10),
            duration: const Duration(milliseconds: 150),
            builder: (context, height, child) {
              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.red.shade700,
                      Colors.red.shade500,
                      Colors.red.shade300,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildJudgingState() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            '判定中...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildResultModal() {
    final examples = _currentChallenge != null
        ? _gameLogic.generateAnswerExamples(_currentChallenge!, limit: 3)
        : <String>[];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isCorrect
              ? [Colors.green.shade100, Colors.green.shade200]
              : [Colors.red.shade100, Colors.red.shade200],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isCorrect ? Colors.green.shade400 : Colors.red.shade400,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isCorrect ? Colors.green : Colors.red).withOpacity(0.4),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isCorrect ? Icons.check_circle : Icons.cancel,
            size: 80,
            color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            _isCorrect ? '正解！' : '不正解',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: _isCorrect ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 12),
          if (_recognizedText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                  width: 2,
                ),
              ),
              child: Text(
                '「$_recognizedText」',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _isCorrect ? Colors.green.shade900 : Colors.red.shade900,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _resultMessage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '回答例:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...examples.map((example) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '・$example',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameOverState() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Text(
        'ゲーム終了',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
    );
  }

  void _showEliminationDialog(Player player, String reason) {
    // 回答例を取得
    final examples = _currentChallenge != null
        ? _gameLogic.generateAnswerExamples(_currentChallenge!, limit: 3)
        : <String>[];

    showDialog(
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
    );

    // 5秒後に自動的にダイアログを閉じて次の処理へ
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context);

        // 残りプレイヤー確認
        final activePlayers = _players.where((p) => p.status == PlayerStatus.playing).toList();

        if (activePlayers.length == 1) {
          // 最後の1人になった場合はゲーム終了
          _endGame();
        } else if (activePlayers.isEmpty) {
          // 全員脱落した場合もゲーム終了
          _endGame();
        } else {
          // まだ複数プレイヤーが残っている場合は次のターンへ
          _moveToNextPlayer();
          setState(() {
            _currentChallenge = _gameLogic.generateChallenge();
          });
          _startTurn();
        }
      }
    });
  }

  void _showGameResultDialog(Player winner) {
    showDialog(
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
              colors: [Colors.amber.shade100, Colors.amber.shade200],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.4),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 優勝トロフィー
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 50,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 20),

              // タイトル
              Text(
                '${winner.name}の勝利！',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // スコア表示
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars, color: Colors.amber.shade700, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '獲得得点: ${winner.score}点',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '回答数: ${winner.wordCount}個',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ボタン
              Column(
                children: [
                  // 同じメンバーで続ける
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          // プレイヤーをリセット（名前は保持、スコアと状態をリセット）
                          for (var player in _players) {
                            player.score = 0;
                            player.wordCount = 0;
                            player.status = PlayerStatus.playing;
                          }
                          _currentPlayerIndex = 0;
                          _usedWords.clear();
                          _currentChallenge = _gameLogic.generateChallenge();
                        });
                        _startTurn();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '同じメンバーで続ける',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // メニューに戻る
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.orange.shade700, width: 2),
                      ),
                      child: Text(
                        'メニューに戻る',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('エラー'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGameMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.refresh),
              title: Text('ゲームをリセット'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isGameStarted = false;
                  _isPlayerSetup = false;
                  _usedWords.clear();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('メニューに戻る'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _increaseCount() {
    if (_playerCount < 8) {
      setState(() {
        _playerCount++;
      });
    }
  }

  void _decreaseCount() {
    if (_playerCount > 2) {
      setState(() {
        _playerCount--;
      });
    }
  }

  /// エラーハンドリング付きAdWidgetビルダー
  Widget _buildAdWidget() {
    try {
      return AdWidget(ad: _bannerAd!);
    } catch (e) {
      print('AdWidgetエラー: $e');
      // オフライン環境や広告読み込み失敗時の代替表示
      return Container(
        width: 320,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '広告',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }
}

/// カウントボタン
class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CountButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.orange : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(28),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.grey.shade500,
            size: 28,
          ),
        ),
      ),
    );
  }
}
