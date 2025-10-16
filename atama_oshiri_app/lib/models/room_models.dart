import 'package:uuid/uuid.dart';

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
    );
  }

  /// パスワード保護かどうか
  bool get isPasswordProtected => password != null && password!.isNotEmpty;

  /// 参加可能かどうか
  bool get canJoin => status == RoomStatus.waiting && players.length < maxPlayers;

  /// プレイヤー数
  int get playerCount => players.length;
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
