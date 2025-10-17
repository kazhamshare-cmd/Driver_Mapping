import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

// シンプルなルーム状態
enum SimpleRoomState { waiting, playing, finished }

// シンプルなプレイヤークラス
class SimplePlayer {
  final String id;
  final String name;
  final bool isHost;
  final DateTime joinedAt;

  SimplePlayer({
    required this.id,
    required this.name,
    required this.isHost,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isHost': isHost,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  factory SimplePlayer.fromMap(Map<String, dynamic> map) {
    return SimplePlayer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      isHost: map['isHost'] ?? false,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
    );
  }
}

// シンプルなルームクラス
class SimpleRoom {
  final String id;
  final String name;
  final SimpleRoomState state;
  final List<SimplePlayer> players;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int rounds;          // 試合数
  final int timeLimit;       // 制限時間（秒）
  final int maxPlayers;      // 最大プレイヤー数
  final String? currentTurnPlayerId;  // 現在のターンのプレイヤーID
  final int currentRound;    // 現在のラウンド数
  final String bellState;    // ベルの状態（safe/danger）
  final Map<String, int> playerScores; // プレイヤーID -> スコアのマップ
  final Map<String, bool> playerReady; // プレイヤーID -> 準備完了状態
  final bool roundEnd;       // ラウンド終了フラグ
  final String? roundWinner; // ラウンド勝者

  SimpleRoom({
    required this.id,
    required this.name,
    required this.state,
    required this.players,
    required this.createdAt,
    required this.updatedAt,
    this.rounds = 3,
    this.timeLimit = 2,
    this.maxPlayers = 2,
    this.currentTurnPlayerId,
    this.currentRound = 0,
    this.bellState = 'safe',
    this.playerScores = const {},
    this.playerReady = const {},
    this.roundEnd = false,
    this.roundWinner,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'state': state.toString().split('.').last,
      'players': {
        for (var player in players)
          player.id: player.toMap()
      },
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'rounds': rounds,
      'timeLimit': timeLimit,
      'maxPlayers': maxPlayers,
      'currentTurnPlayerId': currentTurnPlayerId,
      'currentRound': currentRound,
      'bellState': bellState,
      'playerScores': playerScores,
      'playerReady': playerReady,
      'roundEnd': roundEnd,
      'roundWinner': roundWinner,
    };
  }

  factory SimpleRoom.fromMap(Map<String, dynamic> map, String id) {
    final playersMap = map['players'] as Map? ?? {};
    final players = playersMap.values
        .map((playerData) => SimplePlayer.fromMap(Map<String, dynamic>.from(playerData as Map)))
        .toList();

    // スコアマップを取得
    final scoresMap = map['playerScores'] as Map? ?? {};
    final playerScores = <String, int>{};
    for (var entry in scoresMap.entries) {
      playerScores[entry.key.toString()] = (entry.value as num?)?.toInt() ?? 0;
    }

    return SimpleRoom(
      id: id,
      name: map['name'] ?? '',
      state: SimpleRoomState.values.firstWhere(
        (e) => e.toString().split('.').last == map['state'],
        orElse: () => SimpleRoomState.waiting,
      ),
      players: players,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
      rounds: map['rounds'] ?? 3,
      timeLimit: map['timeLimit'] ?? 2,
      currentTurnPlayerId: map['currentTurnPlayerId'],
      currentRound: map['currentRound'] ?? 0,
      maxPlayers: map['maxPlayers'] ?? 2,
      bellState: map['bellState'] ?? 'safe',
      playerScores: playerScores,
      playerReady: Map<String, bool>.from(map['playerReady'] ?? {}),
      roundEnd: map['roundEnd'] ?? false,
      roundWinner: map['roundWinner'],
    );
  }
}

