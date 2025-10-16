import 'dart:convert';

/// ゲームモードの列挙型
enum GameMode {
  solo,     // 一人モード
  offline,  // オフライン多人数対戦
  online,   // オンライン多人数対戦
}

/// プレイヤーの状態
enum PlayerStatus {
  waiting,    // 待機中
  playing,    // プレイ中
  eliminated, // 脱落
  finished,   // ゲーム終了
}

/// ゲームの状態
enum GameStatus {
  waiting,    // 待機中
  playing,    // プレイ中
  finished,   // 終了
}

/// お題（頭とお尻の文字）
class Challenge {
  final String head;  // 頭の文字
  final String tail;  // お尻の文字

  Challenge({
    required this.head,
    required this.tail,
  });

  Map<String, dynamic> toJson() {
    return {
      'head': head,
      'tail': tail,
    };
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      head: json['head'],
      tail: json['tail'],
    );
  }

  @override
  String toString() => '「$head」で始まり「$tail」で終わる';
}

/// プレイヤー情報
class Player {
  final String id;
  final String name;
  PlayerStatus status;
  int score;  // 得点（しりとりの回数ではなく、文字数の合計）
  int wordCount;  // 回答した単語数
  DateTime? lastActionTime;

  Player({
    required this.id,
    required this.name,
    this.status = PlayerStatus.waiting,
    this.score = 0,
    this.wordCount = 0,
    this.lastActionTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'score': score,
      'wordCount': wordCount,
      'lastActionTime': lastActionTime?.toIso8601String(),
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      status: PlayerStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PlayerStatus.waiting,
      ),
      score: json['score'] ?? 0,
      wordCount: json['wordCount'] ?? 0,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'])
          : null,
    );
  }

  Player copyWith({
    String? id,
    String? name,
    PlayerStatus? status,
    int? score,
    int? wordCount,
    DateTime? lastActionTime,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      score: score ?? this.score,
      wordCount: wordCount ?? this.wordCount,
      lastActionTime: lastActionTime ?? this.lastActionTime,
    );
  }
}

/// 回答の記録
class Answer {
  final String word;
  final String playerId;
  final String playerName;
  final int points;  // この回答で獲得した得点
  final Challenge challenge;
  final DateTime timestamp;

  Answer({
    required this.word,
    required this.playerId,
    required this.playerName,
    required this.points,
    required this.challenge,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'playerId': playerId,
      'playerName': playerName,
      'points': points,
      'challenge': challenge.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      word: json['word'],
      playerId: json['playerId'],
      playerName: json['playerName'],
      points: json['points'],
      challenge: Challenge.fromJson(json['challenge']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// ゲームルーム情報（オンライン/オフライン共通）
class GameRoom {
  final String id;
  final String roomCode;
  final String hostId;
  final int maxPlayers;
  final String? password;
  final List<Player> players;
  final GameStatus status;
  final String currentPlayerId;
  final int currentTurnIndex;
  final Challenge currentChallenge;
  final List<Answer> answers;  // 回答履歴
  final Set<String> usedWords;  // 使用済み単語（同じ単語の重複を防ぐ）
  final List<Player> eliminatedPlayers;
  final DateTime createdAt;
  final DateTime? turnDeadline;
  final int roundNumber;  // ラウンド数
  final int maxRounds;    // 最大ラウンド数（一人モードでは無制限=-1）

  GameRoom({
    required this.id,
    required this.roomCode,
    required this.hostId,
    required this.maxPlayers,
    this.password,
    required this.players,
    this.status = GameStatus.waiting,
    required this.currentPlayerId,
    this.currentTurnIndex = 0,
    required this.currentChallenge,
    this.answers = const [],
    this.usedWords = const {},
    this.eliminatedPlayers = const [],
    required this.createdAt,
    this.turnDeadline,
    this.roundNumber = 1,
    this.maxRounds = 10,  // デフォルトは10ラウンド
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomCode': roomCode,
      'hostId': hostId,
      'maxPlayers': maxPlayers,
      'password': password,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status.name,
      'currentPlayerId': currentPlayerId,
      'currentTurnIndex': currentTurnIndex,
      'currentChallenge': currentChallenge.toJson(),
      'answers': answers.map((a) => a.toJson()).toList(),
      'usedWords': usedWords.toList(),
      'eliminatedPlayers': eliminatedPlayers.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'turnDeadline': turnDeadline?.toIso8601String(),
      'roundNumber': roundNumber,
      'maxRounds': maxRounds,
    };
  }

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'],
      roomCode: json['roomCode'],
      hostId: json['hostId'],
      maxPlayers: json['maxPlayers'],
      password: json['password'],
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p))
          .toList(),
      status: GameStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameStatus.waiting,
      ),
      currentPlayerId: json['currentPlayerId'],
      currentTurnIndex: json['currentTurnIndex'] ?? 0,
      currentChallenge: Challenge.fromJson(json['currentChallenge']),
      answers: (json['answers'] as List? ?? [])
          .map((a) => Answer.fromJson(a))
          .toList(),
      usedWords: Set<String>.from(json['usedWords'] ?? []),
      eliminatedPlayers: (json['eliminatedPlayers'] as List? ?? [])
          .map((p) => Player.fromJson(p))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      turnDeadline: json['turnDeadline'] != null
          ? DateTime.parse(json['turnDeadline'])
          : null,
      roundNumber: json['roundNumber'] ?? 1,
      maxRounds: json['maxRounds'] ?? 10,
    );
  }

  GameRoom copyWith({
    String? id,
    String? roomCode,
    String? hostId,
    int? maxPlayers,
    String? password,
    List<Player>? players,
    GameStatus? status,
    String? currentPlayerId,
    int? currentTurnIndex,
    Challenge? currentChallenge,
    List<Answer>? answers,
    Set<String>? usedWords,
    List<Player>? eliminatedPlayers,
    DateTime? createdAt,
    DateTime? turnDeadline,
    int? roundNumber,
    int? maxRounds,
  }) {
    return GameRoom(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      password: password ?? this.password,
      players: players ?? this.players,
      status: status ?? this.status,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      currentChallenge: currentChallenge ?? this.currentChallenge,
      answers: answers ?? this.answers,
      usedWords: usedWords ?? this.usedWords,
      eliminatedPlayers: eliminatedPlayers ?? this.eliminatedPlayers,
      createdAt: createdAt ?? this.createdAt,
      turnDeadline: turnDeadline ?? this.turnDeadline,
      roundNumber: roundNumber ?? this.roundNumber,
      maxRounds: maxRounds ?? this.maxRounds,
    );
  }
}

