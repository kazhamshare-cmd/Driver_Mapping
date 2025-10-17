import 'package:flutter/material.dart';

/// ゲームルール説明画面
class GameRulesScreen extends StatelessWidget {
  const GameRulesScreen({super.key});

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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ヘッダー
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Text(
                        '遊び方ルール',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 基本ルール
                  _RuleSection(
                    title: '🎯 基本ルール',
                    children: [
                      _RuleItem(
                        icon: '📝',
                        text: 'お題の頭文字と尻文字で始まり・終わる単語を答える',
                      ),
                      _RuleItem(
                        icon: '⏰',
                        text: '制限時間内に音声で回答する',
                      ),
                      _RuleItem(
                        icon: '📚',
                        text: '辞書に存在する単語のみ有効',
                      ),
                      _RuleItem(
                        icon: '🚫',
                        text: '一度使った単語は使用不可',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 文字の組み合わせルール
                  _RuleSection(
                    title: '🔤 文字の組み合わせルール',
                    children: [
                      _RuleItem(
                        icon: '🔗',
                        text: '濁音・半濁音は別の文字として扱われる',
                        examples: ['「は」「ば」「ぱ」は全て別の文字'],
                      ),
                      _RuleItem(
                        icon: '➖',
                        text: '長音符「ー」で終わる場合は前の文字で判定',
                        examples: ['「しちゅー」→「ゆ」で判定'],
                      ),
                      _RuleItem(
                        icon: '🔤',
                        text: '拗音・小文字は大文字に変換',
                        examples: ['「ゃ」→「や」、「っ」→「つ」'],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 具体例
                  _RuleSection(
                    title: '💡 具体例',
                    children: [
                      _ExampleCard(
                        title: 'お題：「は」で始まり「び」で終わる',
                        examples: [
                          'はいび',
                          'はくび',
                          'はなび',
                          'はなび（「は」で始まり「び」で終わる）',
                        ],
                      ),
                      _ExampleCard(
                        title: 'お題：「し」で始まり「ゆ」で終わる',
                        examples: [
                          'しちゅー（「ー」の前の「ゆ」で判定）',
                          'しゆう',
                          'しゆうき',
                        ],
                      ),
                      _ExampleCard(
                        title: 'お題：「お」で始まり「あ」で終わる',
                        examples: [
                          'おもちゃ（「あ」で終わる）',
                          'おかあさん',
                          'おはな',
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 数字に関するルール
                  _RuleSection(
                    title: '🔢 数字に関するルール',
                    children: [
                      _RuleItem(
                        icon: '🚫',
                        text: '数字を含む単語は基本的に使用不可',
                        examples: ['「3位」「3月」「三重の塔」「3歳」「三角形」「3代目」など'],
                      ),
                      _RuleItem(
                        icon: '✅',
                        text: '熟語や固有名詞は使用可能',
                        examples: ['「三位一体」「3代目ジェイソール」など'],
                      ),
                      _RuleItem(
                        icon: '💡',
                        text: '数字が含まれていても意味のある熟語は有効',
                        examples: ['「三日月」「四角形」「五重塔」など'],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 得点システム
                  _RuleSection(
                    title: '🏆 得点システム',
                    children: [
                      _RuleItem(
                        icon: '⭐',
                        text: '頭文字と尻文字を除いた文字数が得点',
                      ),
                      _RuleItem(
                        icon: '🎯',
                        text: 'より長い単語ほど高得点',
                        examples: ['「はなび」= 1点、「はなむすび」= 5点'],
                      ),
                      _RuleItem(
                        icon: '⚡',
                        text: '素早い回答でボーナス得点',
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ゲームモード
                  _RuleSection(
                    title: '🎮 ゲームモード',
                    children: [
                      _RuleItem(
                        icon: '👤',
                        text: 'ソロプレイ：一人でお題に挑戦',
                      ),
                      _RuleItem(
                        icon: '👥',
                        text: 'オフライン対戦：同じ端末で対戦',
                      ),
                      _RuleItem(
                        icon: '🌐',
                        text: 'オンライン対戦：ルームで対戦',
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ルールセクション
class _RuleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _RuleSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// ルール項目
class _RuleItem extends StatelessWidget {
  final String icon;
  final String text;
  final List<String>? examples;

  const _RuleItem({
    required this.icon,
    required this.text,
    this.examples,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (examples != null) ...[
                  const SizedBox(height: 4),
                  ...examples!.map((example) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      '• $example',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 具体例カード
class _ExampleCard extends StatelessWidget {
  final String title;
  final List<String> examples;

  const _ExampleCard({
    required this.title,
    required this.examples,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...examples.map((example) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              '• $example',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
          )),
        ],
      ),
    );
  }
}
