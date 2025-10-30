import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';
import '../services/game_center_service.dart';
import '../models/room_models.dart' as room_models;

/// 開発者向けGameCenter設定画面
class DevGameCenterScreen extends StatefulWidget {
  const DevGameCenterScreen({super.key});

  @override
  State<DevGameCenterScreen> createState() => _DevGameCenterScreenState();
}

class _DevGameCenterScreenState extends State<DevGameCenterScreen> {
  final GameCenterService _gameCenter = GameCenterService();
  bool _isLoading = false;
  String _statusMessage = '';
  room_models.Player? _playerInfo;

  // テスト用のリーダーボードID
  final String _testLeaderboardId = 'com.atama_oshiri.high_score';
  
  // テスト用のアチーブメントID
  final Map<String, String> _achievements = {
    'first_game': 'com.atamaoshiri.first_game',
    'score_100': 'com.atamaoshiri.score_100',
    'score_500': 'com.atamaoshiri.score_500',
    'score_1000': 'com.atamaoshiri.score_1000',
    'perfect_game': 'com.atamaoshiri.perfect_game',
  };

  @override
  void initState() {
    super.initState();
    _loadPlayerInfo();
  }

  Future<void> _loadPlayerInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final player = await _gameCenter.getPlayerInfo();
      setState(() {
        _playerInfo = player;
        _statusMessage = player != null ? 'プレイヤー情報取得成功' : 'プレイヤー情報取得失敗';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'サインイン中...';
    });

    final success = await _gameCenter.signIn();
    setState(() {
      _statusMessage = success ? 'サインイン成功' : 'サインイン失敗';
      _isLoading = false;
    });

    if (success) {
      _loadPlayerInfo();
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'サインアウト中...';
    });

    await _gameCenter.signOut();
    setState(() {
      _statusMessage = 'サインアウト完了';
      _playerInfo = null;
      _isLoading = false;
    });
  }

  Future<void> _submitTestScore() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'テストスコア送信中...';
    });

    final success = await _gameCenter.submitScore(
      leaderboardId: _testLeaderboardId,
      score: 1000,
    );

    setState(() {
      if (success) {
        _statusMessage = 'テストスコア送信成功';
      } else {
        _statusMessage = 'テストスコア送信失敗\n（Leaderboardが未配信の可能性があります）';
      }
      _isLoading = false;
    });
  }

  Future<void> _unlockAchievement(String key) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'アチーブメント解除中...';
    });

    final success = await _gameCenter.unlockAchievement(
      achievementId: _achievements[key]!,
    );

    setState(() {
      _statusMessage = success ? 'アチーブメント解除成功: $key' : 'アチーブメント解除失敗: $key';
      _isLoading = false;
    });
  }

  Future<void> _showLeaderboard() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'リーダーボード表示中...';
    });

    try {
      await _gameCenter.showLeaderboard(leaderboardId: _testLeaderboardId);
      setState(() {
        _statusMessage = 'リーダーボード表示完了';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'リーダーボード表示失敗\n（Leaderboardが未配信の可能性があります）';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAchievements() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'アチーブメント表示中...';
    });

    await _gameCenter.showAchievements();
    
    setState(() {
      _statusMessage = 'アチーブメント表示完了';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GameCenter 開発者設定'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ステータス表示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ステータス',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage),
                    if (_playerInfo != null) ...[
                      const SizedBox(height: 8),
                      Text('プレイヤーID: ${_playerInfo!.id}'),
                      Text('表示名: ${_playerInfo!.name}'),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 認証ボタン
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('サインイン'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('サインアウト'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // リーダーボードテスト
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'リーダーボードテスト',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('ID: $_testLeaderboardId'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submitTestScore,
                            icon: const Icon(Icons.upload),
                            label: const Text('テストスコア送信'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showLeaderboard,
                            icon: const Icon(Icons.leaderboard),
                            label: const Text('リーダーボード表示'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // アチーブメントテスト
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'アチーブメントテスト',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._achievements.entries.map((entry) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.key),
                                  Text(
                                    entry.value,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isLoading ? null : () => _unlockAchievement(entry.key),
                              child: const Text('解除'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showAchievements,
                        icon: const Icon(Icons.emoji_events),
                        label: const Text('アチーブメント表示'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_isLoading) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
