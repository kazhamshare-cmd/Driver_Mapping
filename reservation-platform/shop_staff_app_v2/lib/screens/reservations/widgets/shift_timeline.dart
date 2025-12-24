import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/shift_provider.dart';

/// 選択スタッフのシフト表示コンポーネント
class ShiftTimeline extends ConsumerWidget {
  final String employeeId;

  const ShiftTimeline({required this.employeeId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(staffShiftProvider(employeeId));

    if (shift == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Icon(Icons.event_busy, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'シフトなし',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            'シフト: ${shift.startTime} - ${shift.endTime}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '${shift.workHours.toStringAsFixed(1)}時間',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          if (shift.breakMinutes > 0) ...[
            const SizedBox(width: 8),
            Text(
              '(休憩${shift.breakMinutes}分)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
