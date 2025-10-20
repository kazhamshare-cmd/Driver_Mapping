import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show RadialGradient, Alignment;
import '../utils/block_color.dart';

class RouletteDisplay extends PositionComponent {
  final double slotSize;
  BlockColor leftColor;
  BlockColor rightColor;
  bool isSpinning = false;

  RouletteDisplay({
    required this.slotSize,
    required this.leftColor,
    required this.rightColor,
    required Vector2 position,
  }) : super(position: position, size: Vector2(slotSize * 2 + 10, slotSize));

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 左スロット
    _drawSlot(canvas, Offset(0, 0), leftColor);

    // 右スロット
    _drawSlot(canvas, Offset(slotSize + 10, 0), rightColor);
  }

  void _drawSlot(Canvas canvas, Offset offset, BlockColor color) {
    final radius = slotSize / 2;
    final center = offset + Offset(radius, radius);
    final rect = Rect.fromCenter(center: center, width: slotSize, height: slotSize);

    // グラデーションで立体感のあるボールを描画
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        color.color.withValues(alpha: 1.0),
        color.color.withValues(alpha: 0.8),
        color.color.withValues(alpha: 0.6),
      ],
      stops: const [0.0, 0.6, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // 枠線
    final borderPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    // ハイライト
    final highlightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      center + Offset(-radius * 0.3, -radius * 0.3),
      radius * 0.3,
      highlightPaint,
    );
  }

  void setColors(BlockColor left, BlockColor right) {
    leftColor = left;
    rightColor = right;
  }
}
