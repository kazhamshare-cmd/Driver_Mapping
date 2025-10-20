import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/ad_service.dart';
import '../services/sound_service.dart';
import 'solo_mode_select_screen.dart';
import 'online_mode_menu_screen.dart';
import 'game_rules_screen.dart';
import 'ranking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    // BGMを開始（100%ボリューム）
    SoundService().playBgmFull();
  }

  void _loadBannerAd() {
    _bannerAd = AdService().createBannerAd();
    _bannerAd!.load().then((_) {
      setState(() {
        _isBannerAdLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // BGM切り替えボタン
          IconButton(
            icon: Icon(
              SoundService().bgmEnabled ? Icons.music_note : Icons.music_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                SoundService().toggleBgm();
              });
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // タイトル画像
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Image.asset(
                            'assets/images/title.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 50),

                        // ソロモードボタン
                        _MenuButton(
                          title: 'ソロモード',
                          subtitle: 'じっくり遊ぶ',
                          icon: Icons.person,
                          color: Colors.blue,
                          onPressed: () {
                            SoundService().playClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SoloModeSelectScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // オンラインモードボタン
                        _MenuButton(
                          title: 'オンラインモード',
                          subtitle: 'みんなで楽しむ',
                          icon: Icons.people,
                          color: Colors.orange,
                          onPressed: () {
                            SoundService().playClick();

                            // Firebaseが初期化されているか確認
                            try {
                              Firebase.app();
                              // Firebase初期化済み - オンラインモード画面へ
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const OnlineModeMenuScreen(),
                                ),
                              );
                            } catch (e) {
                              // Firebase未初期化 - エラーメッセージ表示
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Firebase未設定'),
                                  content: const Text(
                                    'オンラインモードを使用するには、Firebaseプロジェクトの設定が必要です。\n\n'
                                    'SETUP_GUIDE.mdの手順に従って、Firebaseの設定を完了してください。\n\n'
                                    'ソロモードは設定なしでお楽しみいただけます。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // ルール説明ボタン
                        _MenuButton(
                          title: 'ルール説明',
                          subtitle: '遊び方を確認',
                          icon: Icons.help_outline,
                          color: Colors.green,
                          onPressed: () {
                            SoundService().playClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GameRulesScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // ランキングボタン
                        _MenuButton(
                          title: 'ランキング',
                          subtitle: 'あなたのベスト記録',
                          icon: Icons.emoji_events,
                          color: Colors.amber,
                          onPressed: () {
                            SoundService().playClick();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RankingScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),

                        // 会社情報
                        Text(
                          '株式会社ビーク',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Developed by KAZUYUKI IKUSHIMA',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // バナー広告
              if (_isBannerAdLoaded && _bannerAd != null)
                Container(
                  alignment: Alignment.center,
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, 6),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
