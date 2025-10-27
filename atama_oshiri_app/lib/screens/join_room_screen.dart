import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import 'online_game_screen.dart';

/// ルーム参加画面
class JoinRoomScreen extends StatefulWidget {
  final Room room;

  const JoinRoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final RoomService _roomService = RoomService.instance;
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _playerNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = JoinRoomRequest(
        roomId: widget.room.id,
        playerName: _playerNameController.text.trim(),
        password: widget.room.isPasswordProtected
            ? _passwordController.text.trim()
            : null,
      );

      final updatedRoom = await _roomService.joinRoom(request);

      if (mounted) {
        // 参加したプレイヤーのIDを取得
        final joinedPlayerId = updatedRoom.players
            .firstWhere((p) => p.name == _playerNameController.text.trim())
            .id;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(
              room: updatedRoom,
              currentPlayerId: joinedPlayerId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'ルーム参加に失敗しました';
        
        if (e.toString().contains('ルームが見つかりません') || 
            e.toString().contains('Room not found')) {
          errorMessage = 'ルームが存在しません。\nルームが削除された可能性があります。';
        } else if (e.toString().contains('プレイヤー数が上限に達しています')) {
          errorMessage = 'ルームが満員です。\n他のルームを選択してください。';
        } else if (e.toString().contains('パスワードが間違っています')) {
          errorMessage = 'パスワードが間違っています。\n正しいパスワードを入力してください。';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ヘッダー
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'ルーム参加',
                          style: TextStyle(
                            fontSize: 36,
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
                        const Text(
                          'ルームに参加しましょう',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // ルーム情報
                  _buildRoomInfoCard(),
                  
                  const SizedBox(height: 30),
                  
                  // プレイヤー名入力
                  _buildInputCard(
                    title: 'あなたの名前',
                    child: TextFormField(
                      controller: _playerNameController,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '例: プレイヤー2',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '名前を入力してください';
                        }
                        if (value.trim().length < 2) {
                          return '名前は2文字以上で入力してください';
                        }
                        // 既存プレイヤーとの重複チェック
                        final existingNames = widget.room.players
                            .map((p) => p.name.toLowerCase())
                            .toList();
                        if (existingNames.contains(value.trim().toLowerCase())) {
                          return 'その名前は既に使用されています';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  // パスワード入力（条件付き表示）
                  if (widget.room.isPasswordProtected) ...[
                    const SizedBox(height: 20),
                    _buildInputCard(
                      title: 'パスワード',
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'パスワードを入力',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'パスワードを入力してください';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // 参加ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _joinRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ルームに参加',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 戻るボタン
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
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
              Expanded(
                child: Text(
                  widget.room.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              if (widget.room.isPasswordProtected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 パスワード保護',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'ホスト: ${widget.room.hostName}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              const Icon(
                Icons.people,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.room.playerCount}/${widget.room.maxPlayers}人',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.room.canJoin ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.room.canJoin ? '参加可能' : '満員',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          if (widget.room.players.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '参加者:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.room.players.map((player) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    player.isHost ? Icons.star : Icons.person,
                    color: player.isHost ? Colors.amber : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    player.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: player.isHost ? Colors.amber : Colors.grey,
                      fontWeight: player.isHost ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
