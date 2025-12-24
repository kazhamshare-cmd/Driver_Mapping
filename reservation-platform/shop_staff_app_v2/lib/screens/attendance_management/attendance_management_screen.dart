import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../attendance/shift_gantt_screen.dart';

/// 勤怠管理画面（店長・オーナー向け）
class AttendanceManagementScreen extends ConsumerStatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  ConsumerState<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends ConsumerState<AttendanceManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  bool _showAllEmployees = true;

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;
    final shopId = staffUser?.shopId;

    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('勤怠管理'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('勤怠管理'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Gantt表示',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShiftGanttScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'フィルター',
            onPressed: () => _showFilterDialog(shopId),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(height: 1),
          Expanded(
            child: _buildAttendanceList(shopId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAttendanceDialog(context, shopId),
        icon: const Icon(Icons.add),
        label: const Text('手動入力'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy/M/d (E)').format(_selectedDate),
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
              final tomorrow =
                  DateTime.now().add(const Duration(days: 1));
              if (_selectedDate.isBefore(tomorrow)) {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日',
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList(String shopId) {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _getAttendances(shopId, startOfDay, endOfDay),
      builder: (context, attendanceSnapshot) {
        if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _getEmployees(shopId),
          builder: (context, employeesSnapshot) {
            if (!employeesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final employees = employeesSnapshot.data!.docs;
            final attendances = attendanceSnapshot.data?.docs ?? [];

            // 勤怠データをemployeeIdでマップ化
            final attendanceByEmployee = <String, List<DocumentSnapshot>>{};
            for (final att in attendances) {
              final data = att.data() as Map<String, dynamic>;
              final employeeId = data['employeeId'] as String;

              if (_selectedEmployeeId != null &&
                  employeeId != _selectedEmployeeId) {
                continue;
              }

              attendanceByEmployee.putIfAbsent(employeeId, () => []);
              attendanceByEmployee[employeeId]!.add(att);
            }

            // 全従業員表示の場合、勤怠がない従業員も表示
            final displayEmployees = _showAllEmployees
                ? employees
                : employees.where((e) =>
                    attendanceByEmployee.containsKey(e.id) ||
                    (_selectedEmployeeId != null && e.id == _selectedEmployeeId)).toList();

            if (displayEmployees.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('勤怠データがありません'),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayEmployees.length,
              itemBuilder: (context, index) {
                final employeeDoc = displayEmployees[index];
                final employee = employeeDoc.data() as Map<String, dynamic>;
                final employeeId = employeeDoc.id;
                final employeeAttendances =
                    attendanceByEmployee[employeeId] ?? [];

                return _buildEmployeeAttendanceCard(
                  employeeId,
                  employee,
                  employeeAttendances,
                  shopId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeAttendanceCard(
    String employeeId,
    Map<String, dynamic> employee,
    List<DocumentSnapshot> attendances,
    String shopId,
  ) {
    final name =
        '${employee['lastName'] ?? ''} ${employee['firstName'] ?? ''}'.trim();
    final role = employee['role'] ?? 'staff';
    final hourlyWage = (employee['hourlyWage'] ?? 1000).toDouble();

    // 勤務時間を計算
    int totalMinutes = 0;
    for (final att in attendances) {
      final data = att.data() as Map<String, dynamic>;
      final clockIn = data['clockIn'] as Map<String, dynamic>?;
      final clockOut = data['clockOut'] as Map<String, dynamic>?;

      if (clockIn != null && clockOut != null) {
        final inTime = (clockIn['timestamp'] as Timestamp).toDate();
        final outTime = (clockOut['timestamp'] as Timestamp).toDate();
        totalMinutes += outTime.difference(inTime).inMinutes;

        // 休憩時間を引く
        final breaks = data['breaks'] as List<dynamic>? ?? [];
        for (final brk in breaks) {
          final breakData = brk as Map<String, dynamic>;
          final breakStart = (breakData['start'] as Timestamp?)?.toDate();
          final breakEnd = (breakData['end'] as Timestamp?)?.toDate();
          if (breakStart != null && breakEnd != null) {
            totalMinutes -= breakEnd.difference(breakStart).inMinutes;
          }
        }
      }
    }

    final hours = totalMinutes / 60.0;
    final earnings = hours * hourlyWage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: attendances.isNotEmpty
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getRoleColor(role).withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(role),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name.isNotEmpty ? name : '名前なし',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildRoleBadge(role),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (attendances.isNotEmpty)
                        Text(
                          '${hours.toStringAsFixed(1)}時間 / ¥${earnings.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          '勤務なし',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '手動入力',
                  onPressed: () => _showAddAttendanceForEmployeeDialog(
                    context,
                    shopId,
                    employeeId,
                    name,
                  ),
                ),
              ],
            ),
          ),
          // 勤怠リスト
          if (attendances.isNotEmpty)
            ...attendances.map((att) => _buildAttendanceTile(att, name)),
        ],
      ),
    );
  }

  Widget _buildAttendanceTile(DocumentSnapshot doc, String employeeName) {
    final data = doc.data() as Map<String, dynamic>;
    final clockIn = data['clockIn'] as Map<String, dynamic>?;
    final clockOut = data['clockOut'] as Map<String, dynamic>?;
    final status = data['status'] as String? ?? 'working';

    DateTime? inTime;
    DateTime? outTime;

    if (clockIn != null) {
      inTime = (clockIn['timestamp'] as Timestamp).toDate();
    }
    if (clockOut != null) {
      outTime = (clockOut['timestamp'] as Timestamp).toDate();
    }

    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = '完了';
        break;
      case 'working':
        statusColor = Colors.blue;
        statusText = '勤務中';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return InkWell(
      onTap: () => _showEditAttendanceDialog(context, doc, employeeName),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            // 出勤時間
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '出勤',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    inTime != null
                        ? DateFormat('HH:mm').format(inTime)
                        : '--:--',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.grey),
            // 退勤時間
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '退勤',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    outTime != null
                        ? DateFormat('HH:mm').format(outTime)
                        : '--:--',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: outTime != null ? null : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // 勤務時間
            if (inTime != null && outTime != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '勤務時間',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${(outTime.difference(inTime).inMinutes / 60).toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.edit, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;

    switch (role) {
      case 'owner':
        color = Colors.purple;
        label = 'オーナー';
        break;
      case 'manager':
        color = Colors.blue;
        label = '店長';
        break;
      default:
        color = Colors.green;
        label = 'スタッフ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  Stream<QuerySnapshot> _getAttendances(
      String shopId, DateTime startOfDay, DateTime endOfDay) {
    return FirebaseFirestore.instance
        .collection('attendances')
        .where('shopId', isEqualTo: shopId)
        .where('workDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('workDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();
  }

  Stream<QuerySnapshot> _getEmployees(String shopId) {
    return FirebaseFirestore.instance
        .collection('employees')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  void _showFilterDialog(String shopId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('フィルター'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('全スタッフを表示'),
              subtitle: const Text('勤務なしのスタッフも表示'),
              value: _showAllEmployees,
              onChanged: (value) {
                setState(() {
                  _showAllEmployees = value;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showAddAttendanceDialog(BuildContext context, String shopId) {
    String? selectedEmployeeId;
    String? selectedEmployeeName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.blue),
            SizedBox(width: 8),
            Text('スタッフを選択'),
          ],
        ),
        content: StreamBuilder<QuerySnapshot>(
          stream: _getEmployees(shopId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final employees = snapshot.data!.docs;
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final doc = employees[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                          .trim();

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isNotEmpty ? name[0] : '?'),
                    ),
                    title: Text(name.isNotEmpty ? name : '名前なし'),
                    subtitle: Text(_getRoleLabel(data['role'] ?? 'staff')),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddAttendanceForEmployeeDialog(
                        context,
                        shopId,
                        doc.id,
                        name.isNotEmpty ? name : '名前なし',
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'オーナー';
      case 'manager':
        return '店長';
      default:
        return 'スタッフ';
    }
  }

  void _showAddAttendanceForEmployeeDialog(
    BuildContext context,
    String shopId,
    String employeeId,
    String employeeName,
  ) {
    final clockInController = TextEditingController(text: '10:00');
    final clockOutController = TextEditingController(text: '18:00');
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('勤怠入力'),
                        Text(
                          '$employeeName - ${DateFormat('M/d (E)').format(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: clockInController,
                    decoration: const InputDecoration(
                      labelText: '出勤時間',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.login),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: clockOutController,
                    decoration: const InputDecoration(
                      labelText: '退勤時間',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.logout),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);

                          try {
                            final clockInTime = _parseTime(
                                clockInController.text, _selectedDate);
                            final clockOutTime = _parseTime(
                                clockOutController.text, _selectedDate);

                            await FirebaseFirestore.instance
                                .collection('attendances')
                                .add({
                              'shopId': shopId,
                              'employeeId': employeeId,
                              'workDate': Timestamp.fromDate(_selectedDate),
                              'clockIn': {
                                'timestamp': Timestamp.fromDate(clockInTime),
                                'location': null,
                                'deviceInfo': 'Manual Entry',
                              },
                              'clockOut': {
                                'timestamp': Timestamp.fromDate(clockOutTime),
                                'location': null,
                                'deviceInfo': 'Manual Entry',
                              },
                              'status': 'completed',
                              'isManualEntry': true,
                              'breaks': [],
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('勤怠を登録しました'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('エラー: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登録'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAttendanceDialog(
    BuildContext context,
    DocumentSnapshot doc,
    String employeeName,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final clockIn = data['clockIn'] as Map<String, dynamic>?;
    final clockOut = data['clockOut'] as Map<String, dynamic>?;
    final workDate = (data['workDate'] as Timestamp).toDate();

    DateTime? inTime;
    DateTime? outTime;

    if (clockIn != null) {
      inTime = (clockIn['timestamp'] as Timestamp).toDate();
    }
    if (clockOut != null) {
      outTime = (clockOut['timestamp'] as Timestamp).toDate();
    }

    final clockInController = TextEditingController(
      text: inTime != null ? DateFormat('HH:mm').format(inTime) : '',
    );
    final clockOutController = TextEditingController(
      text: outTime != null ? DateFormat('HH:mm').format(outTime) : '',
    );
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('勤怠修正'),
                        Text(
                          '$employeeName - ${DateFormat('M/d (E)').format(workDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: clockInController,
                    decoration: const InputDecoration(
                      labelText: '出勤時間',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.login),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: clockOutController,
                    decoration: const InputDecoration(
                      labelText: '退勤時間（空欄で勤務中）',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.logout),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteAttendance(context, doc),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      '削除',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size.fromHeight(40),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);

                          try {
                            final Map<String, dynamic> updateData = {
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            if (clockInController.text.isNotEmpty) {
                              final newClockIn = _parseTime(
                                  clockInController.text, workDate);
                              updateData['clockIn'] = {
                                'timestamp': Timestamp.fromDate(newClockIn),
                                'location': clockIn?['location'],
                                'deviceInfo': 'Edited',
                              };
                            }

                            if (clockOutController.text.isNotEmpty) {
                              final newClockOut = _parseTime(
                                  clockOutController.text, workDate);
                              updateData['clockOut'] = {
                                'timestamp': Timestamp.fromDate(newClockOut),
                                'location': clockOut?['location'],
                                'deviceInfo': 'Edited',
                              };
                              updateData['status'] = 'completed';
                            } else {
                              updateData['clockOut'] = null;
                              updateData['status'] = 'working';
                            }

                            await doc.reference.update(updateData);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('勤怠を修正しました'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('エラー: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteAttendance(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('確認'),
          ],
        ),
        content: const Text('この勤怠記録を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              if (context.mounted) {
                Navigator.pop(context); // 確認ダイアログ
                Navigator.pop(context); // 編集ダイアログ
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('勤怠記録を削除しました'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  DateTime _parseTime(String timeStr, DateTime date) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