// シンプルなルームサービス
class SimpleRoomService {
  static final SimpleRoomService _instance = SimpleRoomService._internal();
  factory SimpleRoomService() => _instance;
  SimpleRoomService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  // Firebase初期化状況を確認
  Future<bool> initializeFirebase() async {
    print('🔥 Firebase初期化開始');

    try {
      // 認証確認
      User? user = _auth.currentUser;
      if (user == null) {
        print('🔥 匿名ログイン実行中...');
        final userCredential = await _auth.signInAnonymously();
        user = userCredential.user;
      }

      if (user != null) {
        print('🔥 Firebase認証成功: ${user.uid}');
        return true;
      } else {
        print('🚨 Firebase認証失敗');
        return false;
      }
    } catch (e) {
      print('🚨 Firebase初期化エラー: $e');
      return false;
    }
  }

  // シンプルなルーム作成
  Future<SimpleRoom?> createRoom(
    String playerName, {
    String? roomName,
    int rounds = 3,
    int timeLimit = 2,
    int maxPlayers = 2,
  }) async {
    final finalRoomName = roomName ?? '$playerNameのルーム';
    print('🏠 ルーム作成開始: $playerName (${rounds}試合, ${timeLimit}秒, 最大${maxPlayers}人)');
    print('🏠 ルーム名: $finalRoomName');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためルーム作成中止');
        return null;
      }

      final roomId = _uuid.v4().substring(0, 8).toUpperCase();
      final playerId = _uuid.v4();
      final now = DateTime.now();

      // ホストプレイヤー作成
      final hostPlayer = SimplePlayer(
        id: playerId,
        name: playerName,
        isHost: true,
        joinedAt: now,
      );

      // ルーム作成
      final room = SimpleRoom(
        id: roomId,
        name: finalRoomName,
        state: SimpleRoomState.waiting,
        players: [hostPlayer],
        createdAt: now,
        updatedAt: now,
        rounds: rounds,
        timeLimit: timeLimit,
        maxPlayers: maxPlayers,
      );

      // Firebaseに保存
      final ref = _database.ref('simple_rooms/$roomId');
      await ref.set(room.toMap());

