import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math';
import '../models/game_models.dart';
import '../models/dictionary_model.dart';
import '../services/game_logic_service.dart';
import '../services/speech_service.dart';
import '../services/sound_service.dart';
import '../services/game_center_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// ソロプレイ画面（サドンデス制）
class SoloGameScreen extends StatefulWidget {
  const SoloGameScreen({super.key});

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

// ゲームの状態
enum GameState {
  ready,          // 準備（お題表示）
  countdown,      // 10秒カウントダウン
  answering,      // 5秒以内に回答
  judging,        // 正誤判定中
  showResult,     // 結果表示（正解例表示）
  gameOver,       // ゲームオーバー
}

class _SoloGameScreenState extends State<SoloGameScreen> {
  final GameLogicService _gameLogic = GameLogicService.instance;
  final SpeechService _speech = SpeechService.instance;
  final SoundService _sound = SoundService.instance;
  final GameCenterService _gameCenter = GameCenterService.instance;
  final DictionaryModel _dictionary = DictionaryModel.instance;
  final AdService _ad = AdService.instance;

  late Player _player;
  late Challenge _currentChallenge;
  final Set<String> _usedWords = {};
  final List<Answer> _answers = [];
  int _score = 0;

  // ゲーム状態
  GameState _gameState = GameState.ready;

  // タイマー関連
  Timer? _countdownTimer;
  Timer? _answerTimer;
  double _countdownSeconds = 7.8;
  double _answerSeconds = 5.0;
  double _timerProgress = 0.0;

  // 音声認識
  bool _isListening = false;
  String _recognizedText = '';
  String _intermediateText = '';
  List<String> _speechAlternatives = [];

  // 広告
  BannerAd? _bannerAd;

  // 結果表示
  bool _isCorrect = false;
  List<String> _answerExamples = [];
  String _feedbackMessage = '';
  String _playerAnswer = ''; // プレイヤーの回答を保存

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _initializeGameCenter();
    _loadBannerAd();
    
    // 音声認識の設定（元の状態に戻す）
  }

