import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import '../models/question.dart';
import '../services/firebase_service.dart';
import '../services/question_service.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';
import '../widgets/answer_area.dart';
import '../widgets/draggable_character.dart';
import '../widgets/blinking_text.dart';
import 'online_game_over_screen.dart';

class OnlineGameScreen extends StatefulWidget {
  final String roomId;
  final String playerId;
  final bool isHost;

  const OnlineGameScreen({
    super.key,
    required this.roomId,
    required this.playerId,
    required this.isHost,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final QuestionService _questionService = QuestionService();

  Question? _currentQuestion;
  List<String?> _answer = [];
  List<String> _availableCharacters = [];
  bool _hasAnswered = false;
  String? _lastQuestionText; // 最後に処理した問題テキストを記録
  bool _hasScheduledNextStage = false; // 次ステージ処理をスケジュール済みか
  int? _lastProcessedStage; // 最後に処理したステージ番号
  bool _hasNavigatedToGameOver = false; // ゲームオーバー画面への遷移フラグ
  bool _hasNavigatedToHome = false; // ホーム画面への遷移フラグ
  Set<String> _notifiedPlayerIds = {}; // 通知済みのプレイヤーID（モーダル表示済み）

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

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
    // ゲーム画面用BGM（80%ボリューム）
    SoundService().setBgmVolumeForGame();
    // ホストのみが問題を生成
    if (widget.isHost) {
      _generateQuestion();
    }
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

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _generateQuestion() async {
    final question = _questionService.getRandomQuestion();

    // 正解の文字とフェイク文字から重複を除いて選択肢を作成
    final allChars = [
      ...question.characters,
      ..._fakeCharacters,
    ];
    final availableChars = allChars.toSet().toList(); // 重複削除
    availableChars.shuffle();

    setState(() {
      _currentQuestion = question;
      _answer = List.filled(question.answer.length, null);
      _availableCharacters = availableChars;
      _lastQuestionText = question.text; // 問題テキストを記録
    });

    // Firestoreに問題を保存
    await _firebaseService.updateQuestion(
      roomId: widget.roomId,
      question: question.text,
    );
  }

  void _onCharacterDropped(String character, int index) {
    setState(() {
      // 既存の配置位置から削除
      final existingIndex = _answer.indexOf(character);
      if (existingIndex != -1) {
        _answer[existingIndex] = null;
      }

      _answer[index] = character;
    });
    SoundService().playDrop();
  }

  void _onCharacterReordered(int fromIndex, int toIndex) {
    setState(() {
      final temp = _answer[fromIndex];
      _answer[fromIndex] = _answer[toIndex];
      _answer[toIndex] = temp;
    });
    SoundService().playDrop();
  }

  void _onCharacterRemoved(int index) {
    setState(() {
      _answer[index] = null;
    });
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

  Future<void> _checkAnswer() async {
    if (_hasAnswered) return;

    final userAnswer = _answer.where((c) => c != null).join('');
    final isCorrect = userAnswer == _currentQuestion!.answer;

    setState(() {
      _hasAnswered = true;
    });

    // 回答を記録（回答内容も保存）
    await _firebaseService.recordAnswer(
      roomId: widget.roomId,
      playerId: widget.playerId,
      isCorrect: isCorrect,
      answer: userAnswer, // 回答内容を追加
    );

    // 音は再生しない（StreamBuilderで全プレイヤーの回答を検知した時に再生）

    // 次のステージへの制御はStreamBuilder内で行う
    // （誰かが1人でも回答したら自動的に次へ進む）
  }

  void _showPlayerResultDialog(Player player) {
    final isCurrentPlayer = player.id == widget.playerId;
    final isCorrect = player.isCorrect;
    final playerAnswer = player.answer ?? '';

    // 2秒後に自動的にモーダルをクローズ
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${player.name}の結果',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCurrentPlayer) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'あなた',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isCorrect ? '正解!' : '不正解',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
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
            // プレイヤーの回答を表示
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '回答: ',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    playerAnswer.isEmpty ? '(未入力)' : playerAnswer,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              // 正解を表示（不正解の場合のみ）
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
            ],
          ],
        ),
        actions: const [],
      ),
    ).then((_) {
      // ダイアログが閉じられた後の処理
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ゲーム中断'),
            content: const Text('ゲームを中断してルームから退出しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('いいえ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('はい'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await _firebaseService.leaveRoom(
            roomId: widget.roomId,
            playerId: widget.playerId,
          );
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('オンライン対戦'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
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
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              // ルームが削除された（1回だけ遷移）
              if (!_hasNavigatedToHome) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_hasNavigatedToHome) {
                    setState(() {
                      _hasNavigatedToHome = true;
                    });
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ホストがルームを削除しました')),
                    );
                  }
                });
              }
              return const Center(child: Text('ルームが削除されました'));
            }

            final room = GameRoom.fromMap(data);

            // プレイヤーが1人になった場合（1回だけ遷移）
            if (room.players.length < 2 && !_hasNavigatedToHome) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigatedToHome) {
                  setState(() {
                    _hasNavigatedToHome = true;
                  });

                  // ホストの場合はルームを削除
                  if (widget.isHost) {
                    _firebaseService.deleteRoom(widget.roomId);
                  }

                  Navigator.of(context).popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('対戦相手が退出しました')),
                  );
                }
              });
            }

            // ゲーム終了（1回だけ遷移）
            if (room.status == RoomStatus.finished && !_hasNavigatedToGameOver) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigatedToGameOver) {
                  setState(() {
                    _hasNavigatedToGameOver = true;
                  });
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => OnlineGameOverScreen(
                        roomId: widget.roomId,
                        playerId: widget.playerId,
                        isHost: widget.isHost,
                      ),
                    ),
                  );
                }
              });
            }

            // 問題が更新されたら反映（ゲストのみ）
            if (!widget.isHost && room.currentQuestion != null) {
              // 最後に処理した問題と異なる場合のみ更新
              if (_lastQuestionText != room.currentQuestion) {
                final newQuestionText = room.currentQuestion;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_lastQuestionText != newQuestionText && mounted) {
                    final question =
                        _questionService.getQuestionByText(newQuestionText!);
                    if (question != null) {
                      // 正解の文字とフェイク文字から重複を除いて選択肢を作成
                      final allChars = [
                        ...question.characters,
                        ..._fakeCharacters,
                      ];
                      final availableChars = allChars.toSet().toList(); // 重複削除
                      availableChars.shuffle();

                      // 開いているダイアログを全て閉じる
                      // Note: ModalRoute.of(context)?.isCurrent == falseの場合のみダイアログが開いている
                      if (ModalRoute.of(context)?.isCurrent == false) {
                        Navigator.of(context).popUntil((route) => route.isCurrent);
                      }

                      setState(() {
                        _currentQuestion = question;
                        _answer = List.filled(question.answer.length, null);
                        _availableCharacters = availableChars;
                        _hasAnswered = false;
                        _lastQuestionText = newQuestionText;
                        _hasScheduledNextStage = false;
                        _notifiedPlayerIds.clear(); // 通知済みリストをクリア
                      });
                    }
                  }
                });
              }
            }

            // ステージが変わったらフラグをリセット
            if (_lastProcessedStage != null && _lastProcessedStage != room.currentStage) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _hasScheduledNextStage = false;
                    _lastProcessedStage = room.currentStage;
                  });
                }
              });
            }

            // 次のステージへ進む条件（ホストが制御）
            // 誰か1人でも回答したら次へ進む
            final shouldProceed = room.players.any((p) => p.hasAnswered);

            if (widget.isHost &&
                shouldProceed &&
                room.players.isNotEmpty &&
                !_hasScheduledNextStage &&
                (_lastProcessedStage == null || _lastProcessedStage == room.currentStage)) {
              print('DEBUG online_game_screen: currentStage=${room.currentStage}, maxStages=${room.maxStages}, shouldProceed=$shouldProceed');
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!_hasScheduledNextStage && mounted) {
                  setState(() {
                    _hasScheduledNextStage = true;
                    _lastProcessedStage = room.currentStage;
                  });
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    // プレイヤーの回答状態をリセット
                    await _firebaseService.nextStage(widget.roomId);
                    // Firestoreの更新が確実に反映されるまで待つ
                    await Future.delayed(const Duration(milliseconds: 800));
                    if (mounted) {
                      // 新しい問題を生成
                      await _generateQuestion();
                    }
                  }
                }
              });
            }

            // 全プレイヤーの回答をモーダルで表示
            for (final player in room.players) {
              if (player.hasAnswered &&
                  !_notifiedPlayerIds.contains(player.id)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_notifiedPlayerIds.contains(player.id)) {
                    setState(() {
                      _notifiedPlayerIds.add(player.id);
                    });

                    // 音を再生
                    if (player.isCorrect) {
                      SoundService().playCorrect();
                    } else {
                      SoundService().playIncorrect();
                    }

                    // モーダルで結果表示
                    _showPlayerResultDialog(player);
                  }
                });
              }
            }

            return Column(
              children: [
                // プレイヤー情報と進捗
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.deepPurple.shade50,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ステージ ${room.currentStage + 1}/${room.maxStages}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // プレイヤーのスコア表示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: room.players.map((player) {
                          final isCurrentPlayer =
                              player.id == widget.playerId;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentPlayer
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  player.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentPlayer
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                Text(
                                  '${player.score}点',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentPlayer
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                if (player.hasAnswered) ...[
                                  Icon(
                                    player.isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: player.isCorrect
                                        ? Colors.green
                                        : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    player.answer ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: player.isCorrect
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // ゲームエリア
                Expanded(
                  child: _currentQuestion == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // 鏡文字
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.deepPurple,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      offset: const Offset(0, 4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Transform.scale(
                                  scaleX: -1,
                                  child: Text(
                                    _currentQuestion!.text,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // 回答エリア
                              AnswerArea(
                                answer: _answer,
                                onCharacterDropped: _onCharacterDropped,
                                onCharacterReordered: _onCharacterReordered,
                                onCharacterRemoved: _onCharacterRemoved,
                              ),
                              const SizedBox(height: 24),

                              // 利用可能な文字
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '文字を選んで',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  BlinkingText(
                                    text: '回答エリアにドラッグ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const Text(
                                    'してください',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: _availableCharacters.map((char) {
                                  final isPlaced = _answer.contains(char);
                                  return DraggableCharacter(
                                    character: char,
                                    isPlaced: isPlaced,
                                    onTap: () => _onCharacterTapped(char),
                                    enableDrag: false, // ドラッグ無効（タップのみ）
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 32),

                              // 回答ボタン
                              ElevatedButton(
                                onPressed: _hasAnswered ||
                                        _answer.any((c) => c == null)
                                    ? null
                                    : _checkAnswer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _hasAnswered ? '回答済み' : '回答する',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
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
            );
          },
        ),
      ),
    );
  }
}
