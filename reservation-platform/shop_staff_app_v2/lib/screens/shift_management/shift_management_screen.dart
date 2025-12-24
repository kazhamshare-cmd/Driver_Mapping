import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/shift.dart';
import '../../models/shift_change_request.dart';
import '../../services/shift_service.dart';

/// シフト管理画面（店長・オーナー向け）
class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShiftService _shiftService = ShiftService();
  DateTime _selectedDate = DateTime.now();
  DateTime _weekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setWeekStart();
  }

  void _setWeekStart() {
    // 月曜始まりに設定
    final now = DateTime.now();
    final weekday = now.weekday;
    _weekStart = now.subtract(Duration(days: weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;
    final shopId = staffUser?.shopId;

    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('シフト管理'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('シフト管理'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '週間シフト', icon: Icon(Icons.calendar_view_week)),
            Tab(text: '変更希望', icon: Icon(Icons.swap_horiz)),
            Tab(text: 'シフト募集', icon: Icon(Icons.campaign)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyShiftTab(shopId),
          _buildChangeRequestsTab(shopId),
          _buildRecruitmentTab(shopId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateShiftDialog(context, shopId),
        icon: const Icon(Icons.add),
        label: const Text('シフト作成'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// 週間シフトタブ
  Widget _buildWeeklyShiftTab(String shopId) {
    return Column(
      children: [
        // 週選択ヘッダー
        _buildWeekSelector(),
        const Divider(height: 1),
        // 週間カレンダー
        Expanded(
          child: _buildWeeklyCalendar(shopId),
        ),
      ],
    );
  }

  Widget _buildWeekSelector() {
    final dateFormat = DateFormat('M/d');
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final periodText =
        '${dateFormat.format(_weekStart)} - ${dateFormat.format(weekEnd)}';

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
                _weekStart = _weekStart.subtract(const Duration(days: 7));
              });
            },
          ),
          Container(
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
                  periodText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _weekStart = _weekStart.add(const Duration(days: 7));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今週',
            onPressed: () {
              setState(() {
                _setWeekStart();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendar(String shopId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getWeeklyShifts(shopId),
      builder: (context, shiftsSnapshot) {
        if (shiftsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _getEmployees(shopId),
          builder: (context, employeesSnapshot) {
            if (!employeesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final employees = employeesSnapshot.data!.docs;
            final shifts = shiftsSnapshot.data?.docs ?? [];

            // 従業員ごとにシフトをグループ化
            final shiftsByEmployee = <String, List<Map<String, dynamic>>>{};
            for (final shift in shifts) {
              final data = shift.data() as Map<String, dynamic>;
              final employeeId = data['employeeId'] as String;
              shiftsByEmployee.putIfAbsent(employeeId, () => []);
              shiftsByEmployee[employeeId]!.add({
                'id': shift.id,
                ...data,
              });
            }

            if (employees.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('スタッフがいません'),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 8,
                  horizontalMargin: 8,
                  headingRowHeight: 48,
                  dataRowMinHeight: 60,
                  dataRowMaxHeight: 80,
                  columns: [
                    const DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: Text('スタッフ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    ...List.generate(7, (index) {
                      final date = _weekStart.add(Duration(days: index));
                      final isToday = _isSameDay(date, DateTime.now());
                      return DataColumn(
                        label: Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isWeekend(date)
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isToday ? Colors.blue : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  rows: employees.map((employeeDoc) {
                    final employee =
                        employeeDoc.data() as Map<String, dynamic>;
                    final employeeId = employeeDoc.id;
                    final employeeShifts = shiftsByEmployee[employeeId] ?? [];
                    final name =
                        '${employee['lastName'] ?? ''} ${employee['firstName'] ?? ''}'
                            .trim();
                    final role = employee['role'] ?? 'staff';

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isNotEmpty ? name : '名前なし',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                _buildRoleBadge(role),
                              ],
                            ),
                          ),
                        ),
                        ...List.generate(7, (index) {
                          final date = _weekStart.add(Duration(days: index));
                          final dayShifts = employeeShifts.where((s) {
                            final shiftDate =
                                (s['shiftDate'] as Timestamp).toDate();
                            return _isSameDay(shiftDate, date);
                          }).toList();

                          return DataCell(
                            _buildShiftCell(dayShifts, date, employeeId, shopId,
                                name.isNotEmpty ? name : '名前なし'),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShiftCell(List<Map<String, dynamic>> shifts, DateTime date,
      String employeeId, String shopId, String employeeName) {
    if (shifts.isEmpty) {
      return InkWell(
        onTap: () => _showAddShiftForEmployee(
            context, shopId, employeeId, employeeName, date),
        child: Container(
          width: 70,
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(Icons.add, color: Colors.grey.shade400, size: 20),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showShiftDetailDialog(context, shifts.first, employeeName),
      child: Container(
        width: 70,
        height: 60,
        decoration: BoxDecoration(
          color: _getShiftStatusColor(shifts.first['status']).withOpacity(0.1),
          border: Border.all(
            color: _getShiftStatusColor(shifts.first['status']),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${shifts.first['startTime']}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              '${shifts.first['endTime']}',
              style: const TextStyle(fontSize: 10),
            ),
            if (shifts.length > 1)
              Text(
                '+${shifts.length - 1}',
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Color _getShiftStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  Stream<QuerySnapshot> _getWeeklyShifts(String shopId) {
    final weekEnd = _weekStart.add(const Duration(days: 7));
    return FirebaseFirestore.instance
        .collection('shifts')
        .where('shopId', isEqualTo: shopId)
        .where('shiftDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_weekStart))
        .where('shiftDate', isLessThan: Timestamp.fromDate(weekEnd))
        .snapshots();
  }

  Stream<QuerySnapshot> _getEmployees(String shopId) {
    return FirebaseFirestore.instance
        .collection('employees')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// 変更希望タブ
  Widget _buildChangeRequestsTab(String shopId) {
    return StreamBuilder<List<ShiftChangeRequest>>(
      stream: _shiftService.getShopShiftChangeRequests(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];
        final pendingRequests =
            requests.where((r) => r.status == ShiftChangeStatus.pending).toList();
        final processedRequests =
            requests.where((r) => r.status != ShiftChangeStatus.pending).toList();

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('変更希望はありません'),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pendingRequests.isNotEmpty) ...[
              _buildSectionHeader('未処理', pendingRequests.length, Colors.orange),
              ...pendingRequests.map((req) => _buildChangeRequestCard(req, true)),
              const SizedBox(height: 24),
            ],
            if (processedRequests.isNotEmpty) ...[
              _buildSectionHeader('処理済み', processedRequests.length, Colors.grey),
              ...processedRequests.map((req) => _buildChangeRequestCard(req, false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeRequestCard(ShiftChangeRequest request, bool isPending) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (request.status) {
      case ShiftChangeStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '承認済み';
        break;
      case ShiftChangeStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = '却下';
        break;
      case ShiftChangeStatus.covered:
        statusColor = Colors.blue;
        statusIcon = Icons.swap_horiz;
        statusText = '交代確定';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = '未処理';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: request.changeType == ShiftChangeType.swap
                        ? Colors.orange.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        request.changeType == ShiftChangeType.swap
                            ? Icons.swap_horiz
                            : Icons.event_busy,
                        size: 14,
                        color: request.changeType == ShiftChangeType.swap
                            ? Colors.orange
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.changeType == ShiftChangeType.swap
                            ? '交代希望'
                            : '休み希望',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: request.changeType == ShiftChangeType.swap
                              ? Colors.orange
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    request.employeeName.isNotEmpty
                        ? request.employeeName[0]
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${DateFormat('M/d (E)').format(request.shiftDate)} ${request.startTime} - ${request.endTime}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.message, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.reason,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _rejectChangeRequest(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('却下'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _approveChangeRequest(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('承認'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveChangeRequest(ShiftChangeRequest request) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    try {
      await _shiftService.approveShiftChangeRequest(
        request.id,
        reviewedByStaffId: staffUser.id,
        reviewedByStaffName:
            '${staffUser.lastName} ${staffUser.firstName}'.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('変更希望を承認しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectChangeRequest(ShiftChangeRequest request) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('変更希望を却下'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('この変更希望を却下しますか？'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '却下理由（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('却下'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _shiftService.rejectShiftChangeRequest(
        request.id,
        reviewedByStaffId: staffUser.id,
        reviewedByStaffName:
            '${staffUser.lastName} ${staffUser.firstName}'.trim(),
        reviewNote:
            noteController.text.isEmpty ? null : noteController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('変更希望を却下しました'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// シフト募集タブ
  Widget _buildRecruitmentTab(String shopId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shiftRequests')
          .where('shopId', isEqualTo: shopId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        final openRequests =
            requests.where((r) => r['status'] == 'open').toList();
        final closedRequests =
            requests.where((r) => r['status'] != 'open').toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('シフト募集はありません'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showCreateRecruitmentDialog(context, shopId),
                  icon: const Icon(Icons.add),
                  label: const Text('新規募集を作成'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 新規募集ボタン
            ElevatedButton.icon(
              onPressed: () => _showCreateRecruitmentDialog(context, shopId),
              icon: const Icon(Icons.add),
              label: const Text('新規募集を作成'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            if (openRequests.isNotEmpty) ...[
              _buildSectionHeader('募集中', openRequests.length, Colors.green),
              ...openRequests.map((req) => _buildRecruitmentCard(req, true)),
              const SizedBox(height: 24),
            ],
            if (closedRequests.isNotEmpty) ...[
              _buildSectionHeader('終了', closedRequests.length, Colors.grey),
              ...closedRequests.map((req) => _buildRecruitmentCard(req, false)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecruitmentCard(DocumentSnapshot doc, bool isOpen) {
    final data = doc.data() as Map<String, dynamic>;
    final newShift = data['newShift'] as Map<String, dynamic>?;
    if (newShift == null) return const SizedBox.shrink();

    final shiftDate = (newShift['shiftDate'] as Timestamp).toDate();
    final responses = data['responses'] as List<dynamic>? ?? [];
    final requiredCount = newShift['requiredStaffCount'] ?? 1;
    final isShiftChange = data['requestType'] == 'shift_change';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRecruitmentDetailDialog(context, doc),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isShiftChange)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '交代募集: ${data['originalEmployeeName'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('M/d').format(shiftDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOpen ? Colors.green : Colors.grey,
                          ),
                        ),
                        Text(
                          DateFormat('(E)').format(shiftDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOpen
                                ? Colors.green.shade700
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${newShift['startTime']} - ${newShift['endTime']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${responses.length}/$requiredCount人応募',
                              style: TextStyle(
                                color: responses.length >= requiredCount
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateShiftDialog(BuildContext context, String shopId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.blue),
              title: const Text('スタッフにシフトを割り当て'),
              subtitle: const Text('特定のスタッフにシフトを追加'),
              onTap: () {
                Navigator.pop(context);
                _showAssignShiftDialog(context, shopId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign, color: Colors.orange),
              title: const Text('シフト募集を作成'),
              subtitle: const Text('スタッフから応募を募る'),
              onTap: () {
                Navigator.pop(context);
                _showCreateRecruitmentDialog(context, shopId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAssignShiftDialog(BuildContext context, String shopId) {
    final dateController = TextEditingController();
    final startTimeController = TextEditingController(text: '10:00');
    final endTimeController = TextEditingController(text: '18:00');
    final breakController = TextEditingController(text: '60');
    DateTime? selectedDate;
    String? selectedEmployeeId;
    String? selectedEmployeeName;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('シフト割り当て'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // スタッフ選択
                    StreamBuilder<QuerySnapshot>(
                      stream: _getEmployees(shopId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final employees = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: selectedEmployeeId,
                          decoration: const InputDecoration(
                            labelText: 'スタッフ *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: employees.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name =
                                '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                                    .trim();
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(name.isNotEmpty ? name : '名前なし'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedEmployeeId = value;
                              final doc = employees
                                  .firstWhere((e) => e.id == value);
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              selectedEmployeeName =
                                  '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'
                                      .trim();
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // 日付選択
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: '日付 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                            dateController.text =
                                DateFormat('yyyy/M/d (E)').format(date);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startTimeController,
                            decoration: const InputDecoration(
                              labelText: '開始時間',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('〜'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: endTimeController,
                            decoration: const InputDecoration(
                              labelText: '終了時間',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: breakController,
                      decoration: const InputDecoration(
                        labelText: '休憩時間（分）',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.free_breakfast),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
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
                          if (selectedEmployeeId == null ||
                              selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('スタッフと日付を選択してください'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('shifts')
                                .add({
                              'shopId': shopId,
                              'employeeId': selectedEmployeeId,
                              'shiftDate': Timestamp.fromDate(selectedDate!),
                              'startTime': startTimeController.text,
                              'endTime': endTimeController.text,
                              'breakMinutes':
                                  int.tryParse(breakController.text) ?? 60,
                              'shiftType': 'regular',
                              'status': 'approved',
                              'createdAt': Timestamp.now(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('シフトを作成しました'),
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
                      : const Text('作成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddShiftForEmployee(BuildContext context, String shopId,
      String employeeId, String employeeName, DateTime date) {
    final startTimeController = TextEditingController(text: '10:00');
    final endTimeController = TextEditingController(text: '18:00');
    final breakController = TextEditingController(text: '60');
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
                  const Icon(Icons.schedule, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('シフト追加'),
                        Text(
                          '$employeeName - ${DateFormat('M/d (E)').format(date)}',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: startTimeController,
                          decoration: const InputDecoration(
                            labelText: '開始',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('〜'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: endTimeController,
                          decoration: const InputDecoration(
                            labelText: '終了',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: breakController,
                    decoration: const InputDecoration(
                      labelText: '休憩（分）',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                            await FirebaseFirestore.instance
                                .collection('shifts')
                                .add({
                              'shopId': shopId,
                              'employeeId': employeeId,
                              'shiftDate': Timestamp.fromDate(date),
                              'startTime': startTimeController.text,
                              'endTime': endTimeController.text,
                              'breakMinutes':
                                  int.tryParse(breakController.text) ?? 60,
                              'shiftType': 'regular',
                              'status': 'approved',
                              'createdAt': Timestamp.now(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('シフトを作成しました'),
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
                      : const Text('追加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShiftDetailDialog(
      BuildContext context, Map<String, dynamic> shift, String employeeName) {
    final shiftDate = (shift['shiftDate'] as Timestamp).toDate();
    final status = shift['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('シフト詳細'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person, 'スタッフ', employeeName),
            _buildDetailRow(Icons.calendar_today, '日付',
                DateFormat('yyyy/M/d (E)').format(shiftDate)),
            _buildDetailRow(Icons.access_time, '時間',
                '${shift['startTime']} - ${shift['endTime']}'),
            _buildDetailRow(
                Icons.free_breakfast, '休憩', '${shift['breakMinutes']}分'),
            Row(
              children: [
                Icon(Icons.check_circle, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text('ステータス: '),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getShiftStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'approved'
                        ? '確定'
                        : status == 'rejected'
                            ? '却下'
                            : '未承認',
                    style: TextStyle(
                      color: _getShiftStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (status == 'pending') ...[
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('shifts')
                    .doc(shift['id'])
                    .update({'status': 'rejected'});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('却下', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('shifts')
                    .doc(shift['id'])
                    .update({'status': 'approved'});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('承認'),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateRecruitmentDialog(BuildContext context, String shopId) {
    final dateController = TextEditingController();
    final startTimeController = TextEditingController(text: '10:00');
    final endTimeController = TextEditingController(text: '18:00');
    final breakController = TextEditingController(text: '60');
    final countController = TextEditingController(text: '1');
    final messageController = TextEditingController();
    DateTime? selectedDate;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('シフト募集'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: '日付 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                            dateController.text =
                                DateFormat('yyyy/M/d (E)').format(date);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startTimeController,
                            decoration: const InputDecoration(
                              labelText: '開始',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('〜'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: endTimeController,
                            decoration: const InputDecoration(
                              labelText: '終了',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: breakController,
                            decoration: const InputDecoration(
                              labelText: '休憩（分）',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: countController,
                            decoration: const InputDecoration(
                              labelText: '募集人数',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'メッセージ（任意）',
                        border: OutlineInputBorder(),
                        hintText: '例: 繁忙期のため急募！',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
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
                          if (selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('日付を選択してください'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('shiftRequests')
                                .add({
                              'shopId': shopId,
                              'requestType': 'recruitment',
                              'newShift': {
                                'shiftDate': Timestamp.fromDate(selectedDate!),
                                'startTime': startTimeController.text,
                                'endTime': endTimeController.text,
                                'breakMinutes':
                                    int.tryParse(breakController.text) ?? 60,
                                'requiredStaffCount':
                                    int.tryParse(countController.text) ?? 1,
                              },
                              'isOpenToAll': true,
                              'status': 'open',
                              'responses': [],
                              'message': messageController.text.isEmpty
                                  ? null
                                  : messageController.text.trim(),
                              'createdAt': Timestamp.now(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('シフト募集を作成しました'),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('募集開始'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecruitmentDetailDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final newShift = data['newShift'] as Map<String, dynamic>;
    final shiftDate = (newShift['shiftDate'] as Timestamp).toDate();
    final responses = List<Map<String, dynamic>>.from(data['responses'] ?? []);
    final isOpen = data['status'] == 'open';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.campaign, color: isOpen ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Text(isOpen ? '募集中' : '募集終了'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.calendar_today, '日付',
                  DateFormat('yyyy/M/d (E)').format(shiftDate)),
              _buildDetailRow(Icons.access_time, '時間',
                  '${newShift['startTime']} - ${newShift['endTime']}'),
              _buildDetailRow(
                  Icons.people, '募集人数', '${newShift['requiredStaffCount']}人'),
              const SizedBox(height: 16),
              const Text(
                '応募者',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (responses.isEmpty)
                Text(
                  'まだ応募がありません',
                  style: TextStyle(color: Colors.grey[600]),
                )
              else
                ...responses.map((r) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (r['employeeName'] as String? ?? '?')[0],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(r['employeeName'] ?? '名前なし'),
                      subtitle: Text(
                        DateFormat('M/d HH:mm').format(
                            (r['respondedAt'] as Timestamp).toDate()),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isOpen
                          ? ElevatedButton(
                              onPressed: () =>
                                  _assignFromRecruitment(doc, r, context),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(60, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('確定', style: TextStyle(fontSize: 12)),
                            )
                          : null,
                    )),
            ],
          ),
        ),
        actions: [
          if (isOpen)
            TextButton(
              onPressed: () async {
                await doc.reference.update({'status': 'closed'});
                if (context.mounted) Navigator.pop(context);
              },
              child:
                  const Text('募集終了', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignFromRecruitment(
      DocumentSnapshot doc, Map<String, dynamic> response, BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final newShift = data['newShift'] as Map<String, dynamic>;
    final employeeId = response['employeeId'] as String;
    final shopId = data['shopId'] as String;

    try {
      // シフトを作成
      await FirebaseFirestore.instance.collection('shifts').add({
        'shopId': shopId,
        'employeeId': employeeId,
        'shiftDate': newShift['shiftDate'],
        'startTime': newShift['startTime'],
        'endTime': newShift['endTime'],
        'breakMinutes': newShift['breakMinutes'],
        'shiftType': 'regular',
        'status': 'approved',
        'createdAt': Timestamp.now(),
      });

      // 募集をクローズ
      await doc.reference.update({'status': 'closed'});

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${response['employeeName']}さんにシフトを確定しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
