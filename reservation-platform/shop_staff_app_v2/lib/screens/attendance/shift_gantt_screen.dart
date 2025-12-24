import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

/// シフトGantt表示画面
class ShiftGanttScreen extends ConsumerStatefulWidget {
  const ShiftGanttScreen({super.key});

  @override
  ConsumerState<ShiftGanttScreen> createState() => _ShiftGanttScreenState();
}

class _ShiftGanttScreenState extends ConsumerState<ShiftGanttScreen> {
  DateTime _selectedDate = DateTime.now();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  // 表示設定
  static const double hourWidth = 60.0;
  static const double rowHeight = 50.0;
  static const double nameColumnWidth = 100.0;
  static const int startHour = 8; // 8:00から表示
  static const int endHour = 24; // 24:00まで表示

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('シフト表（Gantt）'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日',
            onPressed: () {
              setState(() => _selectedDate = DateTime.now());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 日付セレクター
          _buildDateSelector(),

          // Ganttチャート
          Expanded(
            child: FutureBuilder<List<_EmployeeShift>>(
              future: _loadShifts(staffUser.shopId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final shifts = snapshot.data ?? [];

                if (shifts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'この日のシフトはありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildGanttChart(shifts);
              },
            ),
          ),

          // 凡例
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<List<_EmployeeShift>> _loadShifts(String shopId) async {
    final targetDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final nextDate = targetDate.add(const Duration(days: 1));

    // スタッフ一覧を取得
    final employeesSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('employees')
        .orderBy('name')
        .get();

    final shifts = <_EmployeeShift>[];

    for (var empDoc in employeesSnapshot.docs) {
      final empData = empDoc.data();
      final employeeId = empDoc.id;
      final employeeName = empData['name'] as String? ?? '名前なし';

      // このスタッフのシフトを取得
      final shiftSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('shifts')
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(targetDate))
          .where('date', isLessThan: Timestamp.fromDate(nextDate))
          .get();

      // 出退勤記録も取得
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('attendance')
          .where('staffId', isEqualTo: employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(targetDate))
          .where('date', isLessThan: Timestamp.fromDate(nextDate))
          .get();

      TimeOfDay? scheduledStart;
      TimeOfDay? scheduledEnd;
      TimeOfDay? actualStart;
      TimeOfDay? actualEnd;

      // シフト予定
      if (shiftSnapshot.docs.isNotEmpty) {
        final shiftData = shiftSnapshot.docs.first.data();
        final startTime = shiftData['startTime'] as String?;
        final endTime = shiftData['endTime'] as String?;

        if (startTime != null) {
          final parts = startTime.split(':');
          scheduledStart = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        if (endTime != null) {
          final parts = endTime.split(':');
          scheduledEnd = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }

      // 実績
      if (attendanceSnapshot.docs.isNotEmpty) {
        final attData = attendanceSnapshot.docs.first.data();
        final clockIn = (attData['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (attData['clockOut'] as Timestamp?)?.toDate();

        if (clockIn != null) {
          actualStart = TimeOfDay(hour: clockIn.hour, minute: clockIn.minute);
        }
        if (clockOut != null) {
          actualEnd = TimeOfDay(hour: clockOut.hour, minute: clockOut.minute);
        }
      }

      // シフトまたは実績がある場合のみ追加
      if (scheduledStart != null || actualStart != null) {
        shifts.add(_EmployeeShift(
          employeeId: employeeId,
          employeeName: employeeName,
          scheduledStart: scheduledStart,
          scheduledEnd: scheduledEnd,
          actualStart: actualStart,
          actualEnd: actualEnd,
        ));
      }
    }

    return shifts;
  }

  Widget _buildGanttChart(List<_EmployeeShift> shifts) {
    final hours = List.generate(endHour - startHour + 1, (i) => startHour + i);

    return Column(
      children: [
        // 時間ヘッダー
        Container(
          height: 40,
          color: Colors.grey.shade200,
          child: Row(
            children: [
              Container(
                width: nameColumnWidth,
                alignment: Alignment.center,
                child: const Text(
                  'スタッフ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalController,
                  child: Row(
                    children: hours.map((hour) {
                      return Container(
                        width: hourWidth,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          '$hour:00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hour == 12 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // シフト行
        Expanded(
          child: Row(
            children: [
              // スタッフ名列
              SizedBox(
                width: nameColumnWidth,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    return Container(
                      height: rowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                        color: index.isEven ? Colors.white : Colors.grey.shade50,
                      ),
                      child: Text(
                        shifts[index].employeeName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),

              // Ganttバー
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // 横スクロールを同期
                    return false;
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalController,
                    child: SizedBox(
                      width: (endHour - startHour + 1) * hourWidth,
                      child: ListView.builder(
                        itemCount: shifts.length,
                        itemBuilder: (context, index) {
                          return _buildShiftRow(shifts[index], index);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftRow(_EmployeeShift shift, int index) {
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        color: index.isEven ? Colors.white : Colors.grey.shade50,
      ),
      child: Stack(
        children: [
          // 背景グリッド
          Row(
            children: List.generate(endHour - startHour + 1, (i) {
              return Container(
                width: hourWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              );
            }),
          ),

          // 予定シフト（薄い色）
          if (shift.scheduledStart != null && shift.scheduledEnd != null)
            Positioned(
              left: _timeToPosition(shift.scheduledStart!),
              width: _timeDurationToWidth(shift.scheduledStart!, shift.scheduledEnd!),
              top: 8,
              height: rowHeight - 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${_formatTime(shift.scheduledStart!)} - ${_formatTime(shift.scheduledEnd!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),

          // 実績（濃い色でオーバーレイ）
          if (shift.actualStart != null)
            Positioned(
              left: _timeToPosition(shift.actualStart!),
              width: shift.actualEnd != null
                  ? _timeDurationToWidth(shift.actualStart!, shift.actualEnd!)
                  : (DateTime.now().hour - shift.actualStart!.hour) * hourWidth +
                    ((DateTime.now().minute - shift.actualStart!.minute) / 60) * hourWidth,
              top: 12,
              height: rowHeight - 24,
              child: Container(
                decoration: BoxDecoration(
                  color: shift.actualEnd != null
                      ? Colors.green.shade400
                      : Colors.orange.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  shift.actualEnd != null
                      ? '${_formatTime(shift.actualStart!)} - ${_formatTime(shift.actualEnd!)}'
                      : '${_formatTime(shift.actualStart!)} - 勤務中',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _timeToPosition(TimeOfDay time) {
    final hours = time.hour - startHour;
    final minutes = time.minute / 60;
    return (hours + minutes) * hourWidth;
  }

  double _timeDurationToWidth(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final durationMinutes = endMinutes - startMinutes;
    return (durationMinutes / 60) * hourWidth;
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.blue.shade100, '予定', border: Colors.blue.shade300),
          const SizedBox(width: 24),
          _buildLegendItem(Colors.green.shade400, '実績（完了）'),
          const SizedBox(width: 24),
          _buildLegendItem(Colors.orange.shade400, '勤務中'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {Color? border}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: border != null ? Border.all(color: border) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

/// シフトデータクラス
class _EmployeeShift {
  final String employeeId;
  final String employeeName;
  final TimeOfDay? scheduledStart;
  final TimeOfDay? scheduledEnd;
  final TimeOfDay? actualStart;
  final TimeOfDay? actualEnd;

  _EmployeeShift({
    required this.employeeId,
    required this.employeeName,
    this.scheduledStart,
    this.scheduledEnd,
    this.actualStart,
    this.actualEnd,
  });
}
