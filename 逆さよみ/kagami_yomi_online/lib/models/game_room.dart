import 'package:cloud_firestore/cloud_firestore.dart';
import 'player.dart';

enum RoomStatus {
  waiting, // プレイヤー待機中
  playing, // ゲーム中
  finished, // ゲーム終了
}

class GameRoom {
  final String id;
  final String name;
  final String? password;
  final String hostId;
  final int maxStages;
  final int currentStage;
  final RoomStatus status;
  final List<Player> players;
  final DateTime createdAt;
  final String? currentQuestion;
  final bool showInterstitialAd; // 全員で同期する広告表示フラグ

  GameRoom({
    required this.id,
    required this.name,
    this.password,
    required this.hostId,
    required this.maxStages,
    this.currentStage = 0,
    this.status = RoomStatus.waiting,
    this.players = const [],
    required this.createdAt,
    this.currentQuestion,
    this.showInterstitialAd = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'hostId': hostId,
      'maxStages': maxStages,
      'currentStage': currentStage,
      'status': status.toString().split('.').last,
      'players': players.map((p) => p.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'currentQuestion': currentQuestion,
      'showInterstitialAd': showInterstitialAd,
    };
  }

  factory GameRoom.fromMap(Map<String, dynamic> map) {
    RoomStatus parseStatus(String status) {
      switch (status) {
        case 'waiting':
          return RoomStatus.waiting;
        case 'playing':
          return RoomStatus.playing;
        case 'finished':
          return RoomStatus.finished;
        default:
          return RoomStatus.waiting;
      }
    }

    return GameRoom(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      password: map['password'],
      hostId: map['hostId'] ?? '',
      maxStages: map['maxStages'] ?? 10,
      currentStage: map['currentStage'] ?? 0,
      status: parseStatus(map['status'] ?? 'waiting'),
      players: (map['players'] as List<dynamic>?)
              ?.map((p) => Player.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentQuestion: map['currentQuestion'],
      showInterstitialAd: map['showInterstitialAd'] ?? false,
    );
  }

  GameRoom copyWith({
    String? id,
    String? name,
    String? password,
    String? hostId,
    int? maxStages,
    int? currentStage,
    RoomStatus? status,
    List<Player>? players,
    DateTime? createdAt,
    String? currentQuestion,
    bool? showInterstitialAd,
  }) {
    return GameRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      hostId: hostId ?? this.hostId,
      maxStages: maxStages ?? this.maxStages,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      showInterstitialAd: showInterstitialAd ?? this.showInterstitialAd,
    );
  }
}
