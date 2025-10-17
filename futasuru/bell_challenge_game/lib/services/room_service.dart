import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';

enum RoomState { waiting, playing, finished }

enum GamePhase { countdown, playing, result, gameEnd }

enum BellState { safe, danger }

class OnlineGameState {
  final GamePhase phase;
  final BellState bellState;
  final String? currentPlayerId;
  final int currentTurn;
  final List<String> activePlayers;
  final Map<String, int> scores;
  final String? lastAction;
  final DateTime? actionTime;
  final int timeRemaining;

  OnlineGameState({
    required this.phase,
    required this.bellState,
    this.currentPlayerId,
    required this.currentTurn,
    required this.activePlayers,
    required this.scores,
    this.lastAction,
    this.actionTime,
    required this.timeRemaining,
  });

  factory OnlineGameState.fromMap(Map<String, dynamic> map) {
    return OnlineGameState(
      phase: GamePhase.values.firstWhere(
        (e) => e.toString() == 'GamePhase.${map['phase']}',
        orElse: () => GamePhase.countdown,
      ),
      bellState: BellState.values.firstWhere(
        (e) => e.toString() == 'BellState.${map['bellState']}',
        orElse: () => BellState.safe,
      ),
      currentPlayerId: map['currentPlayerId'],
      currentTurn: map['currentTurn'] ?? 0,
      activePlayers: List<String>.from(map['activePlayers'] ?? []),
      scores: Map<String, int>.from(map['scores'] ?? {}),
      lastAction: map['lastAction'],
      actionTime: map['actionTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['actionTime'])
          : null,
      timeRemaining: map['timeRemaining'] ?? 5000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phase': phase.toString().split('.').last,
      'bellState': bellState.toString().split('.').last,
      'currentPlayerId': currentPlayerId,
      'currentTurn': currentTurn,
      'activePlayers': activePlayers,
      'scores': scores,
      'lastAction': lastAction,
      'actionTime': actionTime?.millisecondsSinceEpoch,
      'timeRemaining': timeRemaining,
    };
  }
}

class GameRoom {
  final String id;
  final String name;
  final String? password;
  final bool isPrivate;
  final RoomState state;
  final List<Player> players;
  final Map<String, dynamic>? gameData;
  final OnlineGameState? gameState;
  final DateTime createdAt;
  final DateTime updatedAt;

  GameRoom({
    required this.id,
    required this.name,
    this.password,
    required this.isPrivate,
    required this.state,
    required this.players,
    this.gameData,
    this.gameState,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GameRoom.fromMap(Map<String, dynamic> map, String id) {
    return GameRoom(
      id: id,
      name: map['name'] ?? 'Unnamed Room',
      password: map['password'],
      isPrivate: map['isPrivate'] ?? false,
      state: RoomState.values.firstWhere(
        (e) => e.toString() == 'RoomState.${map['state']}',
        orElse: () => RoomState.waiting,
      ),
      players: _parsePlayersList(map['players']),
      gameData: map['gameData'] != null
          ? Map<String, dynamic>.from(map['gameData'] as Map)
          : null,
      gameState: map['gameState'] != null
          ? OnlineGameState.fromMap(Map<String, dynamic>.from(map['gameState'] as Map))
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'password': password,
      'isPrivate': isPrivate,
      'state': state.toString().split('.').last,
      'players': players.map((p) => p.toMap()).toList(),
      'gameData': gameData,
      'gameState': gameState?.toMap(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// プレイヤーリストを安全に解析するヘルパーメソッド
  static List<Player> _parsePlayersList(dynamic playersData) {
    print('🔥 _parsePlayersList - データ型: ${playersData.runtimeType}');
    print('🔥 _parsePlayersList - データ内容: $playersData');

    if (playersData == null) {
      print('🔥 _parsePlayersList - プレイヤーデータがnull');
      return [];
    }

    try {
      if (playersData is List) {
        print('🔥 _parsePlayersList - リスト形式、アイテム数: ${playersData.length}');
        final players = playersData
            .map((p) {
              try {
                print('🔥 _parsePlayersList - プレイヤーアイテム型: ${p.runtimeType}');
                if (p is Map<String, dynamic>) {
                  final player = Player.fromMap(p);
                  print('🔥 _parsePlayersList - プレイヤー解析成功: ${player.name}');
                  return player;
                } else if (p is Map) {
                  final player = Player.fromMap(Map<String, dynamic>.from(p));
                  print('🔥 _parsePlayersList - プレイヤー解析成功（型変換後）: ${player.name}');
                  return player;
                }
                print('🔥 _parsePlayersList - 不明な型のプレイヤーデータ: $p');
                return null;
              } catch (e) {
                print('🚨 プレイヤーデータ解析エラー: $e');
                return null;
              }
            })
            .where((p) => p != null)
            .cast<Player>()
            .toList();
        print('🔥 _parsePlayersList - リスト解析完了、プレイヤー数: ${players.length}');
        return players;
      } else if (playersData is Map) {
        // FirebaseがMapとして返す場合の対応
        print('🔥 _parsePlayersList - Map形式、キー数: ${playersData.length}');
        final List<Player> players = [];
        playersData.forEach((key, value) {
          try {
            print('🔥 _parsePlayersList - Mapアイテム: key=$key, type=${value.runtimeType}');
            if (value is Map<String, dynamic>) {
              final player = Player.fromMap(value);
              players.add(player);
              print('🔥 _parsePlayersList - Map解析成功: ${player.name}');
            } else if (value is Map) {
              final player = Player.fromMap(Map<String, dynamic>.from(value));
              players.add(player);
              print('🔥 _parsePlayersList - Map解析成功（型変換後）: ${player.name}');
            }
          } catch (e) {
            print('🚨 プレイヤーデータ解析エラー (Map): $e');
          }
        });
        print('🔥 _parsePlayersList - Map解析完了、プレイヤー数: ${players.length}');
        return players;
      } else {
        print('🔥 _parsePlayersList - 予期しないデータ型: ${playersData.runtimeType}');
      }
    } catch (e) {
      print('🚨 プレイヤーリスト解析で予期しないエラー: $e');
    }

    print('🔥 _parsePlayersList - 空のリストを返します');
    return [];
  }
}

class Player {
  final String id;
  final String name;
  final int score;
  final bool isConnected;
  final DateTime joinedAt;

  Player({
    required this.id,
    required this.name,
    required this.score,
    required this.isConnected,
    required this.joinedAt,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Player',
      score: map['score'] ?? 0,
      isConnected: map['isConnected'] ?? true,
      joinedAt: DateTime.fromMillisecondsSinceEpoch(map['joinedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'isConnected': isConnected,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  Player copyWith({
    String? id,
    String? name,
    int? score,
    bool? isConnected,
    DateTime? joinedAt,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      isConnected: isConnected ?? this.isConnected,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class RoomService {
  static final RoomService _instance = RoomService._internal();
  factory RoomService() => _instance;
  RoomService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final Uuid _uuid = const Uuid();

  /// Ensure user is authenticated before database operations
  Future<void> _ensureAuthenticated() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        print('🔐 User not authenticated, signing in anonymously...');
        await AuthService().signInAnonymously();
        print('✅ Anonymous authentication successful');
      }
    } catch (e) {
      print('❌ Authentication failed: $e');
      // Continue without auth - will rely on permissive database rules
    }
  }

  // ルーム作成
  Future<GameRoom> createRoom({
    required String playerName,
    required String roomName,
    String? password,
    Map<String, dynamic>? gameData,
  }) async {
    try {
      print('🔥 RoomService.createRoom 開始');
      await _ensureAuthenticated();

      final roomId = _uuid.v4().substring(0, 8).toUpperCase();
      final playerId = _uuid.v4();

      print('🔥 生成されたroomId: $roomId');
      print('🔥 生成されたplayerId: $playerId');

      final player = Player(
        id: playerId,
        name: playerName,
        score: 0,
        isConnected: true,
        joinedAt: DateTime.now(),
      );

      final room = GameRoom(
        id: roomId,
        name: roomName,
        password: password,
        isPrivate: password != null && password.isNotEmpty,
        state: RoomState.waiting,
        players: [player],
        gameData: gameData,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final roomMap = room.toMap();
      print('🔥 Firebase に送信するデータ: $roomMap');

      await _database.ref('rooms/$roomId').set(roomMap);
      print('🔥 Firebase書き込み成功');

      return room;
    } catch (e, stackTrace) {
      print('❌ RoomService.createRoom エラー: $e');
      print('❌ スタックトレース: $stackTrace');
      rethrow;
    }
  }

  // ルーム参加
  Future<GameRoom?> joinRoom({
    required String roomId,
    required String playerName,
    String? password,
  }) async {
    await _ensureAuthenticated();
    final roomSnapshot = await _database.ref('rooms/$roomId').get();

    if (!roomSnapshot.exists) {
      throw Exception('ルームが見つかりません');
    }

    final room = GameRoom.fromMap(Map<String, dynamic>.from(roomSnapshot.value as Map), roomId);

    // 既に同じ名前のプレイヤーがいるかチェック
    if (room.players.any((p) => p.name == playerName)) {
      throw Exception('同じ名前のプレイヤーが既に存在します');
    }

    // パスワード確認
    if (room.isPrivate && room.password != password) {
      throw Exception('パスワードが間違っています');
    }

    // ルームが満員でないか確認（最大6人）
    if (room.players.length >= 6) {
      throw Exception('ルームが満員です（最大6人）');
    }

    // ゲームが進行中でないか確認
    if (room.state != RoomState.waiting) {
      throw Exception('ゲームが進行中です');
    }

    // プレイヤーを追加
    final playerId = _uuid.v4();
    print('🔥 joinRoom - プレイヤー追加開始: $playerName (ID: $playerId)');
    final newPlayer = Player(
      id: playerId,
      name: playerName,
      score: 0,
      isConnected: true,
      joinedAt: DateTime.now(),
    );

    final updatedPlayers = [...room.players, newPlayer];
    print('🔥 joinRoom - 更新前プレイヤー数: ${room.players.length}');
    print('🔥 joinRoom - 更新後プレイヤー数: ${updatedPlayers.length}');

    await _database.ref('rooms/$roomId').update({
      'players': updatedPlayers.map((p) => p.toMap()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    print('🔥 joinRoom - Firebase更新完了');
    return room.copyWith(players: updatedPlayers);
  }

  // デバッグ用：特定ルームの生データを取得
  Future<void> debugInspectRoom(String roomId) async {
    try {
      print('🔍 デバッグ：ルーム $roomId の検査開始');
      final snapshot = await _database.ref('rooms/$roomId').get();

      if (snapshot.exists) {
        print('🔍 ルーム存在: true');
        final rawData = snapshot.value;
        print('🔍 生データ型: ${rawData.runtimeType}');
        print('🔍 生データ内容: $rawData');

        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData);
          print('🔍 変換後データ: $data');
          print('🔍 プレイヤーフィールド: ${data['players']}');
          print('🔍 プレイヤーフィールド型: ${data['players'].runtimeType}');

          if (data['players'] != null) {
            final playersData = data['players'];
            if (playersData is List) {
              print('🔍 プレイヤー配列長: ${playersData.length}');
              for (int i = 0; i < playersData.length; i++) {
                print('🔍 プレイヤー[$i]: ${playersData[i]}');
              }
            } else if (playersData is Map) {
              print('🔍 プレイヤーMapキー: ${playersData.keys.toList()}');
              playersData.forEach((key, value) {
                print('🔍 プレイヤー[$key]: $value');
              });
            }
          }
        }

        // GameRoom.fromMapでの解析もテスト
        try {
          final room = GameRoom.fromMap(Map<String, dynamic>.from(rawData as Map), roomId);
          print('🔍 解析成功 - プレイヤー数: ${room.players.length}');
          print('🔍 解析成功 - ルーム名: ${room.name}');
          print('🔍 解析成功 - ルーム状態: ${room.state}');
        } catch (e) {
          print('🔍 解析エラー: $e');
        }
      } else {
        print('🔍 ルーム存在: false');
      }
    } catch (e) {
      print('🔍 検査エラー: $e');
    }
  }

  // ルーム一覧取得（全ルーム）
  Stream<List<GameRoom>> getAllRooms() {
    return _database.ref('rooms').onValue.map((event) {
      if (event.snapshot.value == null) return <GameRoom>[];

      final rooms = <GameRoom>[];
      final roomsData = Map<String, dynamic>.from(event.snapshot.value as Map);

      for (final entry in roomsData.entries) {
        try {
          final room = GameRoom.fromMap(Map<String, dynamic>.from(entry.value as Map), entry.key);
          if (room.state == RoomState.waiting) {
            rooms.add(room);
          }
        } catch (e) {
          print('Error parsing room ${entry.key}: $e');
        }
      }

      // 作成日時順でソート
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    });
  }

  // パブリックルーム一覧取得
  Stream<List<GameRoom>> getPublicRooms() {
    return getAllRooms().map((rooms) {
      final now = DateTime.now();
      return rooms.where((room) {
        // プライベート部屋を除外
        if (room.isPrivate) return false;

        // 終了した部屋を除外
        if (room.state == RoomState.finished) return false;

        // 120分（7200秒）以上経過した部屋を除外
        final roomAge = now.difference(room.createdAt).inSeconds;
        if (roomAge > 7200) {
          // 古い部屋を削除（バックグラウンドで実行）
          _deleteOldRoom(room.id);
          return false;
        }

        return true;
      }).toList();
    });
  }

  // プライベートルーム一覧取得
  Stream<List<GameRoom>> getPrivateRooms() {
    return getAllRooms().map((rooms) => rooms.where((room) => room.isPrivate).toList());
  }

  // ルーム状態監視
  Stream<GameRoom?> watchRoom(String roomId) {
    return _database.ref('rooms/$roomId').onValue.map((event) {
      print('🔥 Firebase watchRoom - roomId: $roomId, exists: ${event.snapshot.exists}');
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        print('🔥 Firebase data type: ${data.runtimeType}');
        print('🔥 Firebase raw data: $data');
        try {
          final room = GameRoom.fromMap(Map<String, dynamic>.from(data as Map), roomId);
          print('🔥 GameRoom parsed successfully - players: ${room.players.length}');
          return room;
        } catch (e) {
          print('🔥 Error parsing GameRoom: $e');
          return null;
        }
      }
      print('🔥 Room does not exist');
      return null;
    });
  }

  // ゲーム開始
  Future<void> startGame(String roomId) async {
    await _database.ref('rooms/$roomId').update({
      'state': 'playing',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ゲーム終了
  Future<void> finishGame(String roomId) async {
    await _database.ref('rooms/$roomId').update({
      'state': 'finished',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ルーム退出
  Future<void> leaveRoom(String roomId, String playerId) async {
    final roomSnapshot = await _database.ref('rooms/$roomId').get();
    if (!roomSnapshot.exists) return;

    final room = GameRoom.fromMap(Map<String, dynamic>.from(roomSnapshot.value as Map), roomId);
    final updatedPlayers = room.players.where((player) => player.id != playerId).toList();

    if (updatedPlayers.isEmpty) {
      // 最後のプレイヤーが退出した場合、ルームを削除
      await _database.ref('rooms/$roomId').remove();
    } else {
      await _database.ref('rooms/$roomId').update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // ゲーム開始時のゲーム状態初期化
  Future<void> initializeGameState(String roomId, List<String> playerIds) async {
    print('🎯 ゲーム状態初期化開始 - Room: $roomId, Players: ${playerIds.length}');

    final initialScores = <String, int>{};
    for (final playerId in playerIds) {
      initialScores[playerId] = 0;
    }

    // プレイヤーの順番を入室順（ホストから順番）に維持
    // playerIdsは既に入室順で渡される
    final orderedPlayerIds = List<String>.from(playerIds);

    print('🎯 先行プレイヤー: ${orderedPlayerIds.first.substring(0, 8)}');
    print('🎯 プレイヤー順: ${orderedPlayerIds.map((id) => id.substring(0, 8)).join(', ')}');

    final gameState = OnlineGameState(
      phase: GamePhase.playing,
      bellState: BellState.safe,
      currentPlayerId: orderedPlayerIds.first, // ホスト（最初に入室したプレイヤー）から開始
      currentTurn: 0,
      activePlayers: orderedPlayerIds, // 入室順でゲーム進行
      scores: initialScores,
      timeRemaining: 30,
    );

    await _database.ref('rooms/$roomId').update({
      'state': 'playing',
      'gameState': gameState.toMap(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });

    print('🎯 ゲーム状態初期化完了');
  }

  // ゲーム状態のリアルタイム監視
  Stream<OnlineGameState?> watchGameState(String roomId) {
    return _database.ref('rooms/$roomId/gameState').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      try {
        return OnlineGameState.fromMap(Map<String, dynamic>.from(event.snapshot.value as Map));
      } catch (e) {
        print('Error parsing game state: $e');
        return null;
      }
    });
  }

  // プレイヤーアクション実行（Transactionベース）
  Future<void> performPlayerActionWithId(String roomId, String playerId, String action, String actionId) async {
    // ルーム情報も取得してゲーム設定を参照
    final roomSnapshot = await _database.ref('rooms/$roomId').get();
    if (!roomSnapshot.exists) return;
    final room = GameRoom.fromMap(Map<String, dynamic>.from(roomSnapshot.value as Map), roomId);
    final maxWins = room.gameData?['maxWins'] ?? 3; // デフォルトは3勝

    await _database.ref('rooms/$roomId/gameState').runTransaction((currentData) {
      if (currentData == null) return Transaction.abort();

      if (currentData is! Map) return Transaction.abort();
      final gameState = OnlineGameState.fromMap(Map<String, dynamic>.from(currentData as Map));

      // 現在のプレイヤーでない場合は何もしない
      if (gameState.currentPlayerId != playerId) {
        return Transaction.abort();
      }

      // サーバータイムスタンプを使用
      final serverTimestamp = ServerValue.timestamp;

      // アクション結果を判定（オフライン対戦と同じルール）
      bool isSuccess = false;
      String actionType = '';
      BellState newBellState = gameState.bellState;

      switch (action) {
        case 'tap':
          if (gameState.bellState == BellState.safe) {
            // 箱に入ったベルをタップ → OK（ラリー継続）
            isSuccess = true;
            actionType = 'correct_tap';
            // ベル状態は変わらず、次のプレイヤーに交代
          } else {
            // 危険なベルをタップ → NG（間違い）
            isSuccess = false;
            actionType = 'wrong_action';
          }
          break;

        case 'verticalSwipe':
          if (gameState.bellState == BellState.safe) {
            // 箱に入った状態で縦スワイプ → ベルを危険状態にして送る
            isSuccess = true;
            actionType = 'send_bell';
            newBellState = BellState.danger;
          } else {
            // 危険な状態で縦スワイプ → NG（間違い）
            isSuccess = false;
            actionType = 'wrong_action';
          }
          break;

        case 'horizontalSwipe':
          if (gameState.bellState == BellState.danger) {
            // 危険な状態で横スワイプ → ベルを安全状態にして送る
            isSuccess = true;
            actionType = 'return_to_safe';
            newBellState = BellState.safe;
          } else {
            // 安全な状態で横スワイプ → NG（間違い）
            isSuccess = false;
            actionType = 'wrong_action';
          }
          break;
      }

      // スコア更新（間違えた時のみ）
      final newScores = Map<String, int>.from(gameState.scores);
      if (!isSuccess) {
        // 間違えたプレイヤーに負けポイント（他のプレイヤーに勝ちポイント）
        for (final otherPlayerId in gameState.activePlayers) {
          if (otherPlayerId != playerId) {
            final otherScore = newScores[otherPlayerId] ?? 0;
            newScores[otherPlayerId] = otherScore + 1;
          }
        }
      }

      // 次のプレイヤーを決定
      final currentPlayerIndex = gameState.activePlayers.indexOf(playerId);
      int nextPlayerIndex;
      List<String> activePlayers = List.from(gameState.activePlayers);

      if (!isSuccess) {
        // 間違えた場合、次のプレイヤーから新しいラウンドを開始
        // ベル状態を安全に戻す（オフライン対戦と同じ挙動）
        newBellState = BellState.safe;
        nextPlayerIndex = (currentPlayerIndex + 1) % activePlayers.length;

        // ゲーム終了条件: 最大勝利数に達した場合
        final maxScore = newScores.values.isNotEmpty ? newScores.values.reduce((a, b) => a > b ? a : b) : 0;
        if (maxScore >= maxWins) { // ゲーム設定の勝利数を使用
          final updatedGameState = OnlineGameState(
            phase: GamePhase.gameEnd,
            bellState: newBellState,
            currentPlayerId: null,
            currentTurn: gameState.currentTurn + 1,
            activePlayers: activePlayers,
            scores: newScores,
            lastAction: actionType,
            actionTime: DateTime.now(),
            timeRemaining: 30,
          ).toMap();

          updatedGameState['actionTime'] = serverTimestamp;
          updatedGameState['actionId'] = actionId;
          return Transaction.success(updatedGameState);
        }
      } else {
        nextPlayerIndex = (currentPlayerIndex + 1) % activePlayers.length;
      }

      final nextPlayerId = activePlayers[nextPlayerIndex];

      // ゲーム状態更新
      final updatedGameState = OnlineGameState(
        phase: GamePhase.playing,
        bellState: newBellState,
        currentPlayerId: nextPlayerId,
        currentTurn: gameState.currentTurn + 1,
        activePlayers: activePlayers,
        scores: newScores,
        lastAction: actionType,
        actionTime: DateTime.now(),
        timeRemaining: 30,
      ).toMap();

      updatedGameState['actionTime'] = serverTimestamp;
      updatedGameState['actionId'] = actionId;
      return Transaction.success(updatedGameState);
    });
  }

  // 既存のメソッド（後方互換性のため残す）
  Future<void> performPlayerAction(String roomId, String playerId, String action) async {
    final actionId = DateTime.now().millisecondsSinceEpoch.toString();
    await performPlayerActionWithId(roomId, playerId, action, actionId);
  }

  // 古い部屋を削除（バックグラウンドで実行）
  Future<void> _deleteOldRoom(String roomId) async {
    try {
      print('🗑️ 古い部屋を削除中: $roomId');
      await _database.ref('rooms/$roomId').remove();
      print('✅ 古い部屋を削除完了: $roomId');
    } catch (e) {
      print('❌ 古い部屋削除エラー: $e');
    }
  }

  // 旧バージョン（非推奨）
  Future<void> _performPlayerActionLegacy(String roomId, String playerId, String action) async {
    final roomSnapshot = await _database.ref('rooms/$roomId').get();
    if (!roomSnapshot.exists) return;

    final room = GameRoom.fromMap(Map<String, dynamic>.from(roomSnapshot.value as Map), roomId);
    final gameState = room.gameState;
    if (gameState == null) return;

    // 現在のプレイヤーでない場合は何もしない
    if (gameState.currentPlayerId != playerId) return;

    // アクション結果を判定
    bool isSuccess = false;
    String actionType = '';
    BellState newBellState = gameState.bellState;

    switch (action) {
      case 'tap':
        if (gameState.bellState == BellState.safe) {
          // 箱に入ったベルをタップ → OK
          isSuccess = true;
          actionType = 'correct_tap';
        } else {
          // 危険な状態でタップ → NG
          isSuccess = false;
          actionType = 'wrong_action';
        }
        break;

      case 'verticalSwipe':
        if (gameState.bellState == BellState.safe) {
          // 箱に入った状態で縦スワイプ → ベル送り
          isSuccess = true;
          actionType = 'send_bell';
          newBellState = BellState.danger;
        } else {
          // 危険な状態で縦スワイプ → NG
          isSuccess = false;
          actionType = 'wrong_action';
        }
        break;

      case 'horizontalSwipe':
        if (gameState.bellState == BellState.danger) {
          // 危険な状態で横スワイプ → 箱に戻す
          isSuccess = true;
          actionType = 'return_to_safe';
          newBellState = BellState.safe;
        } else {
          // 安全な状態で横スワイプ → 何もしない（無視）
          return;
        }
        break;
    }

    // スコア更新
    final currentScore = gameState.scores[playerId] ?? 0;
    final newScores = Map<String, int>.from(gameState.scores);
    if (isSuccess) {
      newScores[playerId] = currentScore + 1;
    }

    // 次のプレイヤーを決定
    final currentPlayerIndex = gameState.activePlayers.indexOf(playerId);
    int nextPlayerIndex;
    List<String> activePlayers = List.from(gameState.activePlayers);

    if (!isSuccess) {
      // 失敗した場合、プレイヤーを除外
      activePlayers.remove(playerId);
      if (activePlayers.isEmpty) {
        // 全プレイヤーが除外された場合、ゲーム終了
        final updatedGameState = OnlineGameState(
          phase: GamePhase.gameEnd,
          bellState: newBellState,
          currentPlayerId: null,
          currentTurn: gameState.currentTurn + 1,
          activePlayers: activePlayers,
          scores: newScores,
          lastAction: actionType,
          actionTime: DateTime.now(),
          timeRemaining: 0,
        );

        await _database.ref('rooms/$roomId/gameState').set(updatedGameState.toMap());
        return;
      }
      nextPlayerIndex = currentPlayerIndex % activePlayers.length;
    } else {
      nextPlayerIndex = (currentPlayerIndex + 1) % activePlayers.length;
    }

    final nextPlayerId = activePlayers[nextPlayerIndex];

    // ゲーム状態更新
    final updatedGameState = OnlineGameState(
      phase: GamePhase.playing,
      bellState: newBellState,
      currentPlayerId: nextPlayerId,
      currentTurn: gameState.currentTurn + 1,
      activePlayers: activePlayers,
      scores: newScores,
      lastAction: actionType,
      actionTime: DateTime.now(),
      timeRemaining: 30, // 30秒に修正
    );

    await _database.ref('rooms/$roomId/gameState').set(updatedGameState.toMap());
  }

  // 古いルームを定期清掃（1時間以上前のもの）
  Future<void> cleanupOldRooms() async {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final snapshot = await _database.ref('rooms').get();

    if (!snapshot.exists) return;

    final roomsData = Map<String, dynamic>.from(snapshot.value as Map);

    for (final entry in roomsData.entries) {
      try {
        final roomData = Map<String, dynamic>.from(entry.value as Map);
        final updatedAt = DateTime.fromMillisecondsSinceEpoch(roomData['updatedAt'] ?? 0);

        if (updatedAt.isBefore(oneHourAgo)) {
          await _database.ref('rooms/${entry.key}').remove();
        }
      } catch (e) {
        print('Error cleaning up room ${entry.key}: $e');
      }
    }
  }
}

// GameRoomのcopyWithメソッドを追加
extension GameRoomExtension on GameRoom {
  GameRoom copyWith({
    String? id,
    String? name,
    String? password,
    bool? isPrivate,
    RoomState? state,
    List<Player>? players,
    Map<String, dynamic>? gameData,
    OnlineGameState? gameState,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GameRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      isPrivate: isPrivate ?? this.isPrivate,
      state: state ?? this.state,
      players: players ?? this.players,
      gameData: gameData ?? this.gameData,
      gameState: gameState ?? this.gameState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}