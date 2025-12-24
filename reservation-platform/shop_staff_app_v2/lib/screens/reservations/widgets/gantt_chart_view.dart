import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import '../../../models/reservation.dart';
import '../../../models/blocked_slot.dart';
import '../../../providers/reservation_provider.dart';
import '../../../providers/table_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/blocked_slot_provider.dart';
import '../../../utils/time_utils.dart';
import 'staff_filter_bar.dart';
import 'gantt_chart_row.dart';

/// ガントチャートビュー
class GanttChartView extends ConsumerStatefulWidget {
  final Function(Reservation) onReservationTap;

  const GanttChartView({
    required this.onReservationTap,
    super.key,
  });

  @override
  ConsumerState<GanttChartView> createState() => _GanttChartViewState();
}

class _GanttChartViewState extends ConsumerState<GanttChartView> {
  late LinkedScrollControllerGroup _horizontalControllers;
  late ScrollController _headerHorizontalController;
  late ScrollController _bodyHorizontalController;
  late ScrollController _labelVerticalController;
  late ScrollController _bodyVerticalController;
  late LinkedScrollControllerGroup _verticalControllers;

  static const double cellWidth = 60.0;
  static const double rowHeight = 70.0;
  static const double headerHeight = 40.0;
  static const double labelWidth = 80.0;

