import 'dart:ui';
import 'dart:math';

enum BlockColor {
  red,
  blue,
  green,
  yellow,
  purple,
  orange,
  white,
  black, // 障害物：周辺で接合が起きると灰色になる
  grey,  // 障害物：周辺で結合があると消える
  rainbow; // 特殊ブロック：すべての色と結合可能

  Color get color {
    switch (this) {
      case BlockColor.red:
        return const Color(0xFFE74C3C);
      case BlockColor.blue:
        return const Color(0xFF3498DB);
      case BlockColor.green:
        return const Color(0xFF2ECC71);
      case BlockColor.yellow:
        return const Color(0xFFF1C40F);
      case BlockColor.purple:
        return const Color(0xFF9B59B6);
      case BlockColor.orange:
        return const Color(0xFFE67E22);
      case BlockColor.white:
        return const Color(0xFFFFFFFF);
      case BlockColor.black:
        return const Color(0xFF000000); // 真っ黒
      case BlockColor.grey:
        return const Color(0xFF2C3E50); // 黒っぽい色（ダークグレー）
      case BlockColor.rainbow:
        return const Color(0xFFFFFFFF); // 白（虹色は描画で特別処理）
    }
  }

  // 密度（重さ）: 値が大きいほど重い（メリハリを強化）
  double get density {
    switch (this) {
      case BlockColor.red:
        return 5.0;  // 非常に重い（鉄のイメージ）
      case BlockColor.blue:
        return 0.5;  // 非常に軽い（水のイメージ）
      case BlockColor.green:
        return 1.5;  // 軽め（木のイメージ）
      case BlockColor.yellow:
        return 1.0;  // 軽い（金のイメージ）
      case BlockColor.purple:
        return 4.0;  // 重い（石のイメージ）
      case BlockColor.orange:
        return 2.5;  // やや重い（銅のイメージ）
      case BlockColor.white:
        return 2.0;  // 普通
      case BlockColor.black:
        return 3.0;  // やや重い（障害物）
      case BlockColor.grey:
        return 2.0;  // 普通
      case BlockColor.rainbow:
        return 2.0;  // 普通
    }
  }

  // 反発係数（硬さ）: 値が大きいほど硬く跳ねる
  // ビリヤードモードでは現実的な値（0.5〜0.7）を使用
  double get restitution {
    switch (this) {
      case BlockColor.red:
        return 0.3;  // 硬い（あまり跳ねない）
      case BlockColor.blue:
        return 0.65;  // よく跳ねる（ビリヤードモードでは0.65程度）
      case BlockColor.green:
        return 0.6;  // 弾む（ビリヤードモードでは0.6程度）
      case BlockColor.yellow:
        return 0.5;  // 普通
      case BlockColor.purple:
        return 0.4;  // やや硬い
      case BlockColor.orange:
        return 0.55;  // やや弾む
      case BlockColor.white:
        return 0.55;  // 普通
      case BlockColor.black:
        return 0.0;  // 全く跳ねない（障害物）
      case BlockColor.grey:
        return 0.0;  // 全く跳ねない（障害物）
      case BlockColor.rainbow:
        return 0.6;  // よく弾む（特殊ボール）
    }
  }

  // 摩擦係数: 値が大きいほど滑りにくい
  double get friction {
    switch (this) {
      case BlockColor.red:
        return 0.6;  // 滑りにくい
      case BlockColor.blue:
        return 0.2;  // 滑りやすい（氷のイメージ）
      case BlockColor.green:
        return 0.5;  // 普通
      case BlockColor.yellow:
        return 0.3;  // やや滑りやすい
      case BlockColor.purple:
        return 0.5;  // 普通
      case BlockColor.orange:
        return 0.4;  // やや滑りやすい
      case BlockColor.white:
        return 0.4;  // 普通
      case BlockColor.black:
        return 0.5;  // やや滑りにくい（障害物）
      case BlockColor.grey:
        return 0.4;  // 普通
      case BlockColor.rainbow:
        return 0.3;  // 滑りやすい（特殊ボール）
    }
  }

  // 重力スケール: 値が大きいほど速く落下
  double get gravityScale {
    switch (this) {
      case BlockColor.red:
        return 2.5;  // 非常に速く落下
      case BlockColor.blue:
        return 0.5;  // ゆっくり落下
      case BlockColor.green:
        return 0.8;  // やや遅め
      case BlockColor.yellow:
        return 0.7;  // 遅め
      case BlockColor.purple:
        return 2.0;  // 速く落下
      case BlockColor.orange:
        return 1.3;  // やや速め
      case BlockColor.white:
        return 1.0;  // 普通
      case BlockColor.black:
        return 1.5;  // やや速め（障害物）
      case BlockColor.grey:
        return 1.0;  // 普通
      case BlockColor.rainbow:
        return 1.0;  // 普通
    }
  }

  // レベルに応じた利用可能な色を取得（白を含む、灰色は除外）
  static List<BlockColor> getAvailableColors(int level) {
    if (level == 1) {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow, BlockColor.white];
    } else if (level == 2) {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow, BlockColor.purple, BlockColor.white];
    } else {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow, BlockColor.purple, BlockColor.orange, BlockColor.white];
    }
  }

  // ルーレット用の全色（白とグレーはセグ専用色）
  static List<BlockColor> getRouletteColors() {
    return [
      BlockColor.red,
      BlockColor.blue,
      BlockColor.green,
      BlockColor.yellow,
      BlockColor.purple,
      BlockColor.orange,
      BlockColor.white,   // セグ専用（落下ボールには使用しない）
      BlockColor.grey,    // セグ専用（落下ボールには使用しない）
    ];
  }

  static BlockColor randomFromList(List<BlockColor> colors) {
    final random = Random();
    return colors[random.nextInt(colors.length)];
  }

  bool canMergeWith(BlockColor other) {
    // 虹色はすべての色と結合可能
    if (this == BlockColor.rainbow || other == BlockColor.rainbow) {
      return true;
    }
    return this == other;
  }
}
