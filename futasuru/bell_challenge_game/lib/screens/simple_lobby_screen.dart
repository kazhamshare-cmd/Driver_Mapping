import 'package:flutter/material.dart';
import '../services/simple_room_service.dart';
import '../services/i18n_service.dart';
import 'simple_game_screen.dart';

class SimpleLobbyScreen extends StatefulWidget {
  final VoidCallback onBackToMenu;

  const SimpleLobbyScreen({super.key, required this.onBackToMenu});

  @override
  State<SimpleLobbyScreen> createState() => _SimpleLobbyScreenState();
}

class _SimpleLobbyScreenState extends State<SimpleLobbyScreen> {
  final SimpleRoomService _roomService = SimpleRoomService();
  final TextEditingController _nameController = TextEditingController();

  List<SimpleRoom> _availableRooms = [];
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = '${t('common.player')}${DateTime.now().millisecondsSinceEpoch % 1000}';
    _loadAvailableRooms(); // 古いルームの自動清掃機能付き
  }

  // デバッグ用：全ルーム削除とリロード（手動実行用）
  Future<void> _cleanupAndLoadRooms() async {
    setState(() {
      _isLoading = true;
      _statusMessage = t('online.lobby.deletingAllRooms');
    });

    try {
      // 全てのルームを削除（デバッグ用）
      await _roomService.deleteAllRooms();
      print('🗑️ 全ルーム削除完了');

      await Future.delayed(const Duration(milliseconds: 500));

      // ルーム一覧を読み込み
      await _loadAvailableRooms();
    } catch (e) {
      setState(() {
        _statusMessage = t('online.lobby.deleteRoomError', params: {'error': e.toString()});
      });
    }
  }

  // 利用可能ルーム一覧を読み込み
  Future<void> _loadAvailableRooms() async {
    setState(() {
      _isLoading = true;
      _statusMessage = t('online.lobby.loadingRooms');
    });

    try {
      // まず古いルームを清掃
      final cleanedCount = await _roomService.cleanupOldRooms();
      if (cleanedCount > 0) {
        print('🧹 ${cleanedCount}個の古いルームを削除しました');
      }

      final rooms = await _roomService.getAvailableRooms();
      setState(() {
        _availableRooms = rooms;
        _statusMessage = t('online.lobby.roomsAvailable', params: {'count': rooms.length});
      });
    } catch (e) {
      setState(() {
        _statusMessage = t('online.lobby.loadRoomsFailed', params: {'error': e.toString()});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ゲーム設定ダイアログを表示してルーム作成
  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage(t('online.lobby.enterPlayerName'));
      return;
    }

    // ゲーム設定ダイアログを表示
    final gameSettings = await _showGameSettingsDialog();
    if (gameSettings == null) return; // キャンセルされた場合

    setState(() {
      _isLoading = true;
      _statusMessage = t('online.lobby.creatingRoom');
    });

    try {
      final room = await _roomService.createRoom(
        _nameController.text.trim(),
        roomName: gameSettings['roomName']! as String,
        rounds: gameSettings['rounds']! as int,
        timeLimit: gameSettings['timeLimit']! as int,
        maxPlayers: gameSettings['maxPlayers']! as int,
      );

      if (room != null) {
        print('🏠 ルーム作成成功 - ID: ${room.id}');
        _navigateToGameScreen(room.id, room.players.first.id, _nameController.text.trim());
      } else {
        setState(() {
          _statusMessage = t('online.lobby.createRoomFailed2');
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = t('online.lobby.createRoomError', params: {'error': e.toString()});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ゲーム設定ダイアログ
  Future<Map<String, dynamic>?> _showGameSettingsDialog() async {
    int rounds = 3;
    int timeLimit = 2;
    int maxPlayers = 2;  // 2名対戦に固定
    final roomNameController = TextEditingController(
      text: t('online.lobby.myRoom', params: {'name': _nameController.text.trim()}),
    );

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2a2a4e),
              title: Text(
                t('online.lobby.gameSettings'),
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ルーム名入力
                    TextField(
                      controller: roomNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: t('online.lobby.roomName'),
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: t('online.lobby.roomNamePlaceholder'),
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white30),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 試合数設定
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('online.lobby.rounds'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: rounds > 1 ? () => setState(() => rounds--) : null,
                              icon: const Icon(Icons.remove, color: Colors.white),
                            ),
                            Text(
                              '$rounds',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            IconButton(
                              onPressed: rounds < 10 ? () => setState(() => rounds++) : null,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 制限時間設定
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('online.lobby.timeLimitSetting'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: timeLimit > 1 ? () => setState(() => timeLimit--) : null,
                              icon: const Icon(Icons.remove, color: Colors.white),
                            ),
                            Text(
                              t('online.lobby.timeLimitSeconds', params: {'time': timeLimit}),
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            IconButton(
                              onPressed: timeLimit < 4 ? () => setState(() => timeLimit++) : null,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    roomNameController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: Text(t('common.cancel'), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final roomName = roomNameController.text.trim();
                    roomNameController.dispose();
                    Navigator.of(context).pop({
                      'roomName': roomName.isEmpty ? t('online.lobby.myRoom', params: {'name': _nameController.text.trim()}) : roomName,
                      'rounds': rounds,
                      'timeLimit': timeLimit,
                      'maxPlayers': maxPlayers,
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(t('common.create'), style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ルーム参加
  Future<void> _joinRoom(String roomId) async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage(t('online.lobby.enterPlayerName'));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = t('online.lobby.joiningRoom');
    });

    try {
      final room = await _roomService.joinRoom(roomId, _nameController.text.trim());

      if (room != null) {
        print('🏠 ルーム参加成功 - ID: ${room.id}');
        // 最後に参加したプレイヤーのIDを取得
        final myPlayer = room.players.last;
        _navigateToGameScreen(room.id, myPlayer.id, _nameController.text.trim());
      } else {
        setState(() {
          _statusMessage = t('online.lobby.joinRoomFailed2');
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = t('online.lobby.joinRoomError', params: {'error': e.toString()});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 参加確認ダイアログ
  Future<void> _showJoinConfirmDialog(SimpleRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a4e),
          title: Text(
            t('online.lobby.joinRoomTitle', params: {'name': room.name}),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('online.lobby.roomConditions2'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                t('online.lobby.roundsLabel', params: {'count': room.rounds}),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                t('online.lobby.timeLimitLabel2', params: {'time': room.timeLimit}),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                t('online.lobby.maxPlayersLabel', params: {'count': room.maxPlayers}),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                t('online.lobby.currentPlayersLabel', params: {'count': room.players.length}),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                t('online.lobby.joinConfirmation'),
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t('common.cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text(t('common.join'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _joinRoom(room.id);
    }
  }

  // ゲーム画面に遷移
  void _navigateToGameScreen(String roomId, String playerId, String playerName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SimpleGameScreen(
          roomId: roomId,
          playerId: playerId,
          playerName: playerName,
          onBackToLobby: () {
            Navigator.of(context).pop();
            _loadAvailableRooms(); // ロビーに戻ったらルーム一覧を再読み込み
          },
          onBackToMenu: widget.onBackToMenu,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

              // プレイヤー名入力
              _buildPlayerNameInput(),

              const SizedBox(height: 20),

              // ルーム作成ボタン
              _buildCreateRoomButton(),

              const SizedBox(height: 20),

              // ステータスメッセージ
              _buildStatusMessage(),

              const SizedBox(height: 20),

              // 利用可能ルーム一覧
              Expanded(
                child: _buildAvailableRoomsList(),
              ),

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
            t('online.lobby.lobbyTitle'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('online.lobby.lobbySubtitle'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerNameInput() {
    return TextField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: t('online.lobby.playerName'),
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildCreateRoomButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          t('online.lobby.createRoomButton'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (_isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          if (_isLoading) const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableRoomsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('online.lobby.availableRooms'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                // デバッグ用：全削除ボタン
                IconButton(
                  onPressed: _isLoading ? null : _cleanupAndLoadRooms,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: '全ルーム削除',
                ),
                // 更新ボタン
                IconButton(
                  onPressed: _isLoading ? null : _loadAvailableRooms,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '更新',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _availableRooms.isEmpty
              ? Center(
                  child: Text(
                    t('online.lobby.noRooms'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: _availableRooms.length,
                  itemBuilder: (context, index) {
                    final room = _availableRooms[index];
                    return Card(
                      color: Colors.white.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${room.name} (${room.id})',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('online.lobby.roomListItem', params: {'players': room.players.length, 'maxPlayers': room.maxPlayers}),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              t('online.lobby.roomDetails', params: {'rounds': room.rounds, 'timeLimit': room.timeLimit}),
                              style: const TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: _isLoading ? null : () => _showJoinConfirmDialog(room),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text(
                            t('online.lobby.joinButton'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onBackToMenu,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          t('online.lobby.backToMenu'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}