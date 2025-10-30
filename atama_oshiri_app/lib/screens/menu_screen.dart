import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'solo_start_screen.dart';
import 'offline_game_screen.dart';
import 'room_list_screen.dart';
import 'game_rules_screen.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';

/// メニュー画面 - ゲームモードを選択
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final SoundService _sound = SoundService.instance;
  final AdService _ad = AdService.instance;

  @override
  void initState() {
    super.initState();
    // メニュー画面が表示されたらBGMを再生
    _sound.playMenuBGM();
    // バナー広告を読み込み
    _ad.loadBannerAd();
  }

  @override
  void dispose() {
    // 画面から離れる時はBGMを停止
    _sound.stopMenuBGM();
    super.dispose();
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                // タイトルロゴ
                Image.asset(
                  'assets/images/title_logo.png',
                  width: MediaQuery.of(context).size.width * 0.85,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 60),

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
              // バナー広告
              if (_ad.bannerAd != null)
                Container(
                  color: Colors.black,
                  width: _ad.bannerAd!.size.width.toDouble(),
                  height: _ad.bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _ad.bannerAd!),
                ),
            ],
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
