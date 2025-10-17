import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_settings.dart';

enum RoomType { public, private }
enum RoomStatus { waiting, playing, finished }

class OnlinePlayer {
  final String id;
  final String name;
  final bool isHost;
  final int score;
  final bool isActive;

  const OnlinePlayer({
    required this.id,
    required this.name,
    required this.isHost,
    this.score = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'score': score,
      'isActive': isActive,
    };
  }

  static OnlinePlayer fromMap(Map<String, dynamic> map) {
    return OnlinePlayer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isHost: map['isHost'] ?? false,
      score: map['score'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  OnlinePlayer copyWith({
    String? id,
    String? name,
    bool? isHost,
    int? score,
    bool? isActive,
  }) {
    return OnlinePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      score: score ?? this.score,
      isActive: isActive ?? this.isActive,
    );
  }
}

class OnlineRoom {
  final String id;
  final String name;
  final String hostId;
  final RoomType type;
  final String? password;
  final RoomStatus status;
  final List<OnlinePlayer> players;
  final GameSettings gameSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int maxPlayers;
  final String currentPlayerId;
  final int turnIndex;

  const OnlineRoom({
    required this.id,
    required this.name,
    required this.hostId,
    required this.type,
    this.password,
    required this.status,
    required this.players,
    required this.gameSettings,
    required this.createdAt,
    required this.updatedAt,
    this.maxPlayers = 100, // 無制限（実質的な上限）
    this.currentPlayerId = '',
    this.turnIndex = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hostId': hostId,
      'type': type.toString(),
      'password': password,
      'status': status.toString(),
      'players': players.map((p) => p.toMap()).toList(),
      'gameSettings': gameSettings.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'maxPlayers': maxPlayers,
      'currentPlayerId': currentPlayerId,
      'turnIndex': turnIndex,
    };
  }

  static OnlineRoom fromMap(Map<String, dynamic> map) {
    return OnlineRoom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      hostId: map['hostId'] ?? '',
      type: _parseRoomType(map['type']),
      password: map['password'],
      status: _parseRoomStatus(map['status']),
      players: (map['players'] as List<dynamic>?)
          ?.map((p) => OnlinePlayer.fromMap(p as Map<String, dynamic>))
          .toList() ?? [],
      gameSettings: GameSettings.fromMap(map['gameSettings'] ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
      maxPlayers: map['maxPlayers'] ?? 100,
      currentPlayerId: map['currentPlayerId'] ?? '',
      turnIndex: map['turnIndex'] ?? 0,
    );
  }

  static RoomType _parseRoomType(String? type) {
    switch (type) {
      case 'RoomType.private':
        return RoomType.private;
      default:
        return RoomType.public;
    }
  }

  static RoomStatus _parseRoomStatus(String? status) {
    switch (status) {
      case 'RoomStatus.playing':
        return RoomStatus.playing;
      case 'RoomStatus.finished':
        return RoomStatus.finished;
      default:
        return RoomStatus.waiting;
    }
  }

  OnlineRoom copyWith({
    String? id,
    String? name,
    String? hostId,
    RoomType? type,
    String? password,
    RoomStatus? status,
    List<OnlinePlayer>? players,
    GameSettings? gameSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? maxPlayers,
    String? currentPlayerId,
    int? turnIndex,
  }) {
    return OnlineRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      type: type ?? this.type,
      password: password ?? this.password,
      status: status ?? this.status,
      players: players ?? this.players,
      gameSettings: gameSettings ?? this.gameSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      turnIndex: turnIndex ?? this.turnIndex,
    );
  }

  // ヘルパーメソッド
  OnlinePlayer? get currentPlayer {
    if (currentPlayerId.isEmpty) return null;
    try {
      return players.firstWhere((p) => p.id == currentPlayerId);
    } catch (e) {
      return null;
    }
  }

  OnlinePlayer? get host {
    try {
      return players.firstWhere((p) => p.isHost);
    } catch (e) {
      return null;
    }
  }

  bool get isFull => players.length >= maxPlayers;
  bool get isEmpty => players.isEmpty;
  bool get canStart => players.length >= 2;

  OnlinePlayer? getNextPlayer() {
    if (players.isEmpty) return null;
    final nextIndex = (turnIndex + 1) % players.length;
    return players[nextIndex];
  }
}