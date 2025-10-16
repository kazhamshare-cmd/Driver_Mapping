import 'dart:math';
import '../models/game_models.dart';
import '../models/dictionary_model.dart';

/// 頭お尻ゲームのロジックサービス
class GameLogicService {
  static GameLogicService? _instance;
  static GameLogicService get instance => _instance ??= GameLogicService._();

  GameLogicService._();

  final DictionaryModel _dictionary = DictionaryModel.instance;
  final Random _random = Random();
  
  // 重複防止用の履歴
  final List<String> _recentChallenges = []; // 最近のお題を記録
  static const int maxRecentChallenges = 5; // 直近5個のお題を記録

  // ひらがな一覧（濁音・半濁音は基本形に統一、「ん」を除く）
  static const List<String> _hiraganaList = [
    'あ', 'い', 'う', 'え', 'お',
    'か', 'き', 'く', 'け', 'こ',
    'さ', 'し', 'す', 'せ', 'そ',
    'た', 'ち', 'つ', 'て', 'と',
    'な', 'に', 'ぬ', 'ね', 'の',
    'は', 'ひ', 'ふ', 'へ', 'ほ',
    'ま', 'み', 'む', 'め', 'も',
    'や', 'ゆ', 'よ',
    'ら', 'り', 'る', 'れ', 'ろ',
    'わ', 'を',
  ];

  /// ランダムなお題を生成（回答例が10つ以上あるもの）
  Challenge generateChallenge() {
    int attempts = 0;
    const maxAttempts = 200; // 試行回数を増やす

    while (attempts < maxAttempts) {
      final head = _hiraganaList[_random.nextInt(_hiraganaList.length)];
      final tail = _hiraganaList[_random.nextInt(_hiraganaList.length)];
      final challengeKey = '${head}_${tail}';
      final challenge = Challenge(head: head, tail: tail);

      // 直近のお題と重複しないかチェック
      if (!_recentChallenges.contains(challengeKey) && isChallengeValid(challenge)) {
        _recentChallenges.add(challengeKey);
        if (_recentChallenges.length > maxRecentChallenges) {
          _recentChallenges.removeAt(0); // 古いものを削除
        }
        
        final examples = generateAnswerExamples(challenge, limit: 10);
        print('🎲 新しいお題を生成: 頭=$head, お尻=$tail (解答数: ${examples.length})');
        return challenge;
      }

      attempts++;
    }

    // フォールバック: 無効なお題でも返す
    print('⚠️ 有効なお題が見つからなかったため、ランダムなお題を返します');
    final head = _hiraganaList[_random.nextInt(_hiraganaList.length)];
    final tail = _hiraganaList[_random.nextInt(_hiraganaList.length)];
    return Challenge(head: head, tail: tail);
  }

  /// 回答が正しいかチェックし、得点を計算
  /// 戻り値: {isValid: bool, points: int, message: String}
  Map<String, dynamic> validateAnswer({
    required String word,
    required Challenge challenge,
    required Set<String> usedWords,
  }) {
    // 空の回答
    if (word.isEmpty) {
      return {
        'isValid': false,
        'points': 0,
        'message': 'タイムアウト',
      };
    }

    // 既に使用された単語
    if (usedWords.contains(word)) {
      return {
        'isValid': false,
        'points': 0,
        'message': '既に使用された単語です',
      };
    }

    // 頭お尻ゲーム用の総合チェック
    if (!_dictionary.isWordValidForHeadTail(word, challenge.head, challenge.tail)) {
      return {
        'isValid': false,
        'points': 0,
        'message': '条件に合わない単語です',
      };
    }

    // 最小文字数チェック（3文字以上）
    if (word.length < 3) {
      return {
        'isValid': false,
        'points': 0,
        'message': '3文字以上の単語を入力してください',
      };
    }

    // 得点計算：頭とお尻を除いた文字数
    final points = calculatePoints(word, challenge);

    if (points < 0) {
      return {
        'isValid': false,
        'points': 0,
        'message': '単語が短すぎます',
      };
    }

    return {
      'isValid': true,
      'points': points,
      'message': '$points点獲得！',
    };
  }

