import 'package:flutter/material.dart';

class DraggableCharacter extends StatelessWidget {
  final String character;
  final bool isPlaced;
  final VoidCallback? onDragCompleted;
  final VoidCallback? onTap; // タップ時のコールバック
  final bool enableDrag; // ドラッグ機能の有効/無効

  const DraggableCharacter({
    super.key,
    required this.character,
    this.isPlaced = false,
    this.onDragCompleted,
    this.onTap,
    this.enableDrag = true, // デフォルトは有効
  });

  @override
  Widget build(BuildContext context) {
    if (isPlaced) {
      // 既に配置済みの場合は透明な空のコンテナを返す
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.withOpacity(0.5),
            width: 2,
          ),
        ),
      );
    }

    // ドラッグが無効な場合はタップのみ
    if (!enableDrag) {
      return GestureDetector(
        onTap: onTap,
        child: _CharacterChip(character: character),
      );
    }

    // ドラッグが有効な場合
    return GestureDetector(
      onTap: onTap,
      child: Draggable<String>(
        data: character,
        feedback: Material(
          color: Colors.transparent,
          child: _CharacterChip(
            character: character,
            isDragging: true,
          ),
        ),
        childWhenDragging: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.withOpacity(0.5),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
        ),
        onDragCompleted: onDragCompleted,
        child: _CharacterChip(character: character),
      ),
    );
  }
}

class _CharacterChip extends StatelessWidget {
  final String character;
  final bool isDragging;

  const _CharacterChip({
    required this.character,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isDragging ? Colors.blue.shade400 : Colors.blue.shade300,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          character,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
