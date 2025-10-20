import 'package:flutter/material.dart';
import '../services/sound_service.dart';

class GameRulesScreen extends StatefulWidget {
  const GameRulesScreen({super.key});

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ゲームのルール',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // BGM切り替えボタン
          IconButton(
            icon: Icon(
              SoundService().bgmEnabled ? Icons.music_note : Icons.music_off,
            ),
            onPressed: () {
              setState(() {
                SoundService().toggleBgm();
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル
            const Center(
              child: Text(
                '鏡文字の逆読み',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'ONLINE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 基本ルール
            _SectionTitle(title: '基本ルール'),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.flip,
              title: '鏡文字を読もう',
              description: '表示された鏡文字を正しく読んで、文字を並べて答えを作ります。',
            ),
            const SizedBox(height: 24),

            // 操作方法
            _SectionTitle(title: '操作方法'),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.touch_app,
              title: 'タップで削除',
              description: '回答エリアに配置した文字をタップすると、その文字を削除できます。',
            ),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.swap_horiz,
              title: 'スワイプで入れ替え',
              description: '回答エリア内で文字をドラッグ&ドロップすると、文字を入れ替えられます。',
            ),
            const SizedBox(height: 24),

            // ひらがなの例
            _SectionTitle(title: 'ひらがなの例'),
            const SizedBox(height: 12),
            _ExampleCard(
              text: 'さんま',
              answer: 'まんさ',
              isKanji: false,
            ),
            const SizedBox(height: 24),

            // 漢字の例
            _SectionTitle(title: '漢字の例'),
            const SizedBox(height: 12),
            _ExampleCard(
              text: '図書',
              answer: 'ょしと',
              isKanji: true,
            ),
            const SizedBox(height: 32),

            // モード説明
            _SectionTitle(title: 'ゲームモード'),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.person,
              title: 'ソロモード - リラックス',
              description: '時間制限なし。じっくり考えて遊べます。',
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.timer,
              title: 'ソロモード - タイムアタック',
              description: '30秒以内に答えを出そう！スリリングなゲームプレイ。',
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _RuleCard(
              icon: Icons.people,
              title: 'オンラインモード',
              description: '他のプレイヤーとリアルタイムで対戦！',
              color: Colors.green,
            ),
            const SizedBox(height: 32),

            // 閉じるボタン
            Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Color.fromARGB(255, 94, 53, 177)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    '閉じる',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.deepPurple,
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? color;

  const _RuleCard({
    required this.icon,
    required this.title,
    required this.description,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Colors.deepPurple;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardColor,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 32,
            color: cardColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final String text;
  final String answer;
  final bool isKanji;

  const _ExampleCard({
    required this.text,
    required this.answer,
    required this.isKanji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurple,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // 鏡文字
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  '鏡文字',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Transform.scale(
                  scaleX: -1,
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 矢印
          const Icon(
            Icons.arrow_downward,
            size: 32,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 16),

          // 正解
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  '正解',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  answer,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),

          if (isKanji) ...[
            const SizedBox(height: 12),
            Text(
              '※漢字は部首や構成要素が\n分解されて表示されます',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