  /// 得点計算：頭とお尻を除いた文字数
  int calculatePoints(String word, Challenge challenge) {
    if (word.length < 3) {
      return -1; // 3文字未満は無効
    }

    // 頭とお尻を除いた文字数を計算
    final middleLength = word.length - 2;
    return middleLength;
  }

  /// 単語の詳細情報を取得
  String getWordDetails(String word, Challenge challenge) {
    final points = calculatePoints(word, challenge);
    final middlePart = word.length >= 3
        ? word.substring(1, word.length - 1)
        : '';

    return '「$word」: ${word.length}文字 (中: ${middlePart.isEmpty ? "なし" : middlePart} = $points点)';
  }

  /// 次のプレイヤーを取得（脱落していないプレイヤー）
  Map<String, dynamic>? getNextPlayer(GameRoom room) {
    int nextIndex = (room.currentTurnIndex + 1) % room.players.length;
    final startIndex = nextIndex;

    do {
      final player = room.players[nextIndex];
      if (player.status == PlayerStatus.playing) {
        return {
          'index': nextIndex,
          'playerId': player.id,
          'player': player,
        };
      }
      nextIndex = (nextIndex + 1) % room.players.length;
    } while (nextIndex != startIndex);

    return null; // アクティブなプレイヤーがいない
  }

  /// 最終順位を決定（得点順）
  List<Player> calculateFinalStandings(List<Player> players) {
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    return sortedPlayers;
  }

  /// ゲーム終了判定
  bool isGameOver(GameRoom room) {
    // 最大ラウンド数に達した場合
    if (room.maxRounds > 0 && room.roundNumber > room.maxRounds) {
      return true;
    }

    // アクティブなプレイヤーが1人以下の場合（多人数モードのみ）
    final activePlayers = room.players
        .where((p) => p.status == PlayerStatus.playing)
        .toList();

    if (room.players.length > 1 && activePlayers.length <= 1) {
      return true;
    }

    return false;
  }

  /// ゲーム結果を生成
  GameResult generateGameResult(GameRoom room) {
    final finalStandings = calculateFinalStandings(room.players);
    final winner = finalStandings.first;

    final playerScores = <String, int>{};
    for (final player in room.players) {
      playerScores[player.id] = player.score;
    }

    return GameResult(
      winnerId: winner.id,
      winnerName: winner.name,
      winnerScore: winner.score,
      answers: room.answers,
      totalRounds: room.roundNumber - 1,
      finalStandings: finalStandings,
      playerScores: playerScores,
      finishedAt: DateTime.now(),
    );
  }

  /// お題のヒント文字列を生成
  String getChallengeHintText(Challenge challenge) {
    return '「${challenge.head}」で始まり「${challenge.tail}」で終わる単語';
  }

  /// 難易度を計算（簡単な単語があるかどうか）
  int estimateChallengeDifficulty(Challenge challenge) {
    // TODO: 辞書から該当する単語の数をカウントして難易度を推定
    // 今は仮の実装として、ランダムな難易度を返す
    return _random.nextInt(5) + 1; // 1-5の難易度
  }

  /// お題に対する回答例を生成（長音符対応）
  List<String> generateAnswerExamples(Challenge challenge, {int limit = 5}) {
    final examples = <String>[];

    // 辞書から頭文字で始まる単語を取得
    final wordsWithHead = _dictionary.getWordsStartingWith(challenge.head);

    // お尻の文字で終わる単語をフィルタリング（長音符対応）
    for (final word in wordsWithHead) {
      final lastChar = _dictionary.getLastCharForShiritori(word);
      
      if (lastChar == challenge.tail) {
        examples.add(word);
        if (examples.length >= limit) break;
      }
    }

    return examples;
  }

  /// お題が有効かチェック（回答例が10つ以上あるか）
  bool isChallengeValid(Challenge challenge) {
    final examples = generateAnswerExamples(challenge, limit: 10);
    return examples.length >= 10;
  }
  
  /// ゲーム開始時に重複防止履歴をリセット
  void resetRecentChallenges() {
    _recentChallenges.clear();
    print('🔄 お題重複防止履歴をリセットしました');
  }
}
