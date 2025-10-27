import 'package:uuid/uuid.dart';
import 'game_models.dart' as game_models;

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
  final int currentPlayerIndex; // 現在のターンのプレイヤーインデックス
  final List<String> usedWords; // 現在のお題で使用済みの単語
  final game_models.Challenge? currentChallenge; // 現在のお題

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
    this.currentPlayerIndex = 0, // デフォルトは最初のプレイヤー
    this.usedWords = const [], // デフォルトは空リスト
    this.currentChallenge, // デフォルトはnull
  });

  /// ルーム作成
  factory Room.create({
    required String name,
    required String hostName,
    String? password,
    int maxPlayers = 4,
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
      currentPlayerIndex: 0, // 最初のプレイヤーから開始
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
      'currentPlayerIndex': currentPlayerIndex,
      'usedWords': usedWords,
      'currentChallenge': currentChallenge?.toJson(),
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
      currentPlayerIndex: map['currentPlayerIndex'] ?? 0,
      usedWords: (map['usedWords'] as List<dynamic>?)
          ?.map((w) => w.toString())
          .toList() ?? [],
      currentChallenge: map['currentChallenge'] != null
          ? game_models.Challenge.fromJson(map['currentChallenge'])
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
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
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
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
    );
  }

  /// ルーム開始
  Room startGame() {
    // すべてのプレイヤーのステータスをplayingに変更
    final playingPlayers = players.map((player) {
      return player.updateStatus(PlayerStatus.playing);
    }).toList();

    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: playingPlayers,
      status: RoomStatus.playing,
      maxPlayers: maxPlayers,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
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
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
    );
  }

  /// ルームをリセットしてもう一度遊ぶ
  Room resetForReplay() {
    // 全プレイヤーのステータスを waiting に戻す
    final resetPlayers = players.map((player) {
      return player.updateStatus(PlayerStatus.waiting);
    }).toList();

    return Room(
      id: id,
      name: name,
      hostName: hostName,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: resetPlayers,
      status: RoomStatus.waiting,
      maxPlayers: maxPlayers,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
    );
  }

  /// パスワード保護かどうか
  bool get isPasswordProtected => password != null && password!.isNotEmpty;

  /// 参加可能かどうか
  bool get canJoin => status == RoomStatus.waiting && players.length < maxPlayers;

  /// プレイヤー数
  int get playerCount => players.length;

  /// ホスト変更（最初のプレイヤーを新しいホストにする）
  Room changeHost() {
    if (players.isEmpty) return this;

    final newPlayers = players.map((player) {
      return Player(
        id: player.id,
        name: player.name,
        isHost: player == players.first, // 最初のプレイヤーをホストに
        joinedAt: player.joinedAt,
        status: player.status,
      );
    }).toList();

    return Room(
      id: id,
      name: name,
      hostName: newPlayers.first.name,
      password: password,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      players: newPlayers,
      status: status,
      maxPlayers: maxPlayers,
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
    );
  }

  /// プレイヤーステータス更新
  Room updatePlayerStatus(String playerId, PlayerStatus newStatus) {
    final newPlayers = players.map((player) {
      if (player.id == playerId) {
        return player.updateStatus(newStatus);
      }
      return player;
    }).toList();

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
      currentPlayerIndex: currentPlayerIndex,
      usedWords: usedWords,
      currentChallenge: currentChallenge,
    );
  }

  /// アクティブなプレイヤー数を取得（脱落していないプレイヤー）
  int get activePlayerCount => players.where((p) => p.status == PlayerStatus.playing).length;

  /// アクティブなプレイヤーリストを取得
  List<Player> get activePlayers => players.where((p) => p.status == PlayerStatus.playing).toList();
}

/// プレイヤー情報
class Player {
  final String id;
  final String name;
  final bool isHost;
  final DateTime joinedAt;
  final PlayerStatus status;

  Player({
    required this.id,
    required this.name,
    required this.isHost,
    required this.joinedAt,
    this.status = PlayerStatus.waiting,
  });

  /// Firebase用のMap変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
      'status': status.name,
    };
  }

  /// FirebaseからPlayer作成
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
    );
  }
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
  eliminated, // 脱落
  finished,   // 終了
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

  CreateRoomRequest({
    required this.roomName,
    required this.hostName,
    this.password,
    this.maxPlayers = 4,
  });
}