  Future<void> _initializeGameCenter() async {
    await _gameCenter.initialize();
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
            ad.dispose();
            _bannerAd = null;
            setState(() {});
          },
        ),
      );
      await _bannerAd!.load();
    } catch (e) {
      print('バナー広告初期化エラー: $e');
      _bannerAd = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _answerTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _initializeGame() {
    _player = Player(
      id: const Uuid().v4(),
      name: 'プレイヤー',
      status: PlayerStatus.playing,
    );
    
    // お題重複防止履歴をリセット
    _gameLogic.resetRecentChallenges();
    
    _startNewRound();
  }

  void _startNewRound() {
    // 既存のタイマーを確実にキャンセル（誤差防止）
    _countdownTimer?.cancel();
    _answerTimer?.cancel();

    // 音声認識を完全に停止
    _speech.stopListening();
    
    setState(() {
      _currentChallenge = _gameLogic.generateChallenge();
      print('🎲 新しいお題を生成: 頭="${_currentChallenge.head}", お尻="${_currentChallenge.tail}"');
      
      // 回答例を取得して表示
      final examples = _gameLogic.generateAnswerExamples(_currentChallenge, limit: 10);
      print('📝 回答例 (${examples.length}個): ${examples.join(', ')}');
      
      // 完全にリセット
      _gameState = GameState.ready;
      _recognizedText = '';
      _countdownSeconds = 7.8;
      _answerSeconds = 5.0;
      _timerProgress = 0.0;
      _isListening = false;
    });
    
    print('🔄 ゲーム状態を完全にリセットしました');

    // 1秒後にカウントダウン開始
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _gameState == GameState.ready) {
        _startCountdown();
      }
    });
  }

  void _startCountdown() {
    // 音声認識状態を確実にリセット
    _speech.stopListening();
    
    setState(() {
      _gameState = GameState.countdown;
      _countdownSeconds = 7.8;
      _timerProgress = 0.0;
      _isListening = false;
      _recognizedText = '';
    });
    
    print('🔄 カウントダウン開始: 音声認識状態をリセット');

    // 10秒BGMを再生（7.8秒カウントダウンだが、BGMは継続）
    _sound.playCountdown10sec();

    // カウントダウンタイマー（7.8秒）
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _timerProgress += 0.01282; // 7.8秒で1.0 (1/78 = 0.01282)
        _countdownSeconds = 7.8 - (_timerProgress * 7.8);

        if (_countdownSeconds <= 0) {
          timer.cancel();
          _startAnswering();
        }
      });
    });
  }

  void _startAnswering() {
    setState(() {
      _gameState = GameState.answering;
      _answerSeconds = 8;
      _timerProgress = 0.0;
      _recognizedText = '';
    });

    // BGMは停止せず、余韻を残す

    // 回答開始時のバイブレーション
    _sound.vibrate();

    // 音声認識コールバック設定
    _speech.onResult = (text) {
      if (!mounted || _gameState != GameState.answering) return;

      // speech_serviceで既にひらがな変換されているのでそのまま使用
      setState(() {
        _recognizedText = text;
      });
      print('🎤 画面表示: $_recognizedText');
    };

    _speech.onListeningStopped = () {
      if (!mounted || _gameState != GameState.answering) return;

      // 音声認識が途中で停止した場合、タイマーが残っていれば再開
      final elapsedTime = 8.0 - _answerSeconds;
      print('🎤 音声認識が停止しました（経過時間: ${elapsedTime.toStringAsFixed(1)}秒、残り: ${_answerSeconds.toStringAsFixed(1)}秒）');

      // 音声認識結果が空の場合は再開を試行
      if (_recognizedText.isEmpty) {
        print('📱 音声認識結果が空です。音声認識を再開します');
        if (_answerSeconds > 1.0) {
          _restartListening();
        }
        return;
      }

      // 音声認識が成功した場合は再開しない
      print('✅ 音声認識が成功しました。再開処理をスキップします');
      return;
    };

    // 音声認識開始
    _startListening();

    // 8秒回答タイマー
    _answerTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _timerProgress += 0.0125; // 8秒で1.0
        _answerSeconds = 8 - (_timerProgress * 8); // 小数点表示のため ceil を削除

        if (_answerSeconds <= 0) {
          timer.cancel();
          _speech.stopListening();
          // 回答終了時のバイブレーション
          _sound.vibrate();

          // 音声認識の最終結果を待つために少し遅延
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _judgeAnswer();
            }
          });
        }
      });
    });
  }

  Future<void> _restartListening() async {
    // 音声認識を強制的にリセットして再開
    await _speech.stopListening();
    setState(() {
      _isListening = false;
    });
    
    // 音声認識結果をリセット
    _recognizedText = '';
    _intermediateText = '';
    
    // 少し待ってから再開
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 残り時間に応じたタイムアウトで再開
    try {
      final remainingSeconds = (_answerSeconds.ceil()).clamp(2, 8); // 最低2秒、最大8秒
      print('🎤 音声認識を再開します（残り時間: ${_answerSeconds.toStringAsFixed(1)}秒 → ${remainingSeconds}秒）');
      print('🎤 期待される頭文字: "${_currentChallenge.head}"');
      await _speech.startListening(
        timeout: Duration(seconds: remainingSeconds),
        expectedHead: _currentChallenge.head,
      );
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      print('❌ 音声認識再開エラー: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _startListening() async {
    if (_isListening) {
      print('🎤 既に音声認識中のため、スキップします');
      return;
    }

    if (_gameState != GameState.answering) {
      print('🎤 回答状態ではないため、音声認識を開始しません');
      return;
    }

    setState(() {
      _isListening = true;
    });

    try {
      print('🎤 音声認識を開始します（タイムアウト: ${_answerSeconds}秒）');
      print('🎤 期待される頭文字: "${_currentChallenge.head}"');
      await _speech.startListening(
        timeout: Duration(seconds: _answerSeconds.toInt()),
        expectedHead: _currentChallenge.head,
      );
    } catch (e) {
      print('❌ 音声認識エラー: $e');
      setState(() {
        _isListening = false;
      });
    }
  }

  void _judgeAnswer() {
    _answerTimer?.cancel();
    setState(() {
      _gameState = GameState.judging;
      _isListening = false;
    });

    // 判定処理
    print('🔍 判定開始: お題 = 頭="${_currentChallenge.head}", お尻="${_currentChallenge.tail}"');
    print('🔍 音声認識結果: "$_recognizedText"');

    // プレイヤーの回答を保存
    _playerAnswer = _recognizedText.isEmpty ? '無回答' : _recognizedText;

    // 音声認識結果をそのまま使用（変換なし）
    print('🔍 音声認識結果をそのまま使用します');

    final validation = _gameLogic.validateAnswer(
      word: _recognizedText, // 音声認識結果をそのまま使用
      challenge: _currentChallenge,
      usedWords: _usedWords,
    );

    _isCorrect = validation['isValid'];
    final points = validation['points'] as int;
    _feedbackMessage = validation['message'] as String;

    print('🔍 判定結果: ${_isCorrect ? "正解" : "不正解"} (${_feedbackMessage})');

    if (_isCorrect) {
      // 正解
      _score += points;
      _player.score += points;
      _player.wordCount++;
      _usedWords.add(_recognizedText);

      _answers.add(Answer(
        word: _recognizedText,
        playerId: _player.id,
        playerName: _player.name,
        points: points,
        challenge: _currentChallenge,
        timestamp: DateTime.now(),
      ));

      // 正解時: 他の解答例を3つ取得（自分の回答を除く）
      final allExamples = _gameLogic.generateAnswerExamples(_currentChallenge, limit: 10);
      _answerExamples = allExamples
          .where((word) => word != _recognizedText)
          .take(3)
          .toList();

      _sound.playCorrect();

      // 正解時: 2秒間の簡易フィードバック後、次のラウンドへ
      setState(() {
        _gameState = GameState.showResult;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _startNewRound();
        }
      });
    } else {
      // 不正解: ゲームオーバー
      // 正しい解答例を4つ表示
      _answerExamples = _gameLogic.generateAnswerExamples(_currentChallenge, limit: 4);
      _sound.playIncorrect();

      // 不正解時: 直接ゲームオーバーダイアログへ（結果画面をスキップ）
      _showGameOverDialog();
    }
  }

  /// シミュレーター用フォールバック機能
  void _enableSimulatorFallback({String? expectedTail}) {
    print('📱 シミュレーター用フォールバック機能を有効化');
    print('💡 実機でのテストを推奨しますが、デバッグ用のサンプル回答を提供します');
    
    // デバッグ用のサンプル回答を提供（期待される尻文字も考慮）
    final sampleWords = _getSampleWordsForHead(_currentChallenge.head, expectedTail: expectedTail);
    if (sampleWords.isNotEmpty) {
      print('📝 デバッグ用サンプル回答: ${sampleWords.join(', ')}');
      // 最初のサンプル単語を自動選択（デバッグ用）
      final selectedWord = sampleWords.first;
      print('🎯 デバッグ用選択: "$selectedWord"');
      
      // 少し遅延してから結果を返す（リアルな音声認識をシミュレート）
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _gameState == GameState.answering) {
          setState(() {
            _recognizedText = selectedWord;
          });
          print('🎤 フォールバック結果: $selectedWord');
        }
      });
    } else {
      print('⚠️ サンプル単語が見つかりませんでした');
      // フォールバック用のデフォルト単語
      final fallbackWord = '${_currentChallenge.head}ん';
      print('🎯 デフォルトフォールバック: "$fallbackWord"');
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _gameState == GameState.answering) {
          setState(() {
            _recognizedText = fallbackWord;
          });
          print('🎤 フォールバック結果: $fallbackWord');
        }
      });
    }
  }
  
  /// 頭文字に基づくサンプル単語を取得
  List<String> _getSampleWordsForHead(String head, {String? expectedTail}) {
    final sampleWords = {
      'あ': ['あい', 'あお', 'あか', 'あき', 'あさ'],
      'い': ['いえ', 'いけ', 'いし', 'いち', 'いぬ'],
      'う': ['うえ', 'うし', 'うま', 'うみ', 'うる'],
      'え': ['えき', 'えん', 'えほん', 'えがお', 'えいが'],
      'お': ['おか', 'おに', 'おと', 'おはな', 'おかし'],
      'か': ['かき', 'かみ', 'かばん', 'かぜ', 'かお'],
      'き': ['きのう', 'きょう', 'きのこ', 'きいろ', 'きつね'],
      'く': ['くも', 'くつ', 'くま', 'くち', 'くるま'],
      'け': ['けん', 'けが', 'けしき', 'けいと', 'けいさつ'],
      'こ': ['こども', 'こんにちは', 'こんばんは', 'こおり', 'こねこ'],
      'さ': ['さくら', 'さかな', 'さとう', 'さく', 'さる'],
      'し': ['しろ', 'しんぶん', 'しゃしん', 'しゅうまつ', 'しゅくだい'],
      'す': ['すし', 'すず', 'すいか', 'すいえい', 'すいとう'],
      'せ': ['せんせい', 'せかい', 'せき', 'せんたく', 'せいかつ'],
      'そ': ['そら', 'そと', 'そば', 'そうじ', 'そうべつ'],
      'た': ['たまご', 'たべもの', 'たのしい', 'たてもの', 'たからもの'],
      'ち': ['ちいさい', 'ちから', 'ちず', 'ちょう', 'ちかてつ'],
      'つ': ['つき', 'つくえ', 'つり', 'つま', 'つくし'],
      'て': ['てがみ', 'てんき', 'てんらんかい', 'てんぷら', 'てんさい'],
      'と': ['とけい', 'とり', 'とし', 'とけい', 'としょかん'],
      'な': ['なつ', 'なか', 'なまえ', 'なかま', 'なつやすみ'],
      'に': ['にほん', 'にわ', 'にんぎょう', 'にゅうがく', 'にゅういん'],
      'ぬ': ['ぬいぐるみ', 'ぬの', 'ぬりえ', 'ぬま', 'ぬすみ'],
      'ね': ['ねこ', 'ねんがじょう', 'ねつ', 'ねむい', 'ねがお'],
      'の': ['のり', 'のう', 'のうりん', 'のうぎょう', 'のうみん'],
      'は': ['はな', 'はる', 'はし', 'はなび', 'はたらく'],
      'ひ': ['ひこうき', 'ひまわり', 'ひる', 'ひこうき', 'ひがし'],
      'ふ': ['ふね', 'ふく', 'ふゆ', 'ふとん', 'ふくざつ'],
      'へ': ['へや', 'へいわ', 'へん', 'へいき', 'へいわ'],
      'ほ': ['ほん', 'ほし', 'ほんとう', 'ほんや', 'ほんしつ'],
      'ま': ['まど', 'まち', 'まんが', 'まつり', 'まんねんひつ'],
      'み': ['みず', 'みどり', 'みち', 'みなみ', 'みなさん'],
      'む': ['むし', 'むら', 'むかし', 'むすこ', 'むすめ'],
      'め': ['めがね', 'めん', 'めいし', 'めがね', 'めんきょ'],
      'も': ['もも', 'もり', 'もん', 'もんく', 'もんし'],
      'や': ['やま', 'やさい', 'やね', 'やくそく', 'やまびこ'],
      'ゆ': ['ゆき', 'ゆめ', 'ゆうがた', 'ゆうびん', 'ゆうじん'],
      'よ': ['よる', 'よてい', 'よろしく', 'よし', 'よろこび'],
      'ら': ['らくがき', 'らく', 'らくせん', 'らくがき', 'らくがき'],
      'り': ['りんご', 'りょこう', 'りょうり', 'りょうし', 'りょうり'],
      'る': ['るす', 'るい', 'るいけい', 'るいけい', 'るいけい'],
      'れ': ['れきし', 'れんしゅう', 'れんあい', 'れんしゅう', 'れんあい'],
      'ろ': ['ろく', 'ろくがつ', 'ろくがつ', 'ろくがつ', 'ろくがつ'],
      'わ': ['わか', 'わかもの', 'わかもの', 'わかもの', 'わかもの'],
      'を': ['を', 'を', 'を', 'を', 'を'],
    };
    
    // 基本的なサンプル単語を取得
    List<String> words = sampleWords[head] ?? [];
    
    // 2文字の単語を除外（3文字以上のみ）
    words = words.where((word) => word.length >= 3).toList();
    
    // 期待される尻文字が指定されている場合は、それに合致する単語を優先
    if (expectedTail != null && words.isNotEmpty) {
      final matchingWords = words.where((word) => 
        word.isNotEmpty && word.endsWith(expectedTail)).toList();
      
      if (matchingWords.isNotEmpty) {
        print('🎯 期待される尻文字 "$expectedTail" に合致する単語を優先: ${matchingWords.join(', ')}');
        return matchingWords;
      } else {
        print('⚠️ 期待される尻文字 "$expectedTail" に合致する単語が見つかりません。基本単語を使用します');
      }
    }
    
    return words;
  }

  void _showGameOverDialog() {
    setState(() {
      _gameState = GameState.gameOver;
    });

    // Game Centerにスコアを送信
    _gameCenter.submitScore(
      leaderboardId: 'com.atama_oshiri.high_score',
      score: _score,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'ゲームオーバー',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cancel,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              // プレイヤーの回答を表示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'あなたの回答',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _playerAnswer,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '最終スコア',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '$_score点',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('正答数: ${_player.wordCount}個'),
              if (_player.wordCount > 0)
                Text('平均点: ${(_score / _player.wordCount).toStringAsFixed(1)}点'),

              // 不正解時の解答例表示
              if (_answerExamples.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '正しい解答例',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _answerExamples.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.deepPurple.shade200,
                        ),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ダイアログを閉じる
              Navigator.pop(context); // メニュー画面に戻る
            },
            child: const Text('メニューに戻る'),
          ),
          if (_gameCenter.isSignedIn)
            TextButton(
              onPressed: () {
                _gameCenter.showLeaderboard();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.leaderboard, size: 20),
                  SizedBox(width: 4),
                  Text('ランキング'),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _score = 0;
                _usedWords.clear();
                _answers.clear();
                _player = Player(
                  id: const Uuid().v4(),
                  name: 'プレイヤー',
                  status: PlayerStatus.playing,
                );
                _startNewRound();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('もう一度プレイ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ソロプレイ'),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // スコア表示
              _buildScoreHeader(),
              // メインコンテンツ
              Expanded(
                child: _buildGameContent(),
              ),
              // バナー広告（画面下部に常時表示）
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

  Widget _buildScoreHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            '$_score点',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 2,
            height: 24,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 20),
          Icon(Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            '${_player.wordCount}個',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // お題カード
              _buildChallengeCard(),
              const SizedBox(height: 40),
              // 状態別の表示
              _buildStateSpecificContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.deepPurple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple.shade300,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          // お題ヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade500,
                  Colors.deepPurple.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.4),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text(
              '🎯 お題',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 文字フロー
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _KanaCircle(
                kana: _currentChallenge.head,
                label: '頭',
                color: Colors.blue,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: Colors.deepPurple,
                ),
              ),
              // 装飾的な中央ボックス（コンパクト化）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade200,
                      Colors.grey.shade300,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: Colors.deepPurple,
                ),
              ),
              _KanaCircle(
                kana: _currentChallenge.tail,
                label: 'お尻',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ヒントテキスト（コンパクト化）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.deepPurple.shade200,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '「',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade400,
                  ),
                ),
                Text(
                  _currentChallenge.head,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  '」→「',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  _currentChallenge.tail,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  '」',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateSpecificContent() {
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
        return _buildResultState();
      case GameState.gameOver:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReadyState() {
    return Column(
      children: [
        const Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.deepPurple,
        ),
        const SizedBox(height: 16),
        Text(
          '準備中...',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownState() {
    return Column(
      children: [
        // 円形カウントダウン表示
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade100,
                Colors.deepPurple.shade200,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _countdownSeconds.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade800,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '考え中...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade700,
          ),
        ),
        const SizedBox(height: 20),
        // プログレスバー（カウントダウン）
        SizedBox(
          width: 250,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _timerProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade600),
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              Text(
                '${((_timerProgress) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnsweringState() {
    return Column(
      children: [
        // 音声波形エンベロープ（縦型・イコライザー風）
        _buildWaveformEnvelope(),
        const SizedBox(height: 20),

        // プログレスバーと残り時間
        Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade300, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.2),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _timerProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                minHeight: 14,
                borderRadius: BorderRadius.circular(7),
              ),
              const SizedBox(height: 10),
              Text(
                '⏱️ ${_answerSeconds.toStringAsFixed(1)}秒',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 認識結果表示ボックス（リアルタイム表示）
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _recognizedText.isEmpty
                  ? [Colors.grey.shade100, Colors.grey.shade200]
                  : [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _recognizedText.isEmpty ? Colors.grey.shade400 : Colors.blue.shade400,
              width: _recognizedText.isEmpty ? 2 : 3,
            ),
            boxShadow: _recognizedText.isEmpty
                ? []
                : [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Column(
            children: [
              if (_recognizedText.isEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '認識中...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '音声を認識中です...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ] else ...[
                Text(
                  _recognizedText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade900,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 過去の回答（コンパクト化）
        if (_usedWords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade300, width: 2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 18, color: Colors.purple.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '過去の回答',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: _usedWords.take(4).map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade50, Colors.purple.shade100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade400, width: 2),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // タイトルを一番下に移動
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade500, Colors.red.shade700],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Text(
            '🎤 音声認識中',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // 縦型波形エンベロープUI（イコライザー風・動的アニメーション）
  Widget _buildWaveformEnvelope() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          // イコライザー風アニメーション：各バーが独立して動く
          // 時間とindexを組み合わせて異なる高さを生成
          final time = DateTime.now().millisecondsSinceEpoch / 200;
          final wave1 = sin(time + index * 0.5);
          final wave2 = cos((time * 1.3) + index * 0.7);
          final combined = (wave1 + wave2) / 2;

          // 高さを10〜35pxの範囲で変化
          final animatedHeight = 10 + (12.5 * (1 + combined));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 10,
                end: _isListening ? animatedHeight : 10,
              ),
              duration: const Duration(milliseconds: 150),
              builder: (context, height, child) {
                return Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.red.shade700,
                        Colors.red.shade500,
                        Colors.red.shade300,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJudgingState() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          '判定中...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildResultState() {
    return Column(
      children: [
        // 正誤表示
        Icon(
          _isCorrect ? Icons.check_circle : Icons.cancel,
          size: 120,
          color: _isCorrect ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 24),
        Text(
          _feedbackMessage,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _isCorrect ? Colors.green : Colors.red,
          ),
        ),
        if (_recognizedText.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isCorrect ? Colors.green.shade200 : Colors.red.shade200,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'あなたの回答',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _recognizedText,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
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

/// 情報カード表示ウィジェット
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// ひらがな表示円形ウィジェット
class _KanaCircle extends StatelessWidget {
  final String kana;
  final String label;
  final Color color;

  const _KanaCircle({
    required this.kana,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.4),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              kana,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
