import 'dart:ui';
import 'dart:math' show cos, sin, pi;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' show RadialGradient, Alignment, TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;
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
  int sizeMultiplier = 1; // サイズ倍率（紫の合体用：1, 2, 4）

  // 灰色ブロック用
  bool isFixed = false; // 固定されているか
  int crackLevel = 0; // ヒビのレベル（0: なし, 1: ヒビ入り, 2: 削除）

  // アニメーション用
  bool isBlinking = false;
  double blinkTimer = 0;
  bool isVisible = true;

  // スポーンボール用
  bool isSpawnBall = false; // 下部スポーンエリアのボールか
  double countdown = 0; // カウントダウンタイマー（秒）

  // 発射時間記録用
  double timeSinceFired = 0; // 発射してからの経過時間（秒）

  GameBlock({
    required this.blockColor,
    required this.gridX,
    required this.gridY,
    required this.gridOffset,
    this.blockSize = 30.0,
    this.groupId,
    this.bodyType = BodyType.dynamic,
    this.sizeMultiplier = 1,
  });

  @override
  void update(double dt) {
    super.update(dt);

    // 色ごとの重力スケールを適用（毎フレーム）
    if (isMounted && body.bodyType == BodyType.dynamic) {
      final gravity = world.gravity;
      final additionalGravity = gravity * (blockColor.gravityScale - 1.0);
      body.applyForce(additionalGravity * body.mass);

      // 発射してからの時間を更新（Dynamicの場合のみ）
      timeSinceFired += dt;
    }

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
    // サイズ倍率を考慮した半径（白は1.2倍、黄色は0.8倍）
    double effectiveMultiplier = sizeMultiplier.toDouble();
    if (blockColor == BlockColor.white) {
      effectiveMultiplier = 1.2;
    } else if (blockColor == BlockColor.yellow) {
      effectiveMultiplier = 0.8;
    }

    final actualSize = blockSize * effectiveMultiplier;
    final shape = CircleShape()..radius = (actualSize / 2); // 縮小なしで正確な半径

    // 色ごとの物理特性を適用
    // サイズ倍率に応じて密度を調整（大きさに関わらず一定の密度）
    final adjustedDensity = blockColor.density;

    final fixtureDef = FixtureDef(
      shape,
      restitution: blockColor.restitution, // 色ごとの反発係数（硬さ）
      density: adjustedDensity,            // サイズ倍率を考慮した密度
      friction: blockColor.friction,       // 色ごとの摩擦係数
    );

    // ビリヤードモード（重力なし）の場合は空気抵抗を強化
    final isBilliardMode = world.gravity.length < 0.1; // 重力がほぼ0ならビリヤードモード
    final damping = isBilliardMode ? 1.2 : 0.2; // ビリヤード: 1.2, 通常: 0.2

    final bodyDef = BodyDef(
      position: Vector2(
        gridOffset.x + gridX * blockSize + blockSize / 2,
        gridOffset.y + gridY * blockSize + blockSize / 2,
      ),
      type: bodyType,
      linearDamping: damping,  // モードに応じて空気抵抗を調整
      angularDamping: 0.8, // 回転を抑える
      bullet: true,        // 連続衝突検出を有効化（高速移動でも貫通しない）
      userData: this,      // 衝突検出で使用するために自分自身を設定
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

    // サイズ倍率を考慮（白は1.2倍、黄色は0.8倍）
    double effectiveMultiplier = sizeMultiplier.toDouble();
    if (blockColor == BlockColor.white) {
      effectiveMultiplier = 1.2;
    } else if (blockColor == BlockColor.yellow) {
      effectiveMultiplier = 0.8;
    }

    final actualSize = blockSize * effectiveMultiplier;
    final radius = actualSize / 2;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: actualSize,
      height: actualSize,
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

      // 色ごとのパターンを描画
      _drawPattern(canvas, radius);
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

    // 灰色ブロックのヒビを描画
    if (blockColor == BlockColor.grey && crackLevel > 0) {
      final crackPaint = Paint()
        ..color = const Color(0xFFFFFFFF) // 白いヒビ（黒いボールに対して目立つように）
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // ヒビのパターン（複数本の亀裂）
      if (crackLevel == 1) {
        // 複数のヒビ
        canvas.drawLine(
          Offset(-radius * 0.6, -radius * 0.4),
          Offset(radius * 0.6, radius * 0.4),
          crackPaint,
        );
        canvas.drawLine(
          Offset(-radius * 0.4, radius * 0.6),
          Offset(radius * 0.4, -radius * 0.6),
          crackPaint,
        );
        canvas.drawLine(
          Offset(-radius * 0.3, 0),
          Offset(radius * 0.3, 0),
          crackPaint,
        );
      }
    }

    // カウントダウン表示は削除（常時1個のスポーンボールシステムのため）
  }

  // 色ごとのパターンを描画
  void _drawPattern(Canvas canvas, double radius) {
    final patternPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    switch (blockColor) {
      case BlockColor.red:
        // 赤：縞模様（重厚感）
        for (int i = 0; i < 4; i++) {
          final angle = (i * 45) * (pi / 180);
          final x1 = radius * 0.8 * cos(angle);
          final y1 = radius * 0.8 * sin(angle);
          final x2 = -radius * 0.8 * cos(angle);
          final y2 = -radius * 0.8 * sin(angle);
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), patternPaint);
        }
        break;

      case BlockColor.blue:
        // 青：水玉模様（水のイメージ）
        final dotPaint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60) * (pi / 180);
          final x = radius * 0.5 * cos(angle);
          final y = radius * 0.5 * sin(angle);
          canvas.drawCircle(Offset(x, y), radius * 0.15, dotPaint);
        }
        break;

      case BlockColor.green:
        // 緑：渦巻き（自然のイメージ）
        final spiralPaint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        final path = Path();
        for (double t = 0; t < 2 * pi; t += 0.2) {
          final r = radius * 0.7 * (t / (2 * pi));
          final x = r * cos(t);
          final y = r * sin(t);
          if (t == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, spiralPaint);
        break;

      case BlockColor.yellow:
        // 黄色：星のような光線パターン
        for (int i = 0; i < 8; i++) {
          final angle = (i * 45) * (pi / 180);
          final x1 = radius * 0.3 * cos(angle);
          final y1 = radius * 0.3 * sin(angle);
          final x2 = radius * 0.7 * cos(angle);
          final y2 = radius * 0.7 * sin(angle);
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), patternPaint);
        }
        break;

      case BlockColor.purple:
        // 紫：大きな渦（石のイメージ）
        final largeSpiralPaint = Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        final path = Path();
        for (double t = 0; t < 2 * pi * 2; t += 0.3) {
          final r = radius * 0.8 * (t / (2 * pi * 2));
          final x = r * cos(t);
          final y = r * sin(t);
          if (t == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, largeSpiralPaint);
        break;

      case BlockColor.orange:
        // オレンジ：チェック柄
        final checkPaint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        for (int i = -1; i <= 1; i++) {
          for (int j = -1; j <= 1; j++) {
            if ((i + j) % 2 == 0) {
              canvas.drawRect(
                Rect.fromCenter(
                  center: Offset(i * radius * 0.3, j * radius * 0.3),
                  width: radius * 0.3,
                  height: radius * 0.3,
                ),
                checkPaint,
              );
            }
          }
        }
        break;

      case BlockColor.white:
        // 白：パターンなし（シンプル）
        break;

      case BlockColor.black:
        // 黒：十字模様（障害物のイメージ）
        final crossPaint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawLine(
          Offset(-radius * 0.7, 0),
          Offset(radius * 0.7, 0),
          crossPaint,
        );
        canvas.drawLine(
          Offset(0, -radius * 0.7),
          Offset(0, radius * 0.7),
          crossPaint,
        );
        break;

      case BlockColor.grey:
        // 灰色：パターンなし（シンプル）
        break;

      case BlockColor.rainbow:
        // 虹色：既に特別なグラデーション処理済み
        break;
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
