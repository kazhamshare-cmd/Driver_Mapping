import 'room_models.dart';

/// ゲーム状態
enum GameState {
  ready,                // 準備完了
  waitingForOpponent,   // 相手待ち
  answering,            // 回答中
  judging,              // 判定中
  showResult,           // 結果表示
  gameOver,             // ゲーム終了
}

/// 回答情報
class Answer {
  final String word;
  final bool isCorrect;
  final DateTime answeredAt;
  final int points;
  final String playerId;
  final String playerName;

  Answer({
    required this.word,
    required this.isCorrect,
    required this.answeredAt,
    required this.playerId,
    required this.playerName,
    this.points = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'isCorrect': isCorrect,
      'answeredAt': answeredAt.toIso8601String(),
      'points': points,
      'playerId': playerId,
      'playerName': playerName,
    };
  }

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      word: map['word'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
      answeredAt: DateTime.parse(map['answeredAt'] ?? DateTime.now().toIso8601String()),
      points: map['points'] ?? 0,
      playerId: map['playerId'] ?? '',
      playerName: map['playerName'] ?? '',
    );
  }
}

/// ゲームルーム（オフライン用）
class GameRoom {
  final String id;
  final String name;
  final List<Player> players;
  final Challenge? currentChallenge;
  final int currentPlayerIndex;
  final List<String> usedWords;
  final GameState state;
  final int currentTurnIndex;
  final int maxRounds;
  final int roundNumber;
  final List<Answer> answers;

  GameRoom({
    required this.id,
    required this.name,
    required this.players,
    this.currentChallenge,
    this.currentPlayerIndex = 0,
    this.usedWords = const [],
    this.state = GameState.ready,
    this.currentTurnIndex = 0,
    this.maxRounds = 10,
    this.roundNumber = 1,
    this.answers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'players': players.map((p) => p.toMap()).toList(),
      'currentChallenge': currentChallenge?.toMap(),
      'currentPlayerIndex': currentPlayerIndex,
      'usedWords': usedWords,
      'state': state.name,
      'currentTurnIndex': currentTurnIndex,
      'maxRounds': maxRounds,
      'roundNumber': roundNumber,
      'answers': answers.map((a) => a.toMap()).toList(),
    };
  }

  factory GameRoom.fromMap(Map<String, dynamic> map) {
    return GameRoom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      players: (map['players'] as List<dynamic>?)
          ?.map((p) => Player.fromMap(p))
          .toList() ?? [],
      currentChallenge: map['currentChallenge'] != null 
          ? Challenge.fromMap(map['currentChallenge']) 
          : null,
      currentPlayerIndex: map['currentPlayerIndex'] ?? 0,
      usedWords: List<String>.from(map['usedWords'] ?? []),
      state: GameState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => GameState.ready,
      ),
      currentTurnIndex: map['currentTurnIndex'] ?? 0,
      maxRounds: map['maxRounds'] ?? 10,
      roundNumber: map['roundNumber'] ?? 1,
      answers: (map['answers'] as List<dynamic>?)
          ?.map((a) => Answer.fromMap(a))
          .toList() ?? [],
    );
  }
}

/// ゲーム結果
class GameResult {
  final String winnerId;
  final String winnerName;
  final int winnerScore;
  final List<Player> finalStandings;
  final DateTime completedAt;
  final List<Answer> answers;
  final int totalRounds;

  GameResult({
    required this.winnerId,
    required this.winnerName,
    required this.winnerScore,
    required this.finalStandings,
    required this.completedAt,
    required this.answers,
    required this.totalRounds,
  });

  Map<String, dynamic> toMap() {
    return {
      'winnerId': winnerId,
      'winnerName': winnerName,
      'winnerScore': winnerScore,
      'finalStandings': finalStandings.map((p) => p.toMap()).toList(),
      'completedAt': completedAt.toIso8601String(),
      'answers': answers.map((a) => a.toMap()).toList(),
      'totalRounds': totalRounds,
    };
  }

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      winnerId: map['winnerId'] ?? '',
      winnerName: map['winnerName'] ?? '',
      winnerScore: map['winnerScore'] ?? 0,
      finalStandings: (map['finalStandings'] as List<dynamic>?)
          ?.map((p) => Player.fromMap(p))
          .toList() ?? [],
      completedAt: DateTime.parse(map['completedAt'] ?? DateTime.now().toIso8601String()),
      answers: (map['answers'] as List<dynamic>?)
          ?.map((a) => Answer.fromMap(a))
          .toList() ?? [],
      totalRounds: map['totalRounds'] ?? 0,
    );
  }
}