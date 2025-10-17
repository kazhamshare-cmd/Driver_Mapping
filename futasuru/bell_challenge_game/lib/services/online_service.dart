import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/online_room.dart';
import '../models/game_settings.dart';

class OnlineService {
  static final OnlineService _instance = OnlineService._internal();
  factory OnlineService() => _instance;
  OnlineService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamController<OnlineRoom>? _roomController;

  // 現在のプレイヤー情報
  String? _currentPlayerId;
  String? _currentPlayerName;
  String? _currentRoomId;

  String get currentPlayerId => _currentPlayerId ?? '';
  String get currentPlayerName => _currentPlayerName ?? '';
  String get currentRoomId => _currentRoomId ?? '';

  void setCurrentPlayer(String playerId, String playerName) {
    _currentPlayerId = playerId;
    _currentPlayerName = playerName;
  }

  // 部屋作成
  Future<OnlineRoom> createRoom({
    required String roomName,
    required RoomType type,
    String? password,
    required GameSettings gameSettings,
  }) async {
    if (_currentPlayerId == null || _currentPlayerName == null) {
      throw Exception('プレイヤー情報が設定されていません');
    }

    final roomId = _uuid.v4();
    final now = DateTime.now();

    final host = OnlinePlayer(
      id: _currentPlayerId!,
      name: _currentPlayerName!,
      isHost: true,
    );

    final room = OnlineRoom(
      id: roomId,
      name: roomName,
      hostId: _currentPlayerId!,
      type: type,
      password: password,
      status: RoomStatus.waiting,
      players: [host],
      gameSettings: gameSettings,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('rooms').doc(roomId).set(room.toMap());
    _currentRoomId = roomId;

    print('🏠 部屋作成完了: $roomName (ID: $roomId)');
    return room;
  }

  // 部屋参加
  Future<OnlineRoom> joinRoom(String roomId, {String? password}) async {
    if (_currentPlayerId == null || _currentPlayerName == null) {
      throw Exception('プレイヤー情報が設定されていません');
    }

    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) {
      throw Exception('部屋が見つかりません');
    }

    final room = OnlineRoom.fromMap(roomDoc.data()!);

    // パスワードチェック
    if (room.type == RoomType.private && room.password != password) {
      throw Exception('パスワードが間違っています');
    }

    // 満室チェック
    if (room.isFull) {
      throw Exception('部屋が満室です');
    }

    // 既に参加しているかチェック
    final existingPlayer = room.players.where((p) => p.id == _currentPlayerId).firstOrNull;
    if (existingPlayer != null) {
      _currentRoomId = roomId;
      return room;
    }

    // プレイヤーを追加
    final newPlayer = OnlinePlayer(
      id: _currentPlayerId!,
      name: _currentPlayerName!,
      isHost: false,
    );

    final updatedPlayers = [...room.players, newPlayer];
    final updatedRoom = room.copyWith(
      players: updatedPlayers,
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('rooms').doc(roomId).update(updatedRoom.toMap());
    _currentRoomId = roomId;

    print('🚪 部屋参加完了: ${room.name} (プレイヤー数: ${updatedPlayers.length})');
    return updatedRoom;
  }

  // 公開部屋一覧取得
  Stream<List<OnlineRoom>> getPublicRooms() {
    return _firestore
        .collection('rooms')
        .where('type', isEqualTo: 'RoomType.public')
        .where('status', isEqualTo: 'RoomStatus.waiting')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OnlineRoom.fromMap(doc.data())).toList();
    });
  }

  // 部屋の状態をリアルタイム監視
  Stream<OnlineRoom> watchRoom(String roomId) {
    _roomController?.close();
    _roomController = StreamController<OnlineRoom>.broadcast();

    _roomSubscription = _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final room = OnlineRoom.fromMap(snapshot.data()!);
        _roomController?.add(room);
      }
    });

    return _roomController!.stream;
  }

  // ゲーム開始
  Future<void> startGame(String roomId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'RoomStatus.playing',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'turnIndex': 0,
    });

    print('🎮 ゲーム開始: $roomId');
  }

  // プレイヤーアクション送信
  Future<void> sendPlayerAction({
    required String roomId,
    required String playerId,
    required String action, // 'tap', 'vertical_swipe', 'horizontal_swipe'
    required bool success,
  }) async {
    final actionId = _uuid.v4();
    final actionData = {
      'id': actionId,
      'roomId': roomId,
      'playerId': playerId,
      'action': action,
      'success': success,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _firestore.collection('game_actions').doc(actionId).set(actionData);
    print('🎯 アクション送信: $action (成功: $success)');
  }

  // 次のプレイヤーに交代（トランザクションを使用して競合を防ぐ）
  Future<void> nextTurn(String roomId, int expectedCurrentTurnIndex) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    
    try {
      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw Exception('Room does not exist');
        }

        final room = OnlineRoom.fromMap(roomSnapshot.data()!);
        
        // 期待されるturnIndexと実際のturnIndexが一致しない場合は更新をスキップ
        // これにより、古いデータでの更新を防ぐ
        if (room.turnIndex != expectedCurrentTurnIndex) {
          print('⚠️ ターンインデックスが一致しません。更新をスキップします。(期待: $expectedCurrentTurnIndex, 実際: ${room.turnIndex})');
          return;
        }
        
        if (room.players.isEmpty) {
          throw Exception('No players in room');
        }

        final nextIndex = (room.turnIndex + 1) % room.players.length;
        final nextPlayer = room.players[nextIndex];

        transaction.update(roomRef, {
          'turnIndex': nextIndex,
          'currentPlayerId': nextPlayer.id,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });

        print('🔄 ターン交代: ${nextPlayer.name} (ターン: $nextIndex)');
      });
    } catch (e) {
      print('❌ ターン交代エラー: $e');
    }
  }

  // ゲーム開始時にターンを初期化
  Future<void> initializeGameTurn(String roomId) async {
    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = OnlineRoom.fromMap(roomDoc.data()!);
    if (room.players.isEmpty) return;

    // 最初のプレイヤーをcurrentPlayerIdに設定
    final firstPlayer = room.players.first;

    await _firestore.collection('rooms').doc(roomId).update({
      'currentPlayerId': firstPlayer.id,
      'turnIndex': 0,
      'status': RoomStatus.playing.toString(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    print('🎮 ゲーム開始 - 最初のターン: ${firstPlayer.name}');
  }

  // プレイヤースコア更新
  Future<void> updatePlayerScore(String roomId, String playerId, int score) async {
    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = OnlineRoom.fromMap(roomDoc.data()!);
    final updatedPlayers = room.players.map((player) {
      if (player.id == playerId) {
        return player.copyWith(score: score);
      }
      return player;
    }).toList();

    await _firestore.collection('rooms').doc(roomId).update({
      'players': updatedPlayers.map((p) => p.toMap()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    print('📊 スコア更新: $playerId = $score');
  }

  // 部屋を退出
  Future<void> leaveRoom(String roomId) async {
    if (_currentPlayerId == null) return;

    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = OnlineRoom.fromMap(roomDoc.data()!);
    final updatedPlayers = room.players.where((p) => p.id != _currentPlayerId).toList();

    if (updatedPlayers.isEmpty) {
      // 最後のプレイヤーが退出した場合、部屋を削除
      await _firestore.collection('rooms').doc(roomId).delete();
      print('🗑️ 部屋削除: $roomId');
    } else {
      // ホストが退出した場合、次のプレイヤーをホストにする
      if (room.hostId == _currentPlayerId && updatedPlayers.isNotEmpty) {
        updatedPlayers[0] = updatedPlayers[0].copyWith(isHost: true);
      }

      await _firestore.collection('rooms').doc(roomId).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
        'hostId': updatedPlayers.isNotEmpty ? updatedPlayers[0].id : '',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('🚪 部屋退出: $roomId (残り${updatedPlayers.length}人)');
    }

    _currentRoomId = null;
  }

  // リソースクリーンアップ
  void dispose() {
    _roomSubscription?.cancel();
    _roomController?.close();
    if (_currentRoomId != null) {
      leaveRoom(_currentRoomId!);
    }
  }
}