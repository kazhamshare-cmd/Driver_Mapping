import 'package:flutter/material.dart';

class AnswerArea extends StatelessWidget {
  final List<String?> answer;
  final Function(String, int) onCharacterDropped;
  final Function(int, int) onCharacterReordered;
  final Function(int)? onCharacterRemoved;

  const AnswerArea({
    super.key,
    required this.answer,
    required this.onCharacterDropped,
    required this.onCharacterReordered,
    this.onCharacterRemoved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '回答エリア',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(
              answer.length,
              (index) => _AnswerSlot(
                character: answer[index],
                index: index,
                onAccept: (character) {
                  onCharacterDropped(character, index);
                },
                onReorder: (fromIndex) {
                  if (fromIndex != index) {
                    onCharacterReordered(fromIndex, index);
                  }
                },
                onRemove: onCharacterRemoved != null
                    ? () => onCharacterRemoved!(index)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerSlot extends StatelessWidget {
  final String? character;
  final int index;
  final Function(String) onAccept;
  final Function(int) onReorder;
  final VoidCallback? onRemove;

  const _AnswerSlot({
    required this.character,
    required this.index,
    required this.onAccept,
    required this.onReorder,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // すべてのスロットが並び替えを受け入れられるようにする
    return DragTarget<int>(
      onAcceptWithDetails: (details) {
        // 他のスロットから並び替え
        onReorder(details.data);
      },
      builder: (context, candidateIntData, rejectedIntData) {
        // さらに新しい文字も受け入れられるようにする（空のスロットのみ）
        if (character == null) {
          return DragTarget<String>(
            onAcceptWithDetails: (details) {
              onAccept(details.data);
            },
            builder: (context, candidateStringData, rejectedStringData) {
              final bool isOverString = candidateStringData.isNotEmpty;
              final bool isOverInt = candidateIntData.isNotEmpty;
              final bool isOver = isOverString || isOverInt;

              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isOver
                      ? Colors.deepPurple.shade100
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOver ? Colors.deepPurple : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              );
            },
          );
        }

        // 文字が配置されている場合、ドラッグ可能にする
        final bool isOver = candidateIntData.isNotEmpty;
        return Draggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade400,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  character!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey,
                width: 2,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isOver
                    ? Colors.deepPurple.shade200
                    : Colors.deepPurple.shade300,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOver ? Colors.deepPurple : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  character!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
