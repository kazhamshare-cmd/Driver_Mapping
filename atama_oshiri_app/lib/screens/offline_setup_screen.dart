import 'package:flutter/material.dart';
import 'offline_game_screen.dart';

/// オフライン対戦セットアップ画面
class OfflineSetupScreen extends StatefulWidget {
  const OfflineSetupScreen({super.key});

  @override
  State<OfflineSetupScreen> createState() => _OfflineSetupScreenState();
}

class _OfflineSetupScreenState extends State<OfflineSetupScreen> {
  int _playerCount = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade300,
              Colors.orange.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // タイトル
                const Text(
                  'オフライン対戦',
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
                const SizedBox(height: 16),
                const Text(
                  '参加人数を選択してください',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),

                // 参加人数選択
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '参加人数',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // 人数表示とボタン
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // マイナスボタン
                          _CountButton(
                            icon: Icons.remove,
                            onPressed: _playerCount > 2 ? _decreaseCount : null,
                          ),
                          const SizedBox(width: 24),
                          
                          // 人数表示
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: Colors.orange,
                                width: 3,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$_playerCount',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // プラスボタン
                          _CountButton(
                            icon: Icons.add,
                            onPressed: _playerCount < 8 ? _increaseCount : null,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      Text(
                        '${_playerCount}人で対戦',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // スタートボタン
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfflineGameScreen(
                            playerCount: _playerCount,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'ゲームスタート',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 戻るボタン
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '戻る',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _increaseCount() {
    if (_playerCount < 8) {
      setState(() {
        _playerCount++;
      });
    }
  }

  void _decreaseCount() {
    if (_playerCount > 2) {
      setState(() {
        _playerCount--;
      });
    }
  }
}

/// カウントボタン
class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _CountButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.orange : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(28),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Icon(
            icon,
            color: onPressed != null ? Colors.white : Colors.grey.shade500,
            size: 28,
          ),
        ),
      ),
    );
  }
}
