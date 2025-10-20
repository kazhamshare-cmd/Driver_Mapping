import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameGrid extends PositionComponent {
  final int columns;
  final int rows;
  final double blockSize;

  GameGrid({
    required this.columns,
    required this.rows,
    required this.blockSize,
  }) : super(
          size: Vector2(columns * blockSize, rows * blockSize),
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 背景を描画
    final backgroundPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      backgroundPaint,
    );

    // グリッド線を描画
    final gridPaint = Paint()
      ..color = const Color(0xFF34495E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 縦線
    for (int i = 0; i <= columns; i++) {
      canvas.drawLine(
        Offset(i * blockSize, 0),
        Offset(i * blockSize, size.y),
        gridPaint,
      );
    }

    // 横線
    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(
        Offset(0, i * blockSize),
        Offset(size.x, i * blockSize),
        gridPaint,
      );
    }

    // 枠線を描画
    final borderPaint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      borderPaint,
    );
  }
}
