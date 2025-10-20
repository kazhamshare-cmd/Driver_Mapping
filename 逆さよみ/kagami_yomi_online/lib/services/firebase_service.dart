import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/game_room.dart';
import '../models/player.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ルーム作成
  Future<GameRoom> createRoom({
    required String roomName,
    required String hostName,
    String? password,
    required int maxStages,
  }) async {
    final roomId = _uuid.v4();
    final hostId = _uuid.v4();

    final host = Player(
      id: hostId,
      name: hostName,
    );

    final room = GameRoom(
      id: roomId,
      name: roomName,
      password: password,
      hostId: hostId,
      maxStages: maxStages,
      players: [host],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('rooms').doc(roomId).set(room.toMap());

    return room;
  }

  // ルーム参加
  Future<String> joinRoom({
    required String roomId,
    required String playerName,
    String? password,
  }) async {
    final docRef = _firestore.collection('rooms').doc(roomId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('ルームが見つかりません');
    }

    final room = GameRoom.fromMap(doc.data()!);

    if (room.password != null && room.password != password) {
      throw Exception('パスワードが正しくありません');
    }

    if (room.players.length >= 4) {
      throw Exception('ルームが満員です');
    }

    if (room.status != RoomStatus.waiting) {
      throw Exception('ゲームが既に開始されています');
    }

    final playerId = _uuid.v4();
    final player = Player(
      id: playerId,
      name: playerName,
    );

    await docRef.update({
      'players': FieldValue.arrayUnion([player.toMap()]),
    });

    return playerId;
  }

  // ルーム退出
  Future<void> leaveRoom({
    required String roomId,
    required String playerId,
  }) async {
    final docRef = _firestore.collection('rooms').doc(roomId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final room = GameRoom.fromMap(doc.data()!);
    final updatedPlayers =
        room.players.where((p) => p.id != playerId).toList();

    if (updatedPlayers.isEmpty || room.hostId == playerId) {
      // ホストが退出するか、全員が退出した場合はルーム削除
      await deleteRoom(roomId);
    } else {
      await docRef.update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      });
    }
  }

  // ルーム削除
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).delete();
  }

  // ルーム一覧取得
  Stream<List<GameRoom>> getRooms() {
    return _firestore
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GameRoom.fromMap(doc.data()))
          .toList();
    });
  }

  // ルーム情報取得
  Stream<GameRoom?> getRoomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameRoom.fromMap(doc.data()!);
    });
  }

  // ゲーム開始
  Future<void> startGame(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': RoomStatus.playing.toString().split('.').last,
      'currentStage': 0,
    });
  }

  // 問題更新
  Future<void> updateQuestion({
    required String roomId,
    required String question,
  }) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'currentQuestion': question,
    });
  }

  // プレイヤーの回答記録
  Future<void> recordAnswer({
    required String roomId,
    required String playerId,
    required bool isCorrect,
    required String answer, // 回答内容を追加
  }) async {
    final docRef = _firestore.collection('rooms').doc(roomId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final room = GameRoom.fromMap(doc.data()!);
    final updatedPlayers = room.players.map((p) {
      if (p.id == playerId) {
        int scoreChange = isCorrect ? 1 : -2;
        return p.copyWith(
          hasAnswered: true,
          isCorrect: isCorrect,
          score: p.score + scoreChange,
          answer: answer, // 回答内容を保存
        );
      }
      return p;
    }).toList();

    await docRef.update({
      'players': updatedPlayers.map((p) => p.toMap()).toList(),
    });
  }

  // 次のステージへ
  Future<void> nextStage(String roomId) async {
    final docRef = _firestore.collection('rooms').doc(roomId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final room = GameRoom.fromMap(doc.data()!);
    final nextStageNum = room.currentStage + 1;

    print('DEBUG nextStage: currentStage=${room.currentStage}, nextStageNum=$nextStageNum, maxStages=${room.maxStages}');

    // プレイヤーの回答状態をリセット
    final updatedPlayers = room.players
        .map((p) => p.copyWith(
              hasAnswered: false,
              isCorrect: false,
              answer: null, // 回答内容もリセット
            ))
        .toList();

    if (nextStageNum >= room.maxStages) {
      print('DEBUG: Game finished! nextStageNum=$nextStageNum >= maxStages=${room.maxStages}');
      // ゲーム終了 - 20%の確率で広告を表示
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final showAd = random < 20;

      await docRef.update({
        'status': RoomStatus.finished.toString().split('.').last,
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
        'showInterstitialAd': showAd,
      });
    } else {
      print('DEBUG: Continuing to next stage: $nextStageNum');
      await docRef.update({
        'currentStage': nextStageNum,
        'currentQuestion': null,
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      });
    }
  }

  // ゲーム再開（同じメンバーで）
  Future<void> restartGame(String roomId) async {
    final docRef = _firestore.collection('rooms').doc(roomId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final room = GameRoom.fromMap(doc.data()!);

    // スコアと回答状態をリセット
    final resetPlayers = room.players
        .map((p) => p.copyWith(score: 0, hasAnswered: false, isCorrect: false))
        .toList();

    await docRef.update({
      'status': RoomStatus.playing.toString().split('.').last,
      'currentStage': 0,
      'currentQuestion': null,
      'players': resetPlayers.map((p) => p.toMap()).toList(),
    });
  }
}
