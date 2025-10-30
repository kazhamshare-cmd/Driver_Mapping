import 'package:uuid/uuid.dart';

/// プレイヤー情報
class Player {
  final String id;
  final String name;
  final bool isHost;
  final DateTime joinedAt;
  final PlayerStatus status;
  final int score;
  final int wordCount;

  Player({
    required this.id,
    required this.name,
    required this.isHost,
    required this.joinedAt,
    this.status = PlayerStatus.waiting,
    this.score = 0,
    this.wordCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
      'status': status.name,
      'score': score,
      'wordCount': wordCount,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isHost: map['isHost'] ?? false,
      joinedAt: DateTime.parse(map['joinedAt'] ?? DateTime.now().toIso8601String()),
      status: PlayerStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PlayerStatus.waiting,
      ),
      score: map['score'] ?? 0,
      wordCount: map['wordCount'] ?? 0,
    );
  }

  /// プレイヤー状態更新
  Player updateStatus(PlayerStatus newStatus) {
    return Player(
      id: id,
      name: name,
      isHost: isHost,
      joinedAt: joinedAt,
      status: newStatus,
      score: score,
      wordCount: wordCount,
    );
  }

  /// スコア更新
  Player updateScore(int newScore) {
    return Player(
      id: id,
      name: name,
      isHost: isHost,
      joinedAt: joinedAt,
      status: status,
      score: newScore,
      wordCount: wordCount,
    );
  }

  /// 単語数更新
  Player updateWordCount(int newWordCount) {
    return Player(
      id: id,
      name: name,
      isHost: isHost,
      joinedAt: joinedAt,
      status: status,
      score: score,
      wordCount: newWordCount,
    );
  }

  /// リセット
  Player reset() {
    return Player(
      id: id,
      name: name,
      isHost: isHost,
      joinedAt: joinedAt,
      status: PlayerStatus.playing, // ゲーム再開時はplaying状態にする
      score: 0,
      wordCount: 0,
    );
  }
}

/// お題（チャレンジ）
class Challenge {
  final String head;
  final String tail;
  final List<String> examples;

  Challenge({
    required this.head,
    required this.tail,
    required this.examples,
  });

  Map<String, dynamic> toMap() {
    return {
      'head': head,
      'tail': tail,
      'examples': examples,
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      head: map['head'] ?? '',
      tail: map['tail'] ?? '',
      examples: List<String>.from(map['examples'] ?? []),
    );
  }
}

/// ゲームモード
enum GameMode {
  suddenDeath,  // サドンデス（脱落者を決めていく）
  scoreMatch,   // 点数勝負（規定ラウンド終了後に点数で勝敗）
}

/// ルーム情報
class Room {
  final String id;
  final String name;
  final String hostName;
  final String? password;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Player> players;
  final RoomStatus status;
  final int maxPlayers;
  final Challenge? currentChallenge;
  final int currentPlayerIndex;
  final List<String> usedWords;
  final String? currentSpeechResult; // 現在の音声認識結果
  final GameMode gameMode; // ゲームモード
  final int totalRounds; // 総ラウンド数
  final int currentRound; // 現在のラウンド
  final bool shouldShowAd; // 広告を表示するかどうか（ホストが決定）
  final DateTime? turnStartedAt; // ターン開始時刻（同期用）

  Room({
    required this.id,
    required this.name,
    required this.hostName,
    this.password,
    required this.createdAt,
    required this.updatedAt,
    required this.players,
    this.status = RoomStatus.waiting,
    this.maxPlayers = 4,
    this.currentChallenge,
    this.currentPlayerIndex = 0,
    this.usedWords = const [],
    this.currentSpeechResult,
    this.gameMode = GameMode.suddenDeath,
    this.totalRounds = 5,
    this.currentRound = 1,
    this.shouldShowAd = false,
    this.turnStartedAt,
  });

  /// ルーム作成
  factory Room.create({
    required String name,
    required String hostName,
    String? password,
    int maxPlayers = 4,
    GameMode gameMode = GameMode.scoreMatch,
    int totalRounds = 5,
  }) {
    final now = DateTime.now();
    return Room(
      id: const Uuid().v4(),
      name: name,
      hostName: hostName,
      password: password,
      createdAt: now,
      updatedAt: now,
      players: [
        Player(
          id: const Uuid().v4(),
          name: hostName,
          isHost: true,
          joinedAt: now,
        ),
      ],
      maxPlayers: maxPlayers,
      currentChallenge: null,
      currentPlayerIndex: 0,
      usedWords: [],
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: 1,
    );
  }