      print('🏠 ルーム作成成功: $roomId ($finalRoomName)');
      return room;

    } catch (e) {
      print('🚨 ルーム作成エラー: $e');
      return null;
    }
  }

  // ルームに参加
  Future<SimpleRoom?> joinRoom(String roomId, String playerName) async {
    print('🏠 ルーム参加開始: $roomId, $playerName');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためルーム参加中止');
        return null;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🚨 ルームが存在しません: $roomId');
        return null;
      }

      // 型変換を安全に行う
      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = SimpleRoom.fromMap(roomData, roomId);

      // プレイヤー数チェック
      if (room.players.length >= room.maxPlayers) {
        print('🚨 ルームが満員です (${room.players.length}/${room.maxPlayers})');
        return null;
      }

      // 新プレイヤー追加
      final newPlayer = SimplePlayer(
        id: _uuid.v4(),
        name: playerName,
        isHost: false,
        joinedAt: DateTime.now(),
      );

      final updatedPlayers = [...room.players, newPlayer];
      final updatedRoom = SimpleRoom(
        id: room.id,
        name: room.name,
        state: room.state,
        players: updatedPlayers,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
        rounds: room.rounds,
        timeLimit: room.timeLimit,
        maxPlayers: room.maxPlayers,
        currentTurnPlayerId: room.currentTurnPlayerId,
        currentRound: room.currentRound,
      );

      // Firebaseに更新
      await ref.set(updatedRoom.toMap());

      print('🏠 ルーム参加成功: ${updatedRoom.players.length}人');
      return updatedRoom;

    } catch (e) {
      print('🚨 ルーム参加エラー: $e');
      return null;
    }
  }

  // ルーム監視
  Stream<SimpleRoom?> watchRoom(String roomId) {
    print('🏠 ルーム監視開始: $roomId');

    final ref = _database.ref('simple_rooms/$roomId');

    return ref.onValue.map((event) {
      try {
        if (event.snapshot.exists) {
          // 型変換を安全に行う
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final room = SimpleRoom.fromMap(data, roomId);
          print('🏠 ルームデータ受信: ${room.players.length}人');
          return room;
        } else {
          print('🏠 ルームデータなし');
          return null;
        }
      } catch (e) {
        print('🚨 ルーム監視エラー: $e');
        return null;
      }
    });
  }

  // 利用可能なルーム一覧取得
  Future<List<SimpleRoom>> getAvailableRooms() async {
    print('🏠 利用可能ルーム取得開始');

    try {
      final ref = _database.ref('simple_rooms');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🏠 ルームなし');
        return [];
      }

      // 型変換を安全に行う
      final roomsData = Map<String, dynamic>.from(snapshot.value as Map);
      final rooms = <SimpleRoom>[];

      for (final entry in roomsData.entries) {
        try {
          // 型変換を安全に行う
          final roomData = Map<String, dynamic>.from(entry.value as Map);
          final room = SimpleRoom.fromMap(roomData, entry.key);
          if (room.state == SimpleRoomState.waiting && room.players.length < room.maxPlayers) {
            rooms.add(room);
          }
        } catch (e) {
          print('🚨 ルームデータ解析エラー: $e');
        }
      }

      print('🏠 利用可能ルーム: ${rooms.length}個');
      return rooms;

    } catch (e) {
      print('🚨 ルーム一覧取得エラー: $e');
      return [];
    }
  }

  // ルーム削除（ホストのみ）
  Future<bool> deleteRoom(String roomId) async {
    print('🏠 ルーム削除開始: $roomId');

    try {
      final ref = _database.ref('simple_rooms/$roomId');
      await ref.remove();
      print('🏠 ルーム削除成功');
      return true;
    } catch (e) {
      print('🚨 ルーム削除エラー: $e');
      return false;
    }
  }

  // 全ルーム削除（デバッグ・メンテナンス用）
  Future<bool> deleteAllRooms() async {
    print('🗑️ 全ルーム削除開始');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のため全ルーム削除中止');
        return false;
      }

      final ref = _database.ref('simple_rooms');
      await ref.remove();
      print('🗑️ 全ルーム削除成功');
      return true;
    } catch (e) {
      print('🚨 全ルーム削除エラー: $e');
      return false;
    }
  }

  // 古いルームの自動削除（2時間以上経過したルーム）
  Future<int> cleanupOldRooms() async {
    print('🧹 古いルーム清掃開始');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためルーム清掃中止');
        return 0;
      }

      final ref = _database.ref('simple_rooms');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🧹 清掃対象ルームなし');
        return 0;
      }

      final roomsData = Map<String, dynamic>.from(snapshot.value as Map);
      final now = DateTime.now();
      int deletedCount = 0;

      for (final entry in roomsData.entries) {
        try {
          final roomData = Map<String, dynamic>.from(entry.value as Map);
          final room = SimpleRoom.fromMap(roomData, entry.key);

          // 2時間以上経過したルーム、または終了状態のルームを削除
          final ageInHours = now.difference(room.updatedAt).inHours;
          final shouldDelete = ageInHours >= 2 || room.state == SimpleRoomState.finished;

          if (shouldDelete) {
            final roomRef = _database.ref('simple_rooms/${entry.key}');
            await roomRef.remove();
            print('🧹 古いルーム削除: ${entry.key} (${ageInHours}時間経過)');
            deletedCount++;
          }
        } catch (e) {
          print('🚨 ルーム清掃エラー: ${entry.key} - $e');
        }
      }

      print('🧹 ルーム清掃完了: ${deletedCount}個のルームを削除');
      return deletedCount;

    } catch (e) {
      print('🚨 ルーム清掃エラー: $e');
      return 0;
    }
  }

  // ゲームをリセット（再戦用）
  Future<bool> resetGame(String roomId) async {
    print('🔄 ゲームリセット開始: $roomId');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためゲームリセット中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      // スコアとゲーム状態をリセット
      await ref.update({
        'state': SimpleRoomState.waiting.name,
        'currentRound': 0,
        'playerScores': {},
        'currentPlayerId': null,
        'bellState': 'safe',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('🔄 ゲームリセット完了: $roomId');
      return true;

    } catch (e) {
      print('🚨 ゲームリセットエラー: $e');
      return false;
    }
  }

  // プレイヤーの準備状態を更新
  Future<bool> setPlayerReady(String roomId, String playerId, bool ready) async {
    print('✅ プレイヤー準備状態更新: $roomId, $playerId, $ready');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のため準備状態更新中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      await ref.update({
        'playerReady/$playerId': ready,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ プレイヤー準備状態更新完了: $playerId -> $ready');
      return true;

    } catch (e) {
      print('🚨 プレイヤー準備状態更新エラー: $e');
      return false;
    }
  }

  // 全プレイヤーが準備完了かチェック
  bool areAllPlayersReady(SimpleRoom room) {
    if (room.players.isEmpty) return false;
    
    for (var player in room.players) {
      if (!(room.playerReady[player.id] ?? false)) {
        return false;
      }
    }
    return true;
  }

  // 準備状態をリセット
  Future<bool> resetPlayerReady(String roomId) async {
    print('🔄 準備状態リセット: $roomId');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のため準備状態リセット中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      await ref.update({
        'playerReady': {},
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('🔄 準備状態リセット完了: $roomId');
      return true;

    } catch (e) {
      print('🚨 準備状態リセットエラー: $e');
      return false;
    }
  }

  // ラウンド終了を通知
  Future<bool> setRoundEnd(String roomId, String winner) async {
    print('🏁 ラウンド終了通知: $roomId, 勝者: $winner');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためラウンド終了通知中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      await ref.update({
        'roundEnd': true,
        'roundWinner': winner,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('🏁 ラウンド終了通知完了: $roomId');
      return true;

    } catch (e) {
      print('🚨 ラウンド終了通知エラー: $e');
      return false;
    }
  }

  // ラウンド終了フラグをクリア
  Future<bool> clearRoundEnd(String roomId) async {
    print('🔄 ラウンド終了フラグクリア: $roomId');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためラウンド終了フラグクリア中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      await ref.update({
        'roundEnd': false,
        'roundWinner': null,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('🔄 ラウンド終了フラグクリア完了: $roomId');
      return true;

    } catch (e) {
      print('🚨 ラウンド終了フラグクリアエラー: $e');
      return false;
    }
  }

  // プレイヤーがルームから退出
  Future<bool> leaveRoom(String roomId, String playerId) async {
    print('🚪 ルーム退出開始: $roomId, $playerId');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためルーム退出中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🚨 ルームが存在しません: $roomId');
        return false;
      }

      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = SimpleRoom.fromMap(roomData, roomId);

      // プレイヤーを削除
      final updatedPlayers = room.players.where((player) => player.id != playerId).toList();

      // プレイヤーが0人になった場合はルームを削除
      if (updatedPlayers.isEmpty) {
        await ref.remove();
        print('🚪 プレイヤー0人のためルーム削除: $roomId');
        return true;
      }

      // ホストが退出した場合は次のプレイヤーをホストに
      bool needNewHost = false;
      if (room.players.any((player) => player.id == playerId && player.isHost)) {
        needNewHost = true;
      }

      List<SimplePlayer> finalPlayers = updatedPlayers;
      if (needNewHost && finalPlayers.isNotEmpty) {
        final newHost = SimplePlayer(
          id: finalPlayers.first.id,
          name: finalPlayers.first.name,
          isHost: true,
          joinedAt: finalPlayers.first.joinedAt,
        );
        finalPlayers = [newHost, ...finalPlayers.skip(1)];
        print('🚪 新ホスト設定: ${newHost.name}');
      }

      // ルーム更新
      final updatedRoom = SimpleRoom(
        id: room.id,
        name: room.name,
        state: room.state,
        players: finalPlayers,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
        rounds: room.rounds,
        timeLimit: room.timeLimit,
        maxPlayers: room.maxPlayers,
        currentTurnPlayerId: room.currentTurnPlayerId,
        currentRound: room.currentRound,
      );

      await ref.set(updatedRoom.toMap());
      print('🚪 ルーム退出成功: ${finalPlayers.length}人残り');
      return true;

    } catch (e) {
      print('🚨 ルーム退出エラー: $e');
      return false;
    }
  }

  // ルーム状態を更新（ゲーム開始時など）
  Future<bool> updateRoomState(String roomId, SimpleRoomState newState) async {
    print('🔄 ルーム状態更新開始: $roomId -> $newState');

    try {
      // Firebase初期化確認
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためルーム状態更新中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🚨 ルームが存在しません: $roomId');
        return false;
      }

      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = SimpleRoom.fromMap(roomData, roomId);

      final updatedRoom = SimpleRoom(
        id: room.id,
        name: room.name,
        state: newState,
        players: room.players,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
        rounds: room.rounds,
        timeLimit: room.timeLimit,
        maxPlayers: room.maxPlayers,
        currentTurnPlayerId: room.currentTurnPlayerId,
        currentRound: room.currentRound,
      );

      await ref.set(updatedRoom.toMap());
      print('🔄 ルーム状態更新成功: $newState');
      return true;

    } catch (e) {
      print('🚨 ルーム状態更新エラー: $e');
      return false;
    }
  }

  // デバッグ用：ルーム詳細確認
  Future<void> debugInspectRoom(String roomId) async {
    print('🔍 ルーム詳細確認開始: $roomId');

    try {
      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final data = snapshot.value;
        print('🔍 ルームデータ: $data');
      } else {
        print('🔍 ルームが存在しません');
      }
    } catch (e) {
      print('🚨 ルーム詳細確認エラー: $e');
    }
  }

  // ターンを次のプレイヤーに移す（Transactionベース - 高速・競合回避）
  // bellStateも同時に更新可能
  Future<bool> switchTurn(String roomId, {String? newBellState}) async {
    print('🔄 ターン切り替え開始: $roomId, ベル状態: $newBellState');

    try {
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためターン切り替え中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      
      // Transactionを使用して高速かつ安全にターン切り替え
      final result = await ref.runTransaction((currentData) {
        if (currentData == null) {
          print('🚨 Transaction: ルームデータなし');
          return Transaction.abort();
        }

        try {
          final roomData = Map<String, dynamic>.from(currentData as Map);
          final room = SimpleRoom.fromMap(roomData, roomId);

          if (room.players.isEmpty) {
            print('🚨 Transaction: プレイヤーなし');
            return Transaction.abort();
          }

          // 次のプレイヤーを決定
          String nextPlayerId;
          if (room.currentTurnPlayerId == null) {
            // 最初のターンは最初のプレイヤー
            nextPlayerId = room.players.first.id;
          } else {
            // 現在のプレイヤーの次のプレイヤーを探す
            final currentIndex = room.players.indexWhere((p) => p.id == room.currentTurnPlayerId);
            if (currentIndex != -1) {
              final nextIndex = (currentIndex + 1) % room.players.length;
              nextPlayerId = room.players[nextIndex].id;
            } else {
              // 現在のプレイヤーが見つからない場合は最初のプレイヤー
              nextPlayerId = room.players.first.id;
            }
          }

          // 更新データを作成（必要最小限のフィールドのみ更新）
          final updatedData = Map<String, dynamic>.from(roomData);
          updatedData['currentTurnPlayerId'] = nextPlayerId;
          updatedData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
          
          // ベル状態も更新
          if (newBellState != null) {
            updatedData['bellState'] = newBellState;
          }

          final nextPlayerName = room.players.firstWhere((p) => p.id == nextPlayerId).name;
          print('🔄 Transaction: 次のターン -> $nextPlayerName, ベル: ${newBellState ?? room.bellState}');

          return Transaction.success(updatedData);
        } catch (e) {
          print('🚨 Transaction エラー: $e');
          return Transaction.abort();
        }
      });

      if (result.committed) {
        print('🔄 ターン切り替え成功');
        return true;
      } else {
        print('🚨 Transaction コミット失敗');
        return false;
      }

    } catch (e) {
      print('🚨 ターン切り替えエラー: $e');
      return false;
    }
  }

  // ラウンドを進める
  Future<bool> nextRound(String roomId) async {
    print('🔄 次ラウンド開始: $roomId');

    try {
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のため次ラウンド中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🚨 ルームが存在しません: $roomId');
        return false;
      }

      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = SimpleRoom.fromMap(roomData, roomId);

      final updatedRoom = SimpleRoom(
        id: room.id,
        name: room.name,
        state: room.state,
        players: room.players,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
        rounds: room.rounds,
        timeLimit: room.timeLimit,
        maxPlayers: room.maxPlayers,
        currentTurnPlayerId: room.currentTurnPlayerId,
        currentRound: room.currentRound + 1,
      );

      await ref.set(updatedRoom.toMap());
      print('🔄 次ラウンド成功: ${room.currentRound + 1}');
      return true;

    } catch (e) {
      print('🚨 次ラウンドエラー: $e');
      return false;
    }
  }

  // ゲーム開始時にターンを初期化
  Future<bool> initializeTurn(String roomId) async {
    print('🎮 ターン初期化開始: $roomId');

    try {
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためターン初期化中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');
      final snapshot = await ref.get();

      if (!snapshot.exists) {
        print('🚨 ルームが存在しません: $roomId');
        return false;
      }

      final roomData = Map<String, dynamic>.from(snapshot.value as Map);
      final room = SimpleRoom.fromMap(roomData, roomId);

      if (room.players.isEmpty) {
        print('🚨 プレイヤーが存在しません');
        return false;
      }

      // 最初のプレイヤーをターンに設定
      final firstPlayerId = room.players.first.id;

      // スコアを初期化（全プレイヤー0点）
      final initialScores = <String, int>{};
      for (var player in room.players) {
        initialScores[player.id] = 0;
      }

      final updatedRoom = SimpleRoom(
        id: room.id,
        name: room.name,
        state: SimpleRoomState.playing,
        players: room.players,
        createdAt: room.createdAt,
        updatedAt: DateTime.now(),
        rounds: room.rounds,
        timeLimit: room.timeLimit,
        maxPlayers: room.maxPlayers,
        currentTurnPlayerId: firstPlayerId,
        currentRound: 1,
        playerScores: initialScores,
      );

      await ref.set(updatedRoom.toMap());

      final firstPlayerName = room.players.first.name;
      print('🎮 ターン初期化成功: $firstPlayerName が最初');
      return true;

    } catch (e) {
      print('🚨 ターン初期化エラー: $e');
      return false;
    }
  }

  // プレイヤーのスコアを増やす（Transaction使用で安全に更新）
  Future<bool> incrementPlayerScore(String roomId, String playerId) async {
    print('📊 スコア更新開始: $roomId, プレイヤーID: $playerId');

    try {
      if (!await initializeFirebase()) {
        print('🚨 Firebase初期化失敗のためスコア更新中止');
        return false;
      }

      final ref = _database.ref('simple_rooms/$roomId');

      final result = await ref.runTransaction((currentData) {
        if (currentData == null) {
          print('🚨 Transaction: ルームデータなし');
          return Transaction.abort();
        }

        try {
          final roomData = Map<String, dynamic>.from(currentData as Map);
          final room = SimpleRoom.fromMap(roomData, roomId);

          // スコアを更新
          final updatedScores = Map<String, int>.from(room.playerScores);
          updatedScores[playerId] = (updatedScores[playerId] ?? 0) + 1;

          // 更新データを作成
          final updatedData = Map<String, dynamic>.from(roomData);
          updatedData['playerScores'] = updatedScores;
          updatedData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

          print('📊 Transaction: スコア更新 -> $updatedScores');
          return Transaction.success(updatedData);
        } catch (e) {
          print('🚨 Transaction エラー: $e');
          return Transaction.abort();
        }
      });

      if (result.committed) {
        print('📊 スコア更新成功');
        return true;
      } else {
        print('🚨 Transaction コミット失敗');
        return false;
      }

    } catch (e) {
      print('🚨 スコア更新エラー: $e');
      return false;
    }
  }
}