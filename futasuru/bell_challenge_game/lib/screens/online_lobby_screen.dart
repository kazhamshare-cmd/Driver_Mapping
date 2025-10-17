import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/room_service.dart';
import '../models/game_settings.dart';
import '../services/sound_service.dart';
import '../services/i18n_service.dart';
import 'online_game_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  final GameSettings gameSettings;
  final VoidCallback onBackToSettings;

  const OnlineLobbyScreen({
    super.key,
    required this.gameSettings,
    required this.onBackToSettings,
  });

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final RoomService _roomService = RoomService();
  final SoundService _soundService = SoundService();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showCreateRoom = false;
  bool _isLoading = false;
  String _playerId = '';
  bool _isPrivateRoom = false;
  DifficultyLevel _selectedDifficulty = DifficultyLevel.levels[1];

  @override
  void initState() {
    super.initState();
    _playerId = const Uuid().v4();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setPlayerInfo(String playerName) {
    // RoomServiceでは設定不要（各メソッドでplayerNameを直接渡す）
  }

  Future<void> _createRoom() async {
    if (_isLoading) return;

    final roomName = _roomNameController.text.trim();
    if (roomName.isEmpty) {
      _showErrorDialog(t('online.lobby.roomNameRequired'));
      return;
    }

    // プレイヤー名を入力ダイアログで取得
    final playerName = await _showPlayerNameDialog();
    if (playerName == null || playerName.isEmpty) return;

    _setPlayerInfo(playerName);

    setState(() => _isLoading = true);

    try {
      print('🔥 ルーム作成開始');
      print('🔥 ルーム名: $roomName');
      print('🔥 プレイヤー名: $playerName');
      print('🔥 プライベート: $_isPrivateRoom');

      final gameSettingsWithDifficulty = widget.gameSettings.copyWith(
        selectedDifficulty: _selectedDifficulty,
        timeLimit: _selectedDifficulty.timeLimit,
      );

      final gameData = {
        'maxWins': gameSettingsWithDifficulty.maxWins,
        'timeLimit': gameSettingsWithDifficulty.timeLimit,
        'hapticFeedback': gameSettingsWithDifficulty.hapticFeedback,
        'soundEffects': gameSettingsWithDifficulty.soundEffects,
        'bgmEnabled': gameSettingsWithDifficulty.bgmEnabled,
        'bgmVolume': gameSettingsWithDifficulty.bgmVolume,
        'seVolume': gameSettingsWithDifficulty.seVolume,
      };

      print('🔥 gameData: $gameData');

      final room = await _roomService.createRoom(
        playerName: playerName,
        roomName: roomName,
        password: _isPrivateRoom ? _passwordController.text : null,
        gameData: gameData,
      );

      print('🔥 ルーム作成成功: ${room.id}');
      _soundService.playButtonClick();

      if (mounted) {
        print('🏠 ルーム作成完了 - OnlineGameScreenに遷移: roomId=${room.id}, playerId=${room.players.first.id}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              print('🏠 OnlineGameScreen生成中...');
              return OnlineGameScreen(
                roomId: room.id,
                playerId: room.players.first.id,
                playerName: playerName,
                gameSettings: gameSettingsWithDifficulty,
                onBackToLobby: () => Navigator.pop(context),
              );
            },
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ ルーム作成エラー: $e');
      print('❌ スタックトレース: $stackTrace');
      _showErrorDialog('${t('online.lobby.createRoomFailed')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _joinPublicRoom(GameRoom room) async {
    if (_isLoading) return;

    // プレイヤー名を入力ダイアログで取得
    final playerName = await _showPlayerNameDialog();
    if (playerName == null || playerName.isEmpty) return;

    _setPlayerInfo(playerName);

    setState(() => _isLoading = true);

    try {
      String? password;
      if (room.isPrivate) {
        password = await _showPasswordDialog();
        if (password == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final joinedRoom = await _roomService.joinRoom(
        roomId: room.id,
        playerName: playerName,
        password: password,
      );

      _soundService.playButtonClick();

      if (mounted && joinedRoom != null) {
        // 参加したプレイヤーのIDを取得
        final joinedPlayer = joinedRoom.players.firstWhere((p) => p.name == playerName);

        print('🏠 ルーム参加完了 - OnlineGameScreenに遷移: roomId=${room.id}, playerId=${joinedPlayer.id}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              print('🏠 OnlineGameScreen生成中（参加）...');
              return OnlineGameScreen(
                roomId: room.id,
                playerId: joinedPlayer.id,
                playerName: playerName,
                gameSettings: widget.gameSettings,
                onBackToLobby: () => Navigator.pop(context),
              );
            },
          ),
        );
      }
    } catch (e) {
      _showErrorDialog('${t('online.lobby.joinRoomFailed')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showPlayerNameDialog() async {
    final TextEditingController controller = TextEditingController(
      text: 'Player${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: Text(
          t('online.lobby.enterPlayerName'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t('online.lobby.playerNameHint'),
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.orange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('common.cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: Text(t('common.ok'), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog() async {
    final TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: Text(
          t('online.lobby.enterPassword'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          obscureText: true,
          decoration: InputDecoration(
            hintText: t('online.lobby.passwordHint'),
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.orange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('common.cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: Text(t('common.ok'), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLimitSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('online.lobby.timeLimit'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: DifficultyLevel.levels.map((difficulty) {
              final isSelected = _selectedDifficulty.id == difficulty.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDifficulty = difficulty;
                    });
                    _soundService.playButtonClick();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          difficulty.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('online.lobby.seconds', params: {'time': difficulty.timeLimit}),
                          style: TextStyle(
                            color: isSelected ? Colors.orange : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213e),
        title: Text(t('common.error'), style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('common.ok'), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1e),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              I18nService.translate('settings.onlineMode'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213e),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBackToSettings,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF16213e),
              const Color(0xFF0f0f1e),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // オンラインモード説明カード
              _buildInfoCard(),

              const SizedBox(height: 20),

              // 公開部屋一覧
              _buildSectionCard(
                title: '🎮 ${t('online.lobby.publicRooms')}',
                subtitle: t('online.lobby.publicRoomsSubtitle'),
                icon: Icons.public,
                child: SizedBox(
                  height: 320,
                  child: StreamBuilder<List<GameRoom>>(
                    stream: _roomService.getPublicRooms(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t('online.lobby.searching'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                t('online.lobby.error'),
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final rooms = snapshot.data ?? [];
                      if (rooms.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, color: Colors.white.withOpacity(0.3), size: 64),
                              const SizedBox(height: 16),
                              Text(
                                t('online.lobby.noRoomsAvailable'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t('online.lobby.createRoomSuggestion'),
                                style: TextStyle(
                                  color: Colors.orange.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return _buildRoomCard(room);
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 部屋作成
              _buildSectionCard(
                title: '✨ ${t('online.lobby.createRoom')}',
                subtitle: t('online.lobby.createRoomSubtitle'),
                icon: Icons.add_circle,
                child: Column(
                  children: [
                    // 部屋名入力
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _roomNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: t('online.lobby.roomNameHint'),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          prefixIcon: const Icon(Icons.edit, color: Colors.orange),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 時間設定
                    _buildTimeLimitSelector(),

                    const SizedBox(height: 16),

                    // プライベート部屋設定
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPrivateRoom
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isPrivateRoom
                              ? Colors.orange.withOpacity(0.5)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPrivateRoom ? Icons.lock : Icons.lock_open,
                            color: _isPrivateRoom ? Colors.orange : Colors.white54,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('online.lobby.privateRoom'),
                                  style: TextStyle(
                                    color: _isPrivateRoom ? Colors.orange : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isPrivateRoom ? t('online.lobby.privateRoomEnabled') : t('online.lobby.privateRoomDisabled'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isPrivateRoom,
                            onChanged: (value) {
                              setState(() {
                                _isPrivateRoom = value;
                                if (!value) {
                                  _passwordController.clear();
                                }
                              });
                              _soundService.playButtonClick();
                            },
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                    ),

                    // パスワード入力
                    if (_isPrivateRoom) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: t('online.lobby.passwordHint'),
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                            prefixIcon: const Icon(Icons.key, color: Colors.orange),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          obscureText: true,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 作成ボタン
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF00d4ff), Color(0xFF0099ff)],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isLoading
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF00d4ff).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    t('online.lobby.createButton'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.deepOrange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline, color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('online.lobby.infoTitle'),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('online.lobby.infoDescription'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(GameRoom room) {
    final timeLimit = room.gameData?['timeLimit'] ?? widget.gameSettings.timeLimit;
    final playerCount = room.players.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2d4263).withOpacity(0.8),
            const Color(0xFF1a2942).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _soundService.playButtonClick();
            _joinPublicRoom(room);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ルームアイコン
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    room.isPrivate ? Icons.lock : Icons.groups,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // ルーム情報
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Colors.blue, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$playerCount/6',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.green, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  t('online.lobby.seconds', params: {'time': timeLimit}),
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 参加ボタン
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.login,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}