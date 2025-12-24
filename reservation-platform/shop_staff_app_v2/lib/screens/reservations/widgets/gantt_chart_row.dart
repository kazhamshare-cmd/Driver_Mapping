import 'package:flutter/material.dart';
import '../../../models/reservation.dart';
import '../../../models/table.dart';
import '../../../models/blocked_slot.dart';
import '../../../utils/time_utils.dart';

/// ガントチャートの1行（テーブルごとの予約表示）
class GanttChartRow extends StatelessWidget {
  final TableModel? table; // nullの場合は未割当行
  final List<Reservation> reservations;
  final List<BlockedSlot> blockedSlots;
  final List<String> timeSlots;
  final double cellWidth;
  final double rowHeight;
  final Function(Reservation) onReservationTap;
  final Function(BlockedSlot) onBlockedSlotTap;
  final Function(String startTime)? onEmptyCellTap; // 未割当行ではnull可

  const GanttChartRow({
    this.table,
    required this.reservations,
    required this.blockedSlots,
    required this.timeSlots,
    required this.cellWidth,
    required this.rowHeight,
    required this.onReservationTap,
    required this.onBlockedSlotTap,
    this.onEmptyCellTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUnassigned = table == null;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: isUnassigned ? Colors.orange.shade50 : null,
        border: Border(
          bottom: BorderSide(
            color: isUnassigned ? Colors.orange.shade300 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Stack(
        children: [
          // グリッド線（タップ可能）
          Row(
            children: timeSlots.map((slot) {
              return GestureDetector(
                onTap: onEmptyCellTap != null ? () => onEmptyCellTap!(slot) : null,
                child: Container(
                  width: cellWidth,
                  decoration: BoxDecoration(
                    border: Border(
                        right: BorderSide(color: isUnassigned ? Colors.orange.shade200 : Colors.grey.shade200)),
                  ),
                ),
              );
            }).toList(),
          ),
          // ブロックスロット（未割当行では表示しない）
          if (!isUnassigned)
            ...blockedSlots.map((b) => _buildBlockedSlotBlock(context, b)),
          // 予約ブロック
          ...reservations.map((r) => _buildReservationBlock(context, r)),
        ],
      ),
    );
  }

  Widget _buildBlockedSlotBlock(BuildContext context, BlockedSlot blockedSlot) {
    if (timeSlots.isEmpty) return const SizedBox.shrink();

    final startIndex = TimeSlotUtils.getSlotIndex(
      blockedSlot.startTime,
      timeSlots.first,
      30,
    );
    final span = TimeSlotUtils.calculateSlotSpan(
      blockedSlot.startTime,
      blockedSlot.endTime,
      30,
    );

    // 位置とサイズを計算
    final left = startIndex * cellWidth;
    final width = span * cellWidth - 4;

    // 範囲外の場合はスキップ
    if (startIndex < 0 || left >= timeSlots.length * cellWidth) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: left + 2,
      top: 4,
      child: GestureDetector(
        onTap: () => onBlockedSlotTap(blockedSlot),
        child: Container(
          width: width > 0 ? width : cellWidth - 4,
          height: rowHeight - 8,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade600, width: 1),
          ),
          child: Center(
            child: Text(
              blockedSlot.reason ?? '受付不可',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReservationBlock(BuildContext context, Reservation reservation) {
    if (timeSlots.isEmpty) return const SizedBox.shrink();

    final startIndex = TimeSlotUtils.getSlotIndex(
      reservation.startTime,
      timeSlots.first,
      30,
    );
    final span = TimeSlotUtils.calculateSlotSpan(
      reservation.startTime,
      reservation.endTime,
      30,
    );

    // 位置とサイズを計算
    final left = startIndex * cellWidth;
    final width = span * cellWidth - 4; // マージン分を引く

    // 範囲外の場合はスキップ
    if (startIndex < 0 || left >= timeSlots.length * cellWidth) {
      return const SizedBox.shrink();
    }

    // ステータスに応じた色
    Color blockColor;
    switch (reservation.status) {
      case ReservationStatus.pending:
        blockColor = Colors.orange;
        break;
      case ReservationStatus.confirmed:
        blockColor = Colors.green;
        break;
      case ReservationStatus.completed:
        blockColor = Colors.grey;
        break;
      default:
        blockColor = Colors.grey.shade400;
    }

    return Positioned(
      left: left + 2,
      top: 4,
      child: GestureDetector(
        onTap: () => onReservationTap(reservation),
        child: Container(
          width: width > 0 ? width : cellWidth - 4,
          height: rowHeight - 8,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: blockColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // スタッフ名（指名がある場合）
              if (reservation.staffName != null &&
                  reservation.staffName!.isNotEmpty)
                Text(
                  reservation.staffName!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              // コース名/メニュー名
              Text(
                reservation.menuName,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              // 人数
              if (reservation.numberOfPeople != null)
                Text(
                  '${reservation.numberOfPeople}名',
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.white60,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