/// ゲーム結果
class GameResult {
  final String? winnerId;
  final String? winnerName;
  final int? winnerScore;
  final List<Answer> answers;
  final int totalRounds;
  final List<Player> finalStandings;  // 最終順位
  final Map<String, int> playerScores;
  final DateTime finishedAt;

  GameResult({
    this.winnerId,
    this.winnerName,
    this.winnerScore,
    required this.answers,
    required this.totalRounds,
    required this.finalStandings,
    required this.playerScores,
    required this.finishedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'winnerId': winnerId,
      'winnerName': winnerName,
      'winnerScore': winnerScore,
      'answers': answers.map((a) => a.toJson()).toList(),
      'totalRounds': totalRounds,
      'finalStandings': finalStandings.map((p) => p.toJson()).toList(),
      'playerScores': playerScores,
      'finishedAt': finishedAt.toIso8601String(),
    };
  }

  factory GameResult.fromJson(Map<String, dynamic> json) {
    return GameResult(
      winnerId: json['winnerId'],
      winnerName: json['winnerName'],
      winnerScore: json['winnerScore'],
      answers: (json['answers'] as List)
          .map((a) => Answer.fromJson(a))
          .toList(),
      totalRounds: json['totalRounds'],
      finalStandings: (json['finalStandings'] as List)
          .map((p) => Player.fromJson(p))
          .toList(),
      playerScores: Map<String, int>.from(json['playerScores']),
      finishedAt: DateTime.parse(json['finishedAt']),
    );
  }
}

/// 戦績情報
class GameStats {
  final int totalGames;
  final int totalScore;
  final int highestScore;
  final int longestWord;
  final DateTime? lastPlayed;
  final Map<String, int> modeStats;

  GameStats({
    this.totalGames = 0,
    this.totalScore = 0,
    this.highestScore = 0,
    this.longestWord = 0,
    this.lastPlayed,
    this.modeStats = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'totalGames': totalGames,
      'totalScore': totalScore,
      'highestScore': highestScore,
      'longestWord': longestWord,
      'lastPlayed': lastPlayed?.toIso8601String(),
      'modeStats': modeStats,
    };
  }

  factory GameStats.fromJson(Map<String, dynamic> json) {
    return GameStats(
      totalGames: json['totalGames'] ?? 0,
      totalScore: json['totalScore'] ?? 0,
      highestScore: json['highestScore'] ?? 0,
      longestWord: json['longestWord'] ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'])
          : null,
      modeStats: Map<String, int>.from(json['modeStats'] ?? {}),
    );
  }

  GameStats copyWith({
    int? totalGames,
    int? totalScore,
    int? highestScore,
    int? longestWord,
    DateTime? lastPlayed,
    Map<String, int>? modeStats,
  }) {
    return GameStats(
      totalGames: totalGames ?? this.totalGames,
      totalScore: totalScore ?? this.totalScore,
      highestScore: highestScore ?? this.highestScore,
      longestWord: longestWord ?? this.longestWord,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      modeStats: modeStats ?? this.modeStats,
    );
  }
}
