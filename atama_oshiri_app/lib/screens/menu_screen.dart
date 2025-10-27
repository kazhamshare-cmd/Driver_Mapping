import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'solo_start_screen.dart';
import 'offline_game_screen.dart';
import 'room_list_screen.dart';
import 'game_rules_screen.dart';

/// メニュー画面 - ゲームモードを選択
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  // クラスレベルの静的変数として定義
  static DateTime? _lastBuildTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    print('🏠 MenuScreen: buildメソッドが呼ばれました - ${now.millisecondsSinceEpoch}');
    
    // 連続呼び出しを検出
    if (_lastBuildTime != null) {
      final diff = now.difference(_lastBuildTime!);
      if (diff.inMilliseconds < 100) {
        print('⚠️ MenuScreen: 連続呼び出し検出 - 間隔: ${diff.inMilliseconds}ms');
      }
    }
    _lastBuildTime = now;
    return Scaffold(
      backgroundColor: Colors.white,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                // タイトル画像
                Image.asset(
                  'assets/images/title_logo.png',
                  width: MediaQuery.of(context).size.width * 0.85,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // ソロプレイ
                _MenuButton(
                  icon: Icons.person,
                  label: 'ソロプレイ',
                  description: 'ひとりでお題に挑戦',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SoloStartScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // オフライン対戦
                _MenuButton(
                  icon: Icons.people,
                  label: 'オフライン対戦',
                  description: '同じ端末で対戦',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OfflineGameScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // オンライン対戦
                _MenuButton(
                  icon: Icons.wifi,
                  label: 'オンライン対戦',
                  description: 'ルームで対戦',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RoomListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 遊び方ルール
                _MenuButton(
                  icon: Icons.help_outline,
                  label: '遊び方ルール',
                  description: 'ゲームのルールを確認',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameRulesScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// メニューボタンウィジェット
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(24),
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
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