  /// Firebase用のMap変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostName': hostName,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'players': players.map((p) => p.toMap()).toList(),
      'status': status.name,
      'maxPlayers': maxPlayers,
      'currentChallenge': currentChallenge?.toMap(),
      'currentPlayerIndex': currentPlayerIndex,
      'usedWords': usedWords,
      'currentSpeechResult': currentSpeechResult,
      'gameMode': gameMode.name,
      'totalRounds': totalRounds,
      'currentRound': currentRound,
      'shouldShowAd': shouldShowAd,
      'turnStartedAt': turnStartedAt?.toIso8601String(),
    };
  }

  /// FirebaseからRoom作成
  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      hostName: map['hostName'] ?? '',
      password: map['password'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      players: (map['players'] as List<dynamic>?)
          ?.map((p) => Player.fromMap(p))
          .toList() ?? [],
      status: RoomStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RoomStatus.waiting,
      ),
      maxPlayers: map['maxPlayers'] ?? 4,
      shouldShowAd: map['shouldShowAd'] ?? false,
      currentChallenge: map['currentChallenge'] != null
          ? Challenge.fromMap(map['currentChallenge'])
          : null,
      currentPlayerIndex: map['currentPlayerIndex'] ?? 0,
      usedWords: List<String>.from(map['usedWords'] ?? []),
      currentSpeechResult: map['currentSpeechResult'],
      gameMode: GameMode.values.firstWhere(
        (e) => e.name == map['gameMode'],
        orElse: () => GameMode.suddenDeath,
      ),
      totalRounds: map['totalRounds'] ?? 5,
      currentRound: map['currentRound'] ?? 1,
      turnStartedAt: map['turnStartedAt'] != null
          ? DateTime.parse(map['turnStartedAt'])
          : null,
    );
  }

  /// プレイヤー追加
  Room addPlayer(Player player) {
    if (players.length >= maxPlayers) {
      throw Exception('ルームが満員です');
    }

    final newPlayers = List<Player>.from(players)..add(player);
    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: newPlayers,
      status: status,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// プレイヤー削除
  Room removePlayer(String playerId) {
    final newPlayers = players.where((p) => p.id != playerId).toList();
    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: newPlayers,
      status: status,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// ルーム開始
  Room startGame() {
    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: players,
      status: RoomStatus.playing,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// ルーム終了
  Room endGame() {
    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: players,
      status: RoomStatus.finished,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// パスワード保護かどうか
  bool get isPasswordProtected => password != null && password!.isNotEmpty;

  /// 参加可能かどうか
  bool get canJoin => status == RoomStatus.waiting && players.length < maxPlayers;

  /// アクティブなプレイヤー（脱落していないプレイヤー）
  List<Player> get activePlayers => players.where((p) => p.status != PlayerStatus.eliminated).toList();

  /// プレイヤー状態更新
  Room updatePlayerStatus(String playerId, PlayerStatus newStatus) {
    final updatedPlayers = players.map((p) {
      if (p.id == playerId) {
        return p.updateStatus(newStatus);
      }
      return p;
    }).toList();

    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: updatedPlayers,
      status: status,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// ホスト変更
  Room changeHost() {
    if (players.isEmpty) return this;

    final newHost = players.firstWhere(
      (p) => !p.isHost,
      orElse: () => players.first,
    );

    final updatedPlayers = players.map((p) {
      if (p.id == newHost.id) {
        return Player(
          id: p.id,
          name: p.name,
          isHost: true,
          joinedAt: p.joinedAt,
          status: p.status,
          score: p.score,
        );
      } else if (p.isHost) {
        return Player(
          id: p.id,
          name: p.name,
          isHost: false,
          joinedAt: p.joinedAt,
          status: p.status,
          score: p.score,
        );
      }
      return p;
    }).toList();

    return Room(
      id: id,
      name: name,
      hostName: newHost.name,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: updatedPlayers,
      status: status,
      maxPlayers: maxPlayers,
      currentChallenge: currentChallenge,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: currentRound,
      shouldShowAd: shouldShowAd,
      turnStartedAt: turnStartedAt,
    );
  }

  /// もう一度遊ぶためにルームをリセット
  Room resetForReplay() {
    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: players.map((p) => Player(
        id: p.id,
        name: p.name,
        isHost: p.isHost,
        joinedAt: p.joinedAt,
        status: PlayerStatus.waiting,
        score: 0,
      )).toList(),
      status: RoomStatus.waiting,
      maxPlayers: maxPlayers,
      currentChallenge: null,
      currentPlayerIndex: 0,
      usedWords: [],
      gameMode: gameMode,
      totalRounds: totalRounds,
      currentRound: 1,
      shouldShowAd: false, // リセット時は広告フラグをfalseに
      turnStartedAt: null, // リセット時はターン開始時刻もクリア
    );
  }

  /// プレイヤー数
  int get playerCount => players.length;
}

/// ルーム状態
enum RoomStatus {
  waiting,    // 待機中
  playing,    // プレイ中
  finished,   // 終了
}

/// プレイヤー状態
enum PlayerStatus {
  waiting,    // 待機中
  ready,      // 準備完了
  playing,    // プレイ中
  finished,   // 終了
  eliminated, // 脱落
}

/// ルーム参加リクエスト
class JoinRoomRequest {
  final String roomId;
  final String playerName;
  final String? password;

  JoinRoomRequest({
    required this.roomId,
    required this.playerName,
    this.password,
  });
}

/// ルーム作成リクエスト
class CreateRoomRequest {
  final String roomName;
  final String hostName;
  final String? password;
  final int maxPlayers;
  final GameMode gameMode;
  final int totalRounds;

  CreateRoomRequest({
    required this.roomName,
    required this.hostName,
    this.password,
    this.maxPlayers = 4,
    this.gameMode = GameMode.suddenDeath,
    this.totalRounds = 5,
  });
}
