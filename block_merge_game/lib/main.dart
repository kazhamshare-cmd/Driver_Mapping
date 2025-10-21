import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/block_merge_game.dart';

enum GameMode {
  gravity,   // 重力モード（既存）
  billiard,  // ビリヤードモード（新規）
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Merge Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// スプラッシュ画面（フェードイン効果付き）
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // フェードインアニメーション設定
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // アニメーション開始
    _controller.forward();

    // 2.5秒後にメニュー画面に遷移
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MenuScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e), // ダークブルー背景
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '株式会社ビーク',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900, // 太い文字
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'b19.co.jp',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w900, // 太い文字
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// メインメニュー画面
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e), // ダークブルー背景
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ゲームタイトル
            const Text(
              'Block Merge Game',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 60),

            // 重力モードボタン
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const GamePage(mode: GameMode.gravity)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71), // 緑色
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                '重力モード',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ビリヤードモードボタン
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const GamePage(mode: GameMode.billiard)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6), // 紫色
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'ビリヤードモード',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 遊び方ボタン
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HowToPlayScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB), // 青色
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                '遊び方',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 遊び方画面
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213e),
        title: const Text(
          '遊び方',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '基本ルール',
              '・同じ色のボールを3個以上つなげると消えます\n'
              '・上部のボールをドラッグして配置します\n'
              '・物理演算でボールが落下・跳ね返ります',
            ),
            const SizedBox(height: 20),
            _buildSection(
              'ボールの特徴',
              '🔴 赤：非常に重い（鉄玉）- 速く落ちるが跳ねない\n'
              '🔵 青：非常に軽い（水）- ゆっくり落ちてよく跳ねる\n'
              '🟢 緑：軽め（木）- 非常に弾む（ゴムボール）\n'
              '🟡 黄色：軽い（金）- 星のような光線パターン\n'
              '🟣 紫：重い（石）- 3個で2倍、2倍×3個で4倍に成長。4倍は虹色でしか消せない\n'
              '🟠 オレンジ：やや重い（銅）- チェック柄\n'
              '⚪ 白：1.2倍の大きさ - シンプルなデザイン\n'
              '⚫ 黒：障害物（1/50で出現）- 周辺で接合が起きると灰色に変化\n'
              '⚫ 灰色：障害物（1/20で出現）- 周辺で結合が1回起きると削除される\n'
              '🌈 虹色：特殊ボール（1/200で出現）- どの色にも接続可能、2個以上で消える。4倍紫を消せる',
            ),
            const SizedBox(height: 20),
            _buildSection(
              'コンボシステム',
              '・3秒以内に連続消去するとコンボ継続\n'
              '・コンボ倍率に応じてスコアが倍増',
            ),
            const SizedBox(height: 20),
            _buildSection(
              '特殊ボール',
              '・5個以上同時消去で虹色ボール出現\n'
              '・虹色ボールは万能カード：どの色とも接続し、2個以上で消える',
            ),
            const SizedBox(height: 20),
            _buildSection(
              'ゲームオーバー',
              '・ボールがグリッドの上端を超えると終了',
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  '戻る',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class GamePage extends StatelessWidget {
  final GameMode mode;

  const GamePage({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ゲーム画面（モードに応じて切り替え）
          GameWidget(
            game: mode == GameMode.gravity
              ? BlockMergeGame()
              : BlockMergeGame.billiardMode(), // ビリヤードモード用のコンストラクタ
          ),

          // メニューボタン（左上）
          Positioned(
            top: 50,
            left: 10,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // メニュー画面に戻る
                },
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF000000).withOpacity(0.5),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ),

          // 広告エリア（下部）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              color: const Color(0xFF000000).withOpacity(0.8),
              child: const Center(
                child: Text(
                  '広告エリア',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
