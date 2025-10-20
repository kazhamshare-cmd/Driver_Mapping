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
  grey,
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
      case BlockColor.grey:
        return const Color(0xFF95A5A6);
      case BlockColor.rainbow:
        return const Color(0xFFFFFFFF); // 白（虹色は描画で特別処理）
    }
  }

  // レベルに応じた利用可能な色を取得
  static List<BlockColor> getAvailableColors(int level) {
    if (level == 1) {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow];
    } else if (level == 2) {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow, BlockColor.purple];
    } else {
      return [BlockColor.red, BlockColor.blue, BlockColor.green, BlockColor.yellow, BlockColor.purple, BlockColor.orange];
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
