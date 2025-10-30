import 'package:flutter/material.dart';
import '../models/room_models.dart';
import '../services/room_service.dart';
import 'online_game_screen.dart';

/// ルーム作成画面
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final RoomService _roomService = RoomService.instance;
  final _formKey = GlobalKey<FormState>();
  
  // フォームコントローラー
  final _roomNameController = TextEditingController();
  final _hostNameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // 状態
  bool _isPasswordProtected = false;
  bool _isLoading = false;
  int _maxPlayers = 4;
  GameMode _gameMode = GameMode.scoreMatch; // デフォルトは点数勝負
  int _totalRounds = 5; // デフォルト5ラウンド

  @override
  void initState() {
    super.initState();
    // デフォルト値を設定
    _roomNameController.text = 'みんなで頭お尻ゲーム';
    _hostNameController.text = 'プレイヤー1';
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _hostNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🎮 [デバッグ] ルーム作成 - ゲームモード: ${_gameMode.name}');
      print('🎮 [デバッグ] ルーム作成 - ラウンド数: $_totalRounds');

      final request = CreateRoomRequest(
        roomName: _roomNameController.text.trim().isNotEmpty
            ? _roomNameController.text.trim()
            : '${_hostNameController.text.trim()}のルーム',
        hostName: _hostNameController.text.trim(),
        password: _isPasswordProtected ? _passwordController.text.trim() : null,
        maxPlayers: _maxPlayers,
        gameMode: _gameMode,
        totalRounds: _totalRounds,
      );

      print('🎮 [デバッグ] リクエスト - ゲームモード: ${request.gameMode.name}');
      print('🎮 [デバッグ] リクエスト - ラウンド数: ${request.totalRounds}');

      final room = await _roomService.createRoom(request);

      print('🎮 [デバッグ] 作成されたルーム - ゲームモード: ${room.gameMode.name}');
      print('🎮 [デバッグ] 作成されたルーム - ラウンド数: ${room.totalRounds}');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(
              room: room,
              currentPlayerId: room.players.first.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ルーム作成に失敗しました: $e'),
            backgroundColor: Colors.red,
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
                          'ルーム作成',
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
                          '新しいルームを作成しましょう',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // ルーム名とホスト名（横並び）
                  _buildInputCard(
                    title: 'ルーム設定',
                    child: Column(
                      children: [
                        // ルーム名
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'ルーム名',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _roomNameController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: '例: 友達と対戦！',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                validator: (value) {
                                  // ルーム名が空でもOK（デフォルト名を設定）
                                  if (value != null && value.trim().isNotEmpty && value.trim().length < 2) {
                                    return 'ルーム名は2文字以上で入力してください';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ホスト名
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'あなたの名前',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _hostNameController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: '例: プレイヤー1',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '名前を入力してください';
                                  }
                                  if (value.trim().length < 2) {
                                    return '名前は2文字以上で入力してください';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 最大プレイヤー数
                  _buildInputCard(
                    title: '最大プレイヤー数',
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _maxPlayers.toDouble(),
                            min: 2,
                            max: 8,
                            divisions: 6,
                            label: '$_maxPlayers人',
                            onChanged: (value) {
                              setState(() {
                                _maxPlayers = value.round();
                              });
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_maxPlayers人',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // ゲームモード選択
                  _buildInputCard(
                    title: 'ゲームモード',
                    child: Column(
                      children: [
                        _buildGameModeOption(
                          mode: GameMode.suddenDeath,
                          title: 'サドンデス',
                          description: '失敗したら即脱落！最後の1人まで生き残り勝負',
                          icon: Icons.bolt,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _buildGameModeOption(
                          mode: GameMode.scoreMatch,
                          title: '点数勝負',
                          description: '規定ラウンド終了後に点数で勝敗を決定',
                          icon: Icons.emoji_events,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  // ラウンド数（点数勝負モードの時のみ表示）
                  if (_gameMode == GameMode.scoreMatch) ...[
                    const SizedBox(height: 20),
                    _buildInputCard(
                      title: 'ラウンド数',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _totalRounds.toDouble(),
                                  min: 3,
                                  max: 10,
                                  divisions: 7,
                                  label: '$_totalRoundsラウンド',
                                  onChanged: (value) {
                                    setState(() {
                                      _totalRounds = value.round();
                                    });
                                  },
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_totalRoundsラウンド',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '各プレイヤーが$_totalRounds回ずつ挑戦します',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // パスワード保護
                  _buildInputCard(
                    title: 'パスワード保護',
                    child: Row(
                      children: [
                        Switch(
                          value: _isPasswordProtected,
                          onChanged: (value) {
                            setState(() {
                              _isPasswordProtected = value;
                              if (!value) {
                                _passwordController.clear();
                              }
                            });
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isPasswordProtected
                                ? 'パスワードを設定してルームを保護'
                                : '誰でも参加できるオープンルーム',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // パスワード入力（条件付き表示）
                  if (_isPasswordProtected) ...[
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
                          if (_isPasswordProtected) {
                            if (value == null || value.trim().isEmpty) {
                              return 'パスワードを入力してください';
                            }
                            if (value.trim().length < 4) {
                              return 'パスワードは4文字以上で入力してください';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // 作成ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                              'ルーム作成',
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

  Widget _buildGameModeOption({
    required GameMode mode,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _gameMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _gameMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 32,
              ),
          ],
        ),
      ),
    );
  }
}
