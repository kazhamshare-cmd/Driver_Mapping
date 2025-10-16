import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/room_models.dart';

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  static RoomService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _roomsCollection = 'rooms';

  /// ルーム作成
  Future<Room> createRoom(CreateRoomRequest request) async {
    try {
      final room = Room.create(
        name: request.roomName,
        hostName: request.hostName,
        password: request.password,
        maxPlayers: request.maxPlayers,
      );

      await _firestore
          .collection(_roomsCollection)
          .doc(room.id)
          .set(room.toMap());

      // ルーム作成時に使用済みお題をリセット
      await resetRoomChallenges(room.id);

      if (kDebugMode) {
        print('ルーム作成成功: ${room.id}');
      }

      return room;
    } catch (e) {
      if (kDebugMode) {
        print('ルーム作成エラー: $e');
      }
      rethrow;
    }
  }

  /// ルーム参加
  Future<Room> joinRoom(JoinRoomRequest request) async {
    try {
      final roomDoc = await _firestore
          .collection(_roomsCollection)
          .doc(request.roomId)
          .get();

      if (!roomDoc.exists) {
        throw Exception('ルームが見つかりません');
      }

      final room = Room.fromMap(roomDoc.data()!);

      // パスワードチェック
      if (room.isPasswordProtected) {
        if (request.password != room.password) {
          throw Exception('パスワードが正しくありません');
        }
      }

      // 参加可能かチェック
      if (!room.canJoin) {
        throw Exception('ルームに参加できません');
      }

      // プレイヤー作成
      final player = Player(
        id: const Uuid().v4(),
        name: request.playerName,
        isHost: false,
        joinedAt: DateTime.now(),
      );

      // ルーム更新
      final updatedRoom = room.addPlayer(player);
      await _firestore
          .collection(_roomsCollection)
          .doc(updatedRoom.id)
          .update(updatedRoom.toMap());

      if (kDebugMode) {
        print('ルーム参加成功: ${updatedRoom.id}');
      }

      return updatedRoom;
    } catch (e) {
      if (kDebugMode) {
        print('ルーム参加エラー: $e');
      }
      rethrow;
    }
  }

  /// ルーム一覧取得
  Stream<List<Room>> getRooms() {
    return _firestore
        .collection(_roomsCollection)
        .where('status', isEqualTo: RoomStatus.waiting.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Room.fromMap(doc.data()))
          .toList();
    });
  }

  /// 特定ルーム取得
  Stream<Room?> getRoom(String roomId) {
    return _firestore
        .collection(_roomsCollection)
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return Room.fromMap(snapshot.data()!);
    });
  }

  /// ルーム更新
  Future<void> updateRoom(Room room) async {
    try {
      await _firestore
          .collection(_roomsCollection)
          .doc(room.id)
          .update(room.toMap());

      if (kDebugMode) {
        print('ルーム更新成功: ${room.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム更新エラー: $e');
      }
      rethrow;
    }
  }

  /// ルーム削除
  Future<void> deleteRoom(String roomId) async {
    try {
      await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .delete();

      if (kDebugMode) {
        print('ルーム削除成功: $roomId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム削除エラー: $e');
      }
      rethrow;
    }
  }

  /// プレイヤー退出
  Future<void> leaveRoom(String roomId, String playerId) async {
    try {
      final roomDoc = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();

      if (!roomDoc.exists) return;

      final room = Room.fromMap(roomDoc.data()!);
      final updatedRoom = room.removePlayer(playerId);

      if (updatedRoom.players.isEmpty) {
        // プレイヤーが0人になったらルーム削除
        await deleteRoom(roomId);
      } else {
        // ルーム更新
        await updateRoom(updatedRoom);
      }

      if (kDebugMode) {
        print('プレイヤー退出成功: $playerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('プレイヤー退出エラー: $e');
      }
      rethrow;
    }
  }

  /// ルーム開始
  Future<void> startRoom(String roomId) async {
    try {
      final roomDoc = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();

      if (!roomDoc.exists) return;

      final room = Room.fromMap(roomDoc.data()!);
      final startedRoom = room.startGame();
      await updateRoom(startedRoom);

      if (kDebugMode) {
        print('ルーム開始成功: $roomId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム開始エラー: $e');
      }
      rethrow;
    }
  }

  /// ルーム終了
  Future<void> endRoom(String roomId) async {
    try {
      final roomDoc = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();

      if (!roomDoc.exists) return;

      final room = Room.fromMap(roomDoc.data()!);
      final endedRoom = room.endGame();
      await updateRoom(endedRoom);

      if (kDebugMode) {
        print('ルーム終了成功: $roomId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム終了エラー: $e');
      }
      rethrow;
    }
  }

  /// 古いルームの自動削除（定期実行用）
  Future<void> cleanupOldRooms() async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24)); // 24時間前

      final query = await _firestore
          .collection(_roomsCollection)
          .where('createdAt', isLessThan: cutoffTime)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
        if (kDebugMode) {
          print('古いルームを削除: ${doc.id}');
        }
      }

      if (kDebugMode) {
        print('古いルームのクリーンアップ完了: ${query.docs.length}件削除');
      }
    } catch (e) {
      if (kDebugMode) {
        print('古いルームクリーンアップエラー: $e');
      }
    }
  }

  /// 空のルームの自動削除
  Future<void> cleanupEmptyRooms() async {
    try {
      final query = await _firestore
          .collection(_roomsCollection)
          .where('playerCount', isEqualTo: 0)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
        if (kDebugMode) {
          print('空のルームを削除: ${doc.id}');
        }
      }

      if (kDebugMode) {
        print('空のルームのクリーンアップ完了: ${query.docs.length}件削除');
      }
    } catch (e) {
      if (kDebugMode) {
        print('空のルームクリーンアップエラー: $e');
      }
    }
  }

  /// ルームの生存確認と自動削除
  Future<void> checkRoomHealth(String roomId) async {
    try {
      final roomDoc = await _firestore
          .collection(_roomsCollection)
          .doc(roomId)
          .get();

      if (!roomDoc.exists) return;

      final room = Room.fromMap(roomDoc.data()!);
      final now = DateTime.now();

      // ルームが24時間以上古い場合は削除
      if (room.createdAt.isBefore(now.subtract(const Duration(hours: 24)))) {
        await deleteRoom(roomId);
        if (kDebugMode) {
          print('古いルームを削除: $roomId');
        }
        return;
      }

      // プレイヤーが0人の場合は削除
      if (room.players.isEmpty) {
        await deleteRoom(roomId);
        if (kDebugMode) {
          print('空のルームを削除: $roomId');
        }
        return;
      }

      // ゲームが終了してから1時間以上経過している場合は削除
      if (room.status == RoomStatus.finished && 
          room.updatedAt.isBefore(now.subtract(const Duration(hours: 1)))) {
        await deleteRoom(roomId);
        if (kDebugMode) {
          print('終了済みルームを削除: $roomId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム生存確認エラー: $e');
      }
    }
  }

  /// ルーム内での使用済みお題を記録
  Future<void> recordUsedChallenge(String roomId, String challenge) async {
    try {
      await _firestore.collection(_roomsCollection).doc(roomId)
          .collection('usedChallenges').add({
        'challenge': challenge,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('使用済みお題記録エラー: $e');
      }
    }
  }

  /// ルーム内の使用済みお題を取得
  Future<List<String>> getUsedChallenges(String roomId) async {
    try {
      final snapshot = await _firestore.collection(_roomsCollection).doc(roomId)
          .collection('usedChallenges').get();
      
      return snapshot.docs.map((doc) => doc.data()['challenge'] as String).toList();
    } catch (e) {
      if (kDebugMode) {
        print('使用済みお題取得エラー: $e');
      }
      return [];
    }
  }

  /// ルーム作成時に使用済みお題をリセット
  Future<void> resetRoomChallenges(String roomId) async {
    try {
      final batch = _firestore.batch();
      final challengesRef = _firestore.collection(_roomsCollection).doc(roomId)
          .collection('usedChallenges');
      
      final snapshot = await challengesRef.get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (kDebugMode) {
        print('ルーム使用済みお題をリセット: $roomId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ルーム使用済みお題リセットエラー: $e');
      }
    }
  }

}
