import 'package:flutter/material.dart';
import 'dart:async';
import '../services/simple_room_service.dart';
import '../screens/online_game_screen.dart';
import '../screens/simple_lobby_screen.dart';
import '../models/game_settings.dart';

class SimpleGameScreen extends StatefulWidget {
  final String roomId;
  final String playerId;
  final String playerName;
  final VoidCallback onBackToLobby;
  final VoidCallback onBackToMenu;

  const SimpleGameScreen({
    super.key,
    required this.roomId,
    required this.playerId,
    required this.playerName,
    required this.onBackToLobby,
    required this.onBackToMenu,
  });

  @override
  State<SimpleGameScreen> createState() => _SimpleGameScreenState();
}

class _SimpleGameScreenState extends State<SimpleGameScreen> {
  final SimpleRoomService _roomService = SimpleRoomService();

  SimpleRoom? _currentRoom;
  StreamSubscription<SimpleRoom?>? _roomSubscription;
  bool _isLoading = true;
  String _statusMessage = 'ルーム情報を読み込み中...';
  bool _shouldLeaveOnDispose = true;

  @override
  void initState() {
    super.initState();
    print('🏠 SimpleGameScreen 初期化開始');
    print('🏠 roomId: ${widget.roomId}');
    print('🏠 playerId: ${widget.playerId}');
    print('🏠 playerName: ${widget.playerName}');
    _startListening();
  }

  void _startListening() {
    print('🏠 ルーム監視開始: ${widget.roomId}');

    _roomSubscription = _roomService.watchRoom(widget.roomId).listen(
      (room) {
        print('🏠 ルームデータ受信: ${room?.players.length ?? 0}人, 状態: ${room?.state}');

        if (mounted) {
          final previousRoom = _currentRoom;
          
          setState(() {
            _currentRoom = room;
            _isLoading = false;

            if (room != null) {
              _statusMessage = '${room.players.length}人が参加中';
            } else {
              _statusMessage = 'ルームが見つかりません';
            }
          });

          // ルーム状態がplayingに変わった場合、自動的にゲーム画面に遷移（参加者側）
          if (room != null && 
              room.state == SimpleRoomState.playing && 
              previousRoom?.state != SimpleRoomState.playing &&
              !_isHost()) {
            print('🎮 ゲーム開始を検知 - ゲーム画面に自動遷移 (参加者)');
            _joinGameScreen();
          }
        }
      },
      onError: (error) {
        print('🚨 ルーム監視エラー: $error');

        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'ルーム情報の取得に失敗しました: $error';
          });
        }
      },
    );
  }

  // ルーム情報を手動で更新
  Future<void> _refreshRoomStatus() async {
    print('🔄 ルーム情報を手動更新中...');

    setState(() {
      _isLoading = true;
      _statusMessage = 'ルーム情報を更新中...';
    });

    // デバッグ用：ルーム詳細確認
    await _roomService.debugInspectRoom(widget.roomId);

    // 少し待ってから状態をリセット
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ヘッダー
              _buildHeader(),

              const SizedBox(height: 20),

              // ステータス表示
              _buildStatusSection(),

              const SizedBox(height: 10),

              // ゲーム設定表示
              _buildGameSettingsSection(),

              const SizedBox(height: 20),

              // プレイヤー一覧
              Expanded(
                child: _buildPlayersList(),
              ),

              // アクションボタン
              _buildActionButtons(),

              const SizedBox(height: 20),

              // 戻るボタン
              _buildBackButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'ルーム: ${widget.roomId}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentRoom?.name ?? '読み込み中...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _currentRoom?.state == SimpleRoomState.playing
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentRoom?.state == SimpleRoomState.playing ? 'プレイ中' : '待機中',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          if (_isLoading) const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSettingsSection() {
    if (_currentRoom == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ゲーム設定',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text(
                    '試合数',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${_currentRoom!.rounds}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    '制限時間',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${_currentRoom!.timeLimit}秒',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    '最大人数',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${_currentRoom!.maxPlayers}人',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList() {
    if (_currentRoom == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'ルーム情報を読み込み中...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '参加プレイヤー (${_currentRoom!.players.length}人)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _currentRoom!.players.length,
            itemBuilder: (context, index) {
              final player = _currentRoom!.players[index];
              final isMe = player.id == widget.playerId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: isMe
                      ? Border.all(color: Colors.blue, width: 2)
                      : null,
                ),
                child: Row(
                  children: [
                    // プレイヤーアイコン
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: player.isHost ? Colors.orange : Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        player.isHost ? Icons.star : Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // プレイヤー情報
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                player.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'あなた',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (player.isHost)
                            Text(
                              'ホスト',
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 接続状況
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 更新ボタン
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _refreshRoomStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('状況を更新'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ゲーム開始ボタン（ホストかつ2人以上で表示）
        if (_currentRoom != null &&
            _currentRoom!.players.length >= 2 &&
            _isHost())
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _startGame();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('ゲーム開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // プレイヤーがルームから退出
          await _roomService.leaveRoom(widget.roomId, widget.playerId);
          widget.onBackToLobby();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'ロビーに戻る',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ホスト判定
  bool _isHost() {
    if (_currentRoom == null) return false;
    final myPlayer = _currentRoom!.players.firstWhere(
      (player) => player.id == widget.playerId,
      orElse: () => SimplePlayer(id: '', name: '', isHost: false, joinedAt: DateTime.now()),
    );
    return myPlayer.isHost;
  }

  // ゲーム開始処理（ホスト用）
  void _startGame() async {
    print('🎮 ゲーム開始 - ホスト: ${widget.playerName}');

    if (_currentRoom == null) return;

    // ルーム状態をプレイ中に更新
    await _roomService.updateRoomState(widget.roomId, SimpleRoomState.playing);

    // ゲーム画面に遷移
    _joinGameScreen();
  }

  // ゲーム画面に遷移（ホスト・参加者共通）
  void _joinGameScreen() {
    if (_currentRoom == null) return;

    // ルームの設定に基づいたGameSettingsを作成
    final customGameSettings = GameSettings(
      timeLimit: _currentRoom!.timeLimit,
      maxWins: _currentRoom!.rounds,
      hapticFeedback: true,
      soundEffects: true,
      bgmEnabled: true,
      bgmVolume: 0.3,
      seVolume: 0.8,
      selectedDifficulty: DifficultyLevel.levels[1], // normal
    );

    // ゲーム画面遷移時は退出しない
    _shouldLeaveOnDispose = false;

    // オンラインマルチプレイヤーゲーム画面に遷移
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OnlineGameScreen(
            gameSettings: customGameSettings,
            roomId: widget.roomId,
            playerId: widget.playerId,
            playerName: widget.playerName,
            onBackToLobby: () async {
              // ゲーム終了時の処理：ルームを削除（ホストのみ）
              if (_isHost()) {
                await _roomService.deleteRoom(widget.roomId);
              } else {
                await _roomService.leaveRoom(widget.roomId, widget.playerId);
              }

              // ロビーに戻る
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => SimpleLobbyScreen(
                    onBackToMenu: widget.onBackToMenu,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    print('🏠 SimpleGameScreen 終了');
    _roomSubscription?.cancel();

    // ゲーム開始時以外のみ退出処理を実行
    if (_shouldLeaveOnDispose) {
      print('🚪 待機画面から退出 - ルームから退出します');
      _roomService.leaveRoom(widget.roomId, widget.playerId).catchError((error) {
        print('🚨 画面終了時のルーム退出エラー: $error');
      });
    } else {
      print('🎮 ゲーム画面に遷移 - ルームに残ります');
    }

    super.dispose();
  }
}