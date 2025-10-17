import 'package:flutter/material.dart';
import 'dart:async';
import '../services/online_service.dart';
import '../models/online_room.dart';
import '../services/sound_service.dart';
import '../services/i18n_service.dart';
import 'online_relay_game_screen.dart';

class OnlineRoomScreen extends StatefulWidget {
  final String roomId;
  final VoidCallback onBackToLobby;

  const OnlineRoomScreen({
    super.key,
    required this.roomId,
    required this.onBackToLobby,
  });

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  final OnlineService _onlineService = OnlineService();
  final SoundService _soundService = SoundService();

  StreamSubscription<OnlineRoom>? _roomSubscription;
  OnlineRoom? _currentRoom;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _watchRoom();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _leaveRoom();
    super.dispose();
  }

  void _watchRoom() {
    _roomSubscription = _onlineService.watchRoom(widget.roomId).listen(
      (room) {
        if (mounted) {
          setState(() {
            _currentRoom = room;
          });

          // ゲームが開始されたら、ゲーム画面に遷移
          if (room.status == RoomStatus.playing && !_isLoading) {
            _navigateToGame();
          }
        }
      },
      onError: (error) {
        print('Room watch error: $error');
        if (mounted) {
          _showErrorDialog('ルームの監視中にエラーが発生しました: $error');
        }
      },
    );
  }

  Future<void> _startGame() async {
    if (_currentRoom == null || _isLoading) return;

    // ホストのみゲーム開始可能
    final currentPlayer = _currentRoom!.players.where((p) => p.id == _onlineService.currentPlayerId).firstOrNull;
    if (currentPlayer == null || !currentPlayer.isHost) {
      _showErrorDialog('ホストのみゲームを開始できます');
      return;
    }

    if (_currentRoom!.players.length < 2) {
      _showErrorDialog('ゲームを開始するには最低2人のプレイヤーが必要です');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _onlineService.startGame(widget.roomId);
      _soundService.playButtonClick();
    } catch (e) {
      _showErrorDialog('ゲーム開始に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OnlineRelayGameScreen(
          room: _currentRoom!,
          onBackToLobby: widget.onBackToLobby,
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    try {
      await _onlineService.leaveRoom(widget.roomId);
    } catch (e) {
      print('Leave room error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a3e),
        title: const Text('エラー', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  String t(String key, {Map<String, dynamic>? params}) {
    return I18nService.translate(key, params: params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Text(
          _currentRoom?.name ?? 'ルーム',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16213e),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _soundService.playButtonClick();
            widget.onBackToLobby();
          },
        ),
      ),
      body: _currentRoom == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ルーム情報カード
                  _buildRoomInfoCard(),

                  const SizedBox(height: 20),

                  // プレイヤー一覧
                  _buildPlayersCard(),

                  const SizedBox(height: 20),

                  // ゲーム設定情報
                  _buildGameSettingsCard(),

                  const SizedBox(height: 30),

                  // アクションボタン
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _currentRoom!.type == RoomType.private ? Icons.lock : Icons.public,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _currentRoom!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ルームID: ${_currentRoom!.id.substring(0, 8).toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
          if (_currentRoom!.type == RoomType.private)
            Text(
              'パスワード保護',
              style: TextStyle(
                color: Colors.orange.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'プレイヤー (${_currentRoom!.players.length}人)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentRoom!.players.map((player) {
              final isCurrentPlayer = player.id == _onlineService.currentPlayerId;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentPlayer
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentPlayer
                        ? Colors.orange
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (player.isHost)
                      const Icon(Icons.star, color: Colors.yellow, size: 16),
                    if (player.isHost) const SizedBox(width: 4),
                    Text(
                      player.name,
                      style: TextStyle(
                        color: isCurrentPlayer ? Colors.orange : Colors.white,
                        fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'ゲーム設定',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingRow('難易度', _currentRoom!.gameSettings.selectedDifficulty.name),
          _buildSettingRow('制限時間', '${_currentRoom!.gameSettings.selectedDifficulty.timeLimit}ms'),
          _buildSettingRow('勝利条件', '${_currentRoom!.gameSettings.maxWins}勝'),
          _buildSettingRow('ゲーム形式', 'リレー形式（無制限人数）'),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final currentPlayer = _currentRoom!.players.where((p) => p.id == _onlineService.currentPlayerId).firstOrNull;
    final isHost = currentPlayer?.isHost ?? false;

    return Column(
      children: [
        if (isHost && _currentRoom!.status == RoomStatus.waiting)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'ゲーム開始',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

        if (!isHost && _currentRoom!.status == RoomStatus.waiting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Text(
              'ホストがゲームを開始するまでお待ちください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.orange,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _soundService.playButtonClick();
              widget.onBackToLobby();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
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
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}