  @override
  void initState() {
    super.initState();
    _horizontalControllers = LinkedScrollControllerGroup();
    _headerHorizontalController = _horizontalControllers.addAndGet();
    _bodyHorizontalController = _horizontalControllers.addAndGet();

    _verticalControllers = LinkedScrollControllerGroup();
    _labelVerticalController = _verticalControllers.addAndGet();
    _bodyVerticalController = _verticalControllers.addAndGet();
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    _labelVerticalController.dispose();
    _bodyVerticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(sortedTablesProvider);
    final reservationsByTable = ref.watch(reservationsByTableProvider);
    final unassignedReservations = ref.watch(unassignedReservationsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final blockedSlotsAsync = ref.watch(blockedSlotsForDateProvider(selectedDate));
    final blockedSlots = blockedSlotsAsync.value ?? [];
    final timeSlots = TimeSlotUtils.generateTimeSlots();

    // テーブル一覧 + 未割当予約がある場合は未割当行を追加
    final hasUnassigned = unassignedReservations.isNotEmpty;
    final totalRows = tablesAsync.length + (hasUnassigned ? 1 : 0);

    return Column(
      children: [
        // 日付表示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade700,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state =
                      selectedDate.subtract(const Duration(days: 1));
                },
              ),
              Expanded(
                child: Text(
                  '${selectedDate.year}/${selectedDate.month}/${selectedDate.day}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state =
                      selectedDate.add(const Duration(days: 1));
                },
              ),
              IconButton(
                icon: const Icon(Icons.today, color: Colors.white),
                onPressed: () {
                  ref.read(selectedDateProvider.notifier).state = DateTime.now();
                },
                tooltip: '今日',
              ),
              IconButton(
                icon: const Icon(Icons.block, color: Colors.white),
                onPressed: () => _showBlockDialog(context, ref, selectedDate),
                tooltip: '受付不可設定',
              ),
            ],
          ),
        ),

        // スタッフフィルターバー
        const StaffFilterBar(),

        // ガントチャート本体
        Expanded(
          child: tablesAsync.isEmpty && !hasUnassigned
              ? const Center(child: Text('テーブルがありません'))
              : Row(
                  children: [
                    // 固定テーブルラベル列
                    SizedBox(
                      width: labelWidth,
                      child: Column(
                        children: [
                          // コーナーセル
                          Container(
                            height: headerHeight,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade400),
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '席/時間',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // テーブルラベル
                          Expanded(
                            child: ListView.builder(
                              controller: _labelVerticalController,
                              itemCount: totalRows,
                              itemBuilder: (context, index) {
                                // 未割当行（最後に表示）
                                if (index >= tablesAsync.length) {
                                  return Container(
                                    height: rowHeight,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.orange.shade300),
                                        right: BorderSide(color: Colors.orange.shade300),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              '未割当',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${unassignedReservations.length}件',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final table = tablesAsync[index];
                                return Container(
                                  height: rowHeight,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    border: Border(
                                      bottom:
                                          BorderSide(color: Colors.grey.shade300),
                                      right:
                                          BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        table.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${table.seatTypeName} ${table.minCapacity}-${table.maxCapacity}名',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // スクロール可能なグリッドエリア
                    Expanded(
                      child: Column(
                        children: [
                          // 時間ヘッダー
                          SizedBox(
                            height: headerHeight,
                            child: ListView.builder(
                              controller: _headerHorizontalController,
                              scrollDirection: Axis.horizontal,
                              itemCount: timeSlots.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: cellWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    border: Border(
                                      bottom:
                                          BorderSide(color: Colors.grey.shade400),
                                      right:
                                          BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    timeSlots[index],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          // グリッド本体
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _bodyHorizontalController,
                              child: SizedBox(
                                width: cellWidth * timeSlots.length,
                                child: ListView.builder(
                                  controller: _bodyVerticalController,
                                  itemCount: totalRows,
                                  itemBuilder: (context, rowIndex) {
                                    // 未割当行（最後に表示）
                                    if (rowIndex >= tablesAsync.length) {
                                      return GanttChartRow(
                                        table: null, // 未割当
                                        reservations: unassignedReservations,
                                        blockedSlots: const [], // ブロックスロットなし
                                        timeSlots: timeSlots,
                                        cellWidth: cellWidth,
                                        rowHeight: rowHeight,
                                        onReservationTap: widget.onReservationTap,
                                        onBlockedSlotTap: (_) {}, // 未使用
                                        onEmptyCellTap: null, // タップ不可
                                      );
                                    }

                                    final table = tablesAsync[rowIndex];
                                    final reservations =
                                        reservationsByTable[table.id] ?? [];
                                    return GanttChartRow(
                                      table: table,
                                      reservations: reservations,
                                      blockedSlots: blockedSlots,
                                      timeSlots: timeSlots,
                                      cellWidth: cellWidth,
                                      rowHeight: rowHeight,
                                      onReservationTap: widget.onReservationTap,
                                      onBlockedSlotTap: (slot) => _showDeleteBlockDialog(context, ref, slot),
                                      onEmptyCellTap: (startTime) => _showCreateBlockDialog(context, ref, selectedDate, startTime),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// ブロック設定メニューダイアログ
  void _showBlockDialog(BuildContext context, WidgetRef ref, DateTime date) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('終日受付不可にする'),
              subtitle: Text('${date.month}/${date.day}の予約を全てブロック'),
              onTap: () async {
                Navigator.pop(context);
                final setAllDay = ref.read(setAllDayBlockProvider);
                try {
                  await setAllDay(date: date, reason: '終日受付不可');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('終日受付不可に設定しました')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラー: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('時間帯を指定してブロック'),
              onTap: () {
                Navigator.pop(context);
                _showCreateBlockDialog(context, ref, date, '10:00');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('キャンセル'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// ブロック作成ダイアログ
  void _showCreateBlockDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    String initialStartTime,
  ) {
    String startTime = initialStartTime;
    String endTime = _addHours(initialStartTime, 1);
    String reason = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('受付不可時間を設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.month}/${date.day}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: startTime,
                      decoration: const InputDecoration(
                        labelText: '開始',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: TimeSlotUtils.generateTimeSlots()
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            startTime = v;
                            // 終了時間が開始より前なら調整
                            if (_compareTime(endTime, startTime) <= 0) {
                              endTime = _addHours(startTime, 1);
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('〜'),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: endTime,
                      decoration: const InputDecoration(
                        labelText: '終了',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: TimeSlotUtils.generateTimeSlots()
                          .where((t) => _compareTime(t, startTime) > 0)
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => endTime = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '理由（任意）',
                  hintText: '休憩、満席など',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => reason = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final createBlock = ref.read(createBlockedSlotProvider);
                try {
                  await createBlock(
                    date: date,
                    startTime: startTime,
                    endTime: endTime,
                    reason: reason.isNotEmpty ? reason : null,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$startTime〜$endTime を受付不可に設定')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラー: $e')),
                    );
                  }
                }
              },
              child: const Text('設定'),
            ),
          ],
        ),
      ),
    );
  }

  /// ブロック削除確認ダイアログ
  void _showDeleteBlockDialog(BuildContext context, WidgetRef ref, BlockedSlot slot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('受付不可を解除'),
        content: Text(
          '${slot.startTime}〜${slot.endTime}の受付不可を解除しますか？\n${slot.reason ?? ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final deleteBlock = ref.read(deleteBlockedSlotProvider);
              try {
                await deleteBlock(slot.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('受付不可を解除しました')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('解除'),
          ),
        ],
      ),
    );
  }

  /// 時間に時間を加算
  String _addHours(String time, int hours) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]) + hours;
    final minute = parts[1];
    if (hour >= 24) return '23:30';
    return '${hour.toString().padLeft(2, '0')}:$minute';
  }

  /// 時間比較（a > b なら正、a < b なら負）
  int _compareTime(String a, String b) {
    final aParts = a.split(':');
    final bParts = b.split(':');
    final aMinutes = int.parse(aParts[0]) * 60 + int.parse(aParts[1]);
    final bMinutes = int.parse(bParts[0]) * 60 + int.parse(bParts[1]);
    return aMinutes - bMinutes;
  }
}
