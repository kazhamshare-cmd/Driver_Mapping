import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import 'online_game_play_screen.dart';

/// オンライン対戦画面
class OnlineGameScreen extends StatefulWidget {
  final Room room;
  final String currentPlayerId;

  const OnlineGameScreen({
    super.key,
    required this.room,
    required this.currentPlayerId,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  final RoomService _roomService = RoomService.instance;
  late Stream<Room?> _roomStream;
  bool _isNavigating = false; // 画面遷移フラグ

  @override
  void initState() {
    super.initState();
    _roomStream = _roomService.getRoom(widget.room.id);

    // ルームの生存確認を実行
    _checkRoomHealth();
  }

  Future<void> _checkRoomHealth() async {
    try {
      await _roomService.checkRoomHealth(widget.room.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ルーム生存確認エラー: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Room?>(
            stream: _roomStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorScreen(snapshot.error.toString());
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              final room = snapshot.data;
              if (room == null) {
                return _buildRoomNotFoundScreen();
              }

              // ルームステータスがplayingになったら、ゲーム画面に自動遷移
              print('🎮 [準備画面] ルームステータス: ${room.status}, 遷移フラグ: $_isNavigating');
              if (room.status == RoomStatus.playing && !_isNavigating) {
                print('🎮 [準備画面] ゲーム画面への遷移を開始します');
                _isNavigating = true; // 遷移フラグを設定
                
                // 即座に画面遷移を実行
                Future.microtask(() {
                  if (mounted) {
                    print('🎮 [準備画面] Navigator.pushReplacementを実行します');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnlineGamePlayScreen(
                          room: room,
                          currentPlayerId: widget.currentPlayerId,
                        ),
                      ),
                    );
                  }
                });
              } else if (room.status == RoomStatus.playing && _isNavigating) {
                print('🎮 [準備画面] 既に遷移中です - スキップ');
              }

              return _buildGameScreen(room);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGameScreen(Room room) {
    return Column(
      children: [
        // ヘッダー
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                room.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ステータス: ${_getStatusText(room.status)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        
        // プレイヤー一覧
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildPlayerList(room),
          ),
        ),
        
        // アクションボタン
        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildActionButtons(room),
        ),
      ],
    );
  }

  Widget _buildPlayerList(Room room) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '参加者',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const Spacer(),
              Text(
                '${room.playerCount}/${room.maxPlayers}人',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ...room.players.map((player) => _buildPlayerCard(player)),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: player.isHost ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: player.isHost ? Colors.amber : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            player.isHost ? Icons.star : Icons.person,
            color: player.isHost ? Colors.amber : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: player.isHost ? FontWeight.bold : FontWeight.normal,
                color: player.isHost ? Colors.amber : Colors.grey,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(player.status),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getPlayerStatusText(player.status),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Room room) {
    switch (room.status) {
      case RoomStatus.waiting:
        return _buildWaitingButtons(room);
      case RoomStatus.playing:
        return _buildPlayingButtons(room);
      case RoomStatus.finished:
        return _buildFinishedButtons(room);
    }
  }

  Widget _buildWaitingButtons(Room room) {
    return Column(
      children: [
        if (_isHost(room)) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: room.players.length >= 2
                  ? () => _startGame(room)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              child: Text(
                room.players.length >= 2
                    ? 'ゲーム開始'
                    : 'プレイヤーを待機中...',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _leaveRoom(room),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'ルームを退出',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayingButtons(Room room) {
    return Column(
      children: [
        const Text(
          'ゲーム中...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _leaveRoom(room),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'ルームを退出',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedButtons(Room room) {
    return Column(
      children: [
        const Text(
          'ゲーム終了',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _leaveRoom(room),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'ルームを退出',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'エラーが発生しました',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomNotFoundScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'ルームが見つかりません',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ルームが削除されたか、存在しません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '戻る',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.waiting:
        return '待機中';
      case RoomStatus.playing:
        return 'プレイ中';
      case RoomStatus.finished:
        return '終了';
    }
  }

  String _getPlayerStatusText(PlayerStatus status) {
    switch (status) {
      case PlayerStatus.waiting:
        return '待機中';
      case PlayerStatus.ready:
        return '準備完了';
      case PlayerStatus.playing:
        return 'プレイ中';
      case PlayerStatus.eliminated:
        return '脱落';
      case PlayerStatus.finished:
        return '終了';
    }
  }

  Color _getStatusColor(PlayerStatus status) {
    switch (status) {
      case PlayerStatus.waiting:
        return Colors.grey;
      case PlayerStatus.ready:
        return Colors.green;
      case PlayerStatus.playing:
        return Colors.blue;
      case PlayerStatus.eliminated:
        return Colors.red;
      case PlayerStatus.finished:
        return Colors.orange;
    }
  }

  bool _isHost(Room room) {
    // 現在のユーザーがホストかどうかを判定
    final currentPlayer = room.players.firstWhere(
      (p) => p.id == widget.currentPlayerId,
      orElse: () => room.players.first,
    );
    return currentPlayer.isHost;
  }

  Future<void> _startGame(Room room) async {
    try {
      print('🎮 [準備画面] ゲーム開始を試行します: ${room.id}');
      await _roomService.startRoom(room.id);
      print('🎮 [準備画面] ルーム開始成功');
      
      // ゲーム開始成功時のメッセージ表示のみ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ゲームを開始しました！'),
            backgroundColor: Colors.green,
          ),
        );
        
        // StreamBuilderで自動的に画面遷移されるため、ここでは遷移しない
      }
    } catch (e) {
      print('🎮 [準備画面] ゲーム開始エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ゲーム開始に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveRoom(Room room) async {
    try {
      await _roomService.leaveRoom(room.id, widget.currentPlayerId);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ ルーム退出エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ルーム退出に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}