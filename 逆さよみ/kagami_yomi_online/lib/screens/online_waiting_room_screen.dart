import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import '../services/firebase_service.dart';
import '../services/sound_service.dart';
import 'online_game_screen.dart';

class OnlineWaitingRoomScreen extends StatefulWidget {
  final String roomId;
  final String playerId;
  final bool isHost;

  const OnlineWaitingRoomScreen({
    super.key,
    required this.roomId,
    required this.playerId,
    required this.isHost,
  });

  @override
  State<OnlineWaitingRoomScreen> createState() =>
      _OnlineWaitingRoomScreenState();
}

class _OnlineWaitingRoomScreenState extends State<OnlineWaitingRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _hasNavigatedToGame = false; // ゲーム画面への遷移を1回だけ実行するフラグ

  @override
  void dispose() {
    // ゲームに遷移せずに退出する場合のみ、プレイヤーを削除
    // ゲーム開始で遷移した場合は削除しない
    if (!widget.isHost && !_hasNavigatedToGame) {
      _firebaseService.leaveRoom(
        roomId: widget.roomId,
        playerId: widget.playerId,
      );
    }
    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      await _firebaseService.startGame(widget.roomId);
      SoundService().playGameStart();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(
              roomId: widget.roomId,
              playerId: widget.playerId,
              isHost: widget.isHost,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出確認'),
        content: Text(widget.isHost
            ? 'ホストが退出するとルームが削除されます。よろしいですか？'
            : 'ルームから退出しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (widget.isHost) {
        await _firebaseService.deleteRoom(widget.roomId);
      } else {
        await _firebaseService.leaveRoom(
          roomId: widget.roomId,
          playerId: widget.playerId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveRoom();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '待機中',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveRoom,
          ),
          actions: [
            // BGM切り替えボタン
            IconButton(
              icon: Icon(
                SoundService().bgmEnabled ? Icons.music_note : Icons.music_off,
              ),
              onPressed: () {
                setState(() {
                  SoundService().toggleBgm();
                });
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green.shade50,
                Colors.purple.shade50,
              ],
            ),
          ),
          child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) {
              // ルームが削除された
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ルームが削除されました')),
                  );
                }
              });
              return const Center(child: Text('ルームが削除されました'));
            }

            final room = GameRoom.fromMap(data);

            // ゲームが開始された場合、ゲーム画面に遷移（1回だけ）
            if (room.status == RoomStatus.playing && !_hasNavigatedToGame) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_hasNavigatedToGame) {
                  setState(() {
                    _hasNavigatedToGame = true;
                  });
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => OnlineGameScreen(
                        roomId: widget.roomId,
                        playerId: widget.playerId,
                        isHost: widget.isHost,
                      ),
                    ),
                  );
                }
              });
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ルーム情報
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.deepPurple.shade200,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.2),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.meeting_room,
                                      color: Colors.deepPurple,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      room.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: room.password != null
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: room.password != null
                                        ? Colors.orange
                                        : Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      size: 20,
                                      color: room.password != null
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      room.password != null
                                          ? 'パスワード保護'
                                          : 'パスワードなし',
                                      style: TextStyle(
                                        color: room.password != null
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.gamepad,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${room.maxStages} ステージ',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // プレイヤー一覧
                        Text(
                          'プレイヤー',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.deepPurple,
                            shadows: [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black.withOpacity(0.1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...room.players.map((player) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: player.id == room.hostId
                                      ? Colors.orange.shade300
                                      : Colors.blue.shade300,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (player.id == room.hostId
                                            ? Colors.orange
                                            : Colors.blue)
                                        .withOpacity(0.2),
                                    offset: const Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: player.id == room.hostId
                                          ? [Colors.orange, Colors.orange.shade700]
                                          : [Colors.blue, Colors.blue.shade700],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    player.id == room.hostId
                                        ? Icons.star
                                        : Icons.person,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (player.id == room.hostId
                                            ? Colors.orange
                                            : Colors.blue)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    player.id == room.hostId ? 'ホスト' : 'ゲスト',
                                    style: TextStyle(
                                      color: player.id == room.hostId
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            )),

                        if (room.players.length < 2)
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '他のプレイヤーの参加を待っています...',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ボタンエリア
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isHost) ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: room.players.length >= 2
                                  ? const LinearGradient(
                                      colors: [
                                        Colors.green,
                                        Color.fromARGB(255, 56, 142, 60)
                                      ],
                                    )
                                  : null,
                              color: room.players.length < 2
                                  ? Colors.grey.shade300
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: room.players.length >= 2
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed: room.players.length >= 2
                                  ? _startGame
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text(
                                'ゲームを開始',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _leaveRoom,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ルームを削除',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.red,
                                  Color.fromARGB(255, 198, 40, 40)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _leaveRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text(
                                'ルームから退出',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}
