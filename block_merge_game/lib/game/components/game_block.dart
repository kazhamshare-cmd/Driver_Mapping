import 'dart:ui';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' show RadialGradient, Alignment;
import '../utils/block_color.dart';

class GameBlock extends BodyComponent {
  final BlockColor blockColor;
  final int gridX;
  final int gridY;
  final double blockSize;
  final Vector2 gridOffset;
  final BodyType bodyType;
  bool isMovable = false;
  String? groupId; // グループID（合体したブロック用）

  // アニメーション用
  bool isBlinking = false;
  double blinkTimer = 0;
  bool isVisible = true;

  GameBlock({
    required this.blockColor,
    required this.gridX,
    required this.gridY,
    required this.gridOffset,
    this.blockSize = 30.0,
    this.groupId,
    this.bodyType = BodyType.dynamic,
  });

  @override
  void update(double dt) {
    super.update(dt);

    if (isBlinking) {
      blinkTimer += dt;
      // 0.3秒ごとに点滅（ゆっくり）
      if (blinkTimer >= 0.3) {
        isVisible = !isVisible;
        blinkTimer = 0;
      }
    }
  }

  @override
  Body createBody() {
    // 円形（ボール）の形状に変更
    // 半径を少し小さくして重なりを防ぐ
    final shape = CircleShape()..radius = (blockSize / 2) * 0.95;

    final fixtureDef = FixtureDef(
      shape,
      restitution: 0.6, // 跳ね返りを強くする（2倍）
      density: 2.0,     // 密度を上げて安定させる
      friction: 0.4,    // 摩擦を少し減らす
    );

    final bodyDef = BodyDef(
      position: Vector2(
        gridOffset.x + gridX * blockSize + blockSize / 2,
        gridOffset.y + gridY * blockSize + blockSize / 2,
      ),
      type: bodyType,
      linearDamping: 0.2,  // 空気抵抗を減らす（バウンスしやすく）
      angularDamping: 0.8, // 回転を抑える
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 点滅中で非表示の場合は描画しない
    if (isBlinking && !isVisible) {
      return;
    }

    final radius = blockSize / 2;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: blockSize,
      height: blockSize,
    );

    // 虹色ボールの場合はグラデーション
    if (blockColor == BlockColor.rainbow) {
      final gradient = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF), // 中心は白
          const Color(0xFFE74C3C), // Red
          const Color(0xFFF1C40F), // Yellow
          const Color(0xFF2ECC71), // Green
          const Color(0xFF3498DB), // Blue
          const Color(0xFF9B59B6), // Purple
        ],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, radius, paint);
    } else {
      // グラデーションで立体感のあるボールを描画
      final gradient = RadialGradient(
        center: const Alignment(-0.3, -0.3), // 光源の位置
        colors: [
          blockColor.color.withValues(alpha: 1.0),
          blockColor.color.withValues(alpha: 0.8),
          blockColor.color.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.6, 1.0],
      );
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, radius, paint);
    }

    // 枠線（円形）
    final borderPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius, borderPaint);

    // ハイライト（光沢）を追加
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-radius * 0.3, -radius * 0.3),
      radius * 0.3,
      highlightPaint,
    );

    // 移動可能な場合は白い点を表示（点滅していても常に表示）
    if (isMovable && isVisible) {
      final dotPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, 4, dotPaint);
    }
  }

  void setPosition(int x, int y) {
    body.setTransform(
      Vector2(
        gridOffset.x + x * blockSize + blockSize / 2,
        gridOffset.y + y * blockSize + blockSize / 2,
      ),
      0,
    );
  }
}
