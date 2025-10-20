import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import '../services/question_service.dart';
import '../services/score_service.dart';
import '../models/question.dart';
import '../widgets/draggable_character.dart';
import '../widgets/answer_area.dart';
import '../widgets/blinking_text.dart';

class SoloGameScreen extends StatefulWidget {
  final bool isTimedMode;

  const SoloGameScreen({
    super.key,
    required this.isTimedMode,
  });

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen> with TickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  int _currentStage = 0;
  int _score = 0;
  Question? _currentQuestion;
  List<String?> _answer = [];
  List<String> _availableCharacters = []; // 選択可能な文字（重複なし）
  Timer? _timer;
  int _timeLeft = 30;
  bool _isGameOver = false;
  String _userAnswer = ''; // ゲームオーバー時のユーザーの回答
  bool _wasTimeUp = false; // 時間切れでゲームオーバーになったか
  bool _gameStarted = false; // ゲームが開始されたか（タイムアタックモード用）

  // アニメーションテキスト用
  Timer? _animationTimer;
  int _animationIndex = 0;
  static const String _animationText = '-- 逆読み回答 -->';

  // 「問題」反転アニメーション用
  Timer? _flipTimer;
  bool _isFlipped = false;

  // フェイク文字の固定リスト
  static const List<String> _fakeCharacters = [
    'あ',
    'お',
    'さ',
    'き',
    'の',
    'は',
    'ま',
    'ら',
    'し',
    'ち',
    'わ',
    'れ',
  ];

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _startAnimationTimer();
    _startFlipTimer();
    _startNewQuestion();
    // ゲーム画面用BGM（80%ボリューム）
    SoundService().setBgmVolumeForGame();
  }

  void _startAnimationTimer() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      setState(() {
        _animationIndex = (_animationIndex + 1) % (_animationText.length + 1);
      });
    });
  }

  void _startFlipTimer() {
    _flipTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      setState(() {
        _isFlipped = !_isFlipped;
      });
    });
  }

  void _loadBannerAd() {
    _bannerAd = AdService().createBannerAd();
    _bannerAd!.load().then((_) {
      if (mounted) {
        setState(() {
          _isBannerAdLoaded = true;
        });
      }
    });
  }

  void _startNewQuestion() {
    setState(() {
      _currentQuestion =
          QuestionService().getQuestionForStage(_currentStage);
      _answer = List.filled(_currentQuestion!.characters.length, null);

      // 正解の文字とフェイク文字から重複を除いて選択肢を作成
      final allChars = [
        ..._currentQuestion!.characters,
        ..._fakeCharacters,
      ];
      _availableCharacters = allChars.toSet().toList(); // 重複削除
      _availableCharacters.shuffle();

      _timeLeft = 30;
      // タイムアタックモードの場合、最初はゲーム未開始状態
      _gameStarted = !widget.isTimedMode;
    });

    SoundService().playGameStart();

    // リラックスモードではすぐにタイマーを開始しない（タイマーなし）
    // タイムアタックモードではスタートボタンを待つ
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
    });
    if (widget.isTimedMode) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    SoundService().playTimeUp();
    setState(() {
      _userAnswer = _answer.whereType<String>().join('');
      _wasTimeUp = true;
    });
    _gameOver();
  }

  void _onCharacterDropped(String character, int targetIndex) {
    // すべての文字が何度でも使用可能
    setState(() {
      _answer[targetIndex] = character;
    });
    // 文字配置音を再生
    SoundService().playDrop();
  }

  void _onCharacterReordered(int fromIndex, int toIndex) {
    setState(() {
      final temp = _answer[fromIndex];
      _answer[fromIndex] = _answer[toIndex];
      _answer[toIndex] = temp;
    });
  }

  void _onCharacterRemoved(int index) {
    setState(() {
      _answer[index] = null;
    });
    // 削除音を再生
    SoundService().playDrop();
  }

  void _onCharacterTapped(String character) {
    // 最初の空白を見つける
    final firstEmptyIndex = _answer.indexOf(null);
    if (firstEmptyIndex != -1) {
      setState(() {
        _answer[firstEmptyIndex] = character;
      });
      // 文字配置音を再生
      SoundService().playDrop();
    }
  }

  void _checkAnswer() {
    _timer?.cancel();

    final userAnswer = _answer.whereType<String>().join('');
    final isCorrect = userAnswer == _currentQuestion!.answer;

    if (isCorrect) {
      SoundService().playCorrect();
      setState(() {
        _score++;
        _currentStage++;
      });

      _showResultDialog(true);
    } else {
      SoundService().playIncorrect();
      setState(() {
        _userAnswer = userAnswer;
        _wasTimeUp = false;
      });
      _gameOver();
    }
  }

  void _gameOver() {
    setState(() {
      _isGameOver = true;
    });

    _timer?.cancel();
    SoundService().playGameOver();

    // ハイスコア更新
    if (widget.isTimedMode) {
      ScoreService().setHighScoreTimed(_score);
    } else {
      ScoreService().setHighScoreRelax(_score);
    }

    _showGameOverDialog();
  }

  void _showResultDialog(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isCorrect ? '正解!' : '不正解',
          style: TextStyle(
            color: isCorrect ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              size: 64,
              color: isCorrect ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'ステージ $_currentStage クリア!',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              '現在のスコア: $_score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startNewQuestion();
            },
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'ゲームオーバー',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_esports,
              size: 64,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 16),

            // 理由を表示
            Text(
              _wasTimeUp ? '時間切れ!' : '不正解!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _wasTimeUp ? Colors.orange : Colors.red,
              ),
            ),
            const SizedBox(height: 12),

            // 鏡文字を表示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    '鏡文字',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scaleX: -1,
                    child: Text(
                      _currentQuestion!.text,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // あなたの回答を表示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'あなたの回答: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userAnswer.isEmpty ? '(未入力)' : _userAnswer,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 正解を表示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '正解: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentQuestion!.answer,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '最終ステージ: $_currentStage',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '最終スコア: $_score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AdService().showInterstitialAd(percentage: 25);
              if (mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('メニューに戻る'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AdService().showInterstitialAd(percentage: 100);
              if (mounted) {
                Navigator.of(context).pop();
                setState(() {
                  _currentStage = 0;
                  _score = 0;
                  _isGameOver = false;
                });
                _startNewQuestion();
              }
            },
            child: const Text('最初から'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationTimer?.cancel();
    _flipTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentQuestion == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('ステージ $_currentStage'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                'スコア: $_score',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // BGM切り替えボタン
          IconButton(
            icon: Icon(
              SoundService().bgmEnabled ? Icons.music_note : Icons.music_off,
            ),
            onPressed: () {
              setState(() {
                SoundService().toggleBgm();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // タイマー表示（タイムアタックモードのみ）
          if (widget.isTimedMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _timeLeft <= 10 ? Colors.red : Colors.orange,
              child: Text(
                '残り時間: $_timeLeft秒',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // 鏡文字表示（タイムアタックモードでゲーム未開始の場合は「問題」を反転）
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '鏡文字',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // タイムアタックモードでゲーム未開始の場合は「問題」のアニメーション
                        if (widget.isTimedMode && !_gameStarted)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Transform.scale(
                              key: ValueKey<bool>(_isFlipped),
                              scaleX: _isFlipped ? -1 : 1,
                              child: const Text(
                                '問題',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          )
                        else
                          // ゲーム開始後は実際の鏡文字を表示
                          Transform.scale(
                            scaleX: -1,
                            child: Text(
                              _currentQuestion!.text,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // アニメーションテキスト「-- 逆読み回答 -->」
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_animationText.length, (index) {
                        final isLit = index < _animationIndex;
                        return Text(
                          _animationText[index],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isLit ? Colors.deepPurple : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // タイムアタックモードでゲーム未開始の場合、スタートボタンを表示
                  if (widget.isTimedMode && !_gameStarted)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        onPressed: _startGame,
                        icon: const Icon(Icons.play_arrow, size: 32),
                        label: const Text(
                          'スタート',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),

                  // 回答エリア
                  AnswerArea(
                    answer: _answer,
                    onCharacterDropped: _onCharacterDropped,
                    onCharacterReordered: _onCharacterReordered,
                    onCharacterRemoved: _onCharacterRemoved,
                  ),
                  const SizedBox(height: 12),

                  // 文字選択エリア
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '文字を選んで',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            BlinkingText(
                              text: '回答エリアにドラッグ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const Text(
                              'してください',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: _availableCharacters.map((character) {
                            // すべての文字が常に使用可能
                            return DraggableCharacter(
                              character: character,
                              isPlaced: false, // 常にfalse（何度でも使用可能）
                              onTap: () => _onCharacterTapped(character),
                              enableDrag: false, // ドラッグ無効（タップのみ）
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 回答ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _answer.contains(null)
                          ? null
                          : _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        '回答する',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // バナー広告
          if (_isBannerAdLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
