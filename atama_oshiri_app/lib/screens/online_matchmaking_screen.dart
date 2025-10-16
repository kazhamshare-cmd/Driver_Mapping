import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/online_match_service.dart';
import 'online_game_screen.dart';

/// オンラインマッチング画面
class OnlineMatchmakingScreen extends StatefulWidget {
  const OnlineMatchmakingScreen({super.key});

  @override
  State<OnlineMatchmakingScreen> createState() => _OnlineMatchmakingScreenState();
}

class _OnlineMatchmakingScreenState extends State<OnlineMatchmakingScreen> {
  final OnlineMatchService _matchService = OnlineMatchService.instance;
  bool _isSearching = false;
  String? _matchId;
  final TextEditingController _friendCodeController = TextEditingController();

  @override
  void dispose() {
    _friendCodeController.dispose();
    if (_matchId != null) {
      _matchService.cancelMatch(_matchId!);
    }
    super.dispose();
  }

  Future<void> _startRandomMatching() async {
    setState(() {
      _isSearching = true;
    });

    final matchId = await _matchService.startMatchmaking();

    if (matchId == null) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マッチングに失敗しました')),
        );
      }
      return;
    }

    setState(() {
      _matchId = matchId;
    });

    // マッチ監視
    _matchService.watchMatch(matchId).listen((match) {
      if (!mounted) return;

      if (match.status == MatchStatus.ready) {
        // 対戦開始
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(matchId: matchId),
          ),
        );
      }
    });
  }

  Future<void> _createFriendMatch() async {
    final matchId = await _matchService.createFriendMatch();

    if (matchId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('マッチ作成に失敗しました')),
        );
      }
      return;
    }

    if (mounted) {
      _showFriendCodeDialog(matchId);
    }
  }

  void _showFriendCodeDialog(String matchId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('フレンドコード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('このコードを友達に共有してください'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                matchId,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: matchId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('コピーしました')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('コピー'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _matchService.cancelMatch(matchId);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    // マッチ監視
    _matchService.watchMatch(matchId).listen((match) {
      if (!mounted) return;

      if (match.status == MatchStatus.ready) {
        Navigator.pop(context); // ダイアログを閉じる
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnlineGameScreen(matchId: matchId),
          ),
        );
      }
    });
  }

  Future<void> _joinFriendMatch() async {
    final code = _friendCodeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('フレンドコードを入力してください')),
      );
      return;
    }

    final success = await _matchService.joinFriendMatch(code);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OnlineGameScreen(matchId: code),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マッチに参加できませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('オンライン対戦'),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade300,
              Colors.deepPurple.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // タイトル
                  const Icon(
                    Icons.people,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'オンライン対戦',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 48),

                  if (_isSearching) ...[
                    // マッチング中表示
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 24),
                    const Text(
                      '対戦相手を探しています...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_matchId != null) {
                          _matchService.cancelMatch(_matchId!);
                        }
                        setState(() {
                          _isSearching = false;
                          _matchId = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: const Text(
                        'キャンセル',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ] else ...[
                    // ランダムマッチング
                    _buildMenuButton(
                      title: 'ランダムマッチング',
                      subtitle: '誰かと対戦する',
                      icon: Icons.shuffle,
                      color: Colors.orange,
                      onPressed: _startRandomMatching,
                    ),
                    const SizedBox(height: 16),

                    // フレンド対戦
                    _buildMenuButton(
                      title: 'フレンド対戦を作成',
                      subtitle: 'コードを共有して対戦',
                      icon: Icons.person_add,
                      color: Colors.green,
                      onPressed: _createFriendMatch,
                    ),
                    const SizedBox(height: 32),

                    // フレンドコード入力
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'フレンドコードで参加',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _friendCodeController,
                            decoration: const InputDecoration(
                              hintText: 'フレンドコードを入力',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.vpn_key),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _joinFriendMatch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                '参加',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
