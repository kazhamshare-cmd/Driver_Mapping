import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/shift.dart';
import '../../models/shift_change_request.dart';
import '../../models/staff_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/shift_service.dart';

/// バック明細情報
class BackDetailInfo {
  final String checkoutId;
  final String type; // 'pos' or 'table'
  final String customerName;
  final double total;
  final double shareRate;
  final double backRate;
  final double backAmount;
  final DateTime createdAt;
  final List<Map<String, dynamic>> items;

  BackDetailInfo({
    required this.checkoutId,
    required this.type,
    required this.customerName,
    required this.total,
    required this.shareRate,
    required this.backRate,
    required this.backAmount,
    required this.createdAt,
    required this.items,
  });
}

class MyShiftsScreen extends ConsumerStatefulWidget {
  const MyShiftsScreen({super.key});

  @override
  ConsumerState<MyShiftsScreen> createState() => _MyShiftsScreenState();
}

class _MyShiftsScreenState extends ConsumerState<MyShiftsScreen> with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final ShiftService _shiftService = ShiftService();
  bool _isCustomRange = false;
  int _closingDay = 1; // 締日（1日〜28日）
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setCurrentMonth();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 現在の月（1日〜末日）を設定
  void _setCurrentMonth() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _isCustomRange = false;
  }

  /// 締日ベースの期間を設定（例: 15日締めなら前月16日〜当月15日）
  void _setClosingDayPeriod(int closingDay, {int monthOffset = 0}) {
    final now = DateTime.now();
    final targetMonth = DateTime(now.year, now.month + monthOffset);

    if (closingDay == 1) {
      // 1日締め = 通常の月初〜月末
      _startDate = DateTime(targetMonth.year, targetMonth.month, 1);
      _endDate = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
    } else {
      // 例: 15日締め → 前月16日〜当月15日
      _startDate = DateTime(targetMonth.year, targetMonth.month - 1, closingDay + 1);
      _endDate = DateTime(targetMonth.year, targetMonth.month, closingDay, 23, 59, 59);
    }
    _closingDay = closingDay;
    _isCustomRange = false;
  }

  /// 前の期間へ
  void _previousPeriod() {
    if (_isCustomRange) {
      // カスタム期間の場合は同じ日数分戻る
      final duration = _endDate.difference(_startDate);
      _endDate = _startDate.subtract(const Duration(days: 1));
      _startDate = _endDate.subtract(duration);
    } else if (_closingDay == 1) {
      // 通常月
      _startDate = DateTime(_startDate.year, _startDate.month - 1, 1);
      _endDate = DateTime(_startDate.year, _startDate.month + 1, 0, 23, 59, 59);
    } else {
      // 締日ベース
      _startDate = DateTime(_startDate.year, _startDate.month - 1, _closingDay + 1);
      _endDate = DateTime(_endDate.year, _endDate.month - 1, _closingDay, 23, 59, 59);
    }
  }

  /// 次の期間へ
  void _nextPeriod() {
    if (_isCustomRange) {
      final duration = _endDate.difference(_startDate);
      _startDate = _endDate.add(const Duration(days: 1));
      _endDate = _startDate.add(duration);
    } else if (_closingDay == 1) {
      _startDate = DateTime(_startDate.year, _startDate.month + 1, 1);
      _endDate = DateTime(_startDate.year, _startDate.month + 1, 0, 23, 59, 59);
    } else {
      _startDate = DateTime(_startDate.year, _startDate.month + 1, _closingDay + 1);
      _endDate = DateTime(_endDate.year, _endDate.month + 1, _closingDay, 23, 59, 59);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final t = ref.watch(translationProvider);

    return staffUserAsync.when(
      data: (staffUser) {
        if (staffUser == null) {
          return Scaffold(
            body: Center(child: Text(t.text('pleaseLogin'))),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go('/');
              },
            ),
            title: Text(t.text('myShift')),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: t.text('periodSettings'),
                onPressed: () => _showPeriodSettingsDialog(t),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: t.text('shift'), icon: const Icon(Icons.schedule)),
                Tab(text: t.text('back') ?? 'バック', icon: const Icon(Icons.attach_money)),
              ],
            ),
          ),
          body: Column(
            children: [
              // 期間選択ヘッダー
              _buildPeriodSelector(t),
              // タブビュー
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // シフトタブ
                    Column(
                      children: [
                        _buildMonthlySummary(staffUser),
                        const Divider(height: 1),
                        Expanded(child: _buildShiftsList(staffUser)),
                      ],
                    ),
                    // バックタブ
                    _buildBackTab(staffUser),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('${t.text('errorOccurred')}: $error')),
      ),
    );
  }

  /// 期間選択ヘッダー
  Widget _buildPeriodSelector(AppTranslations t) {
    final dateFormat = DateFormat('M/d');
    final periodText = '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _previousPeriod();
              });
            },
          ),
          InkWell(
            onTap: () => _showCustomDateRangePicker(t),
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
                    periodText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isCustomRange) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.text('custom'),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _nextPeriod();
              });
            },
          ),
          // 今月に戻る
          if (_isCustomRange || _startDate.month != DateTime.now().month)
            IconButton(
              icon: const Icon(Icons.today),
              tooltip: t.text('thisMonth'),
              onPressed: () {
                setState(() {
                  _setCurrentMonth();
                });
              },
            ),
        ],
      ),
    );
  }

  /// 期間設定ダイアログ
  void _showPeriodSettingsDialog(AppTranslations t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.text('periodSettings')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.text('closingDay'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildClosingDayChip(1, t.text('endOfMonth'), t),
                  _buildClosingDayChip(10, '10${t.text('dayClosing')}', t),
                  _buildClosingDayChip(15, '15${t.text('dayClosing')}', t),
                  _buildClosingDayChip(20, '20${t.text('dayClosing')}', t),
                  _buildClosingDayChip(25, '25${t.text('dayClosing')}', t),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                t.text('quickSelect'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(t.text('thisMonth')),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _setCurrentMonth();
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(t.text('lastMonth')),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _setClosingDayPeriod(_closingDay, monthOffset: -1);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(t.text('customRange')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomDateRangePicker(t);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.text('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingDayChip(int day, String label, AppTranslations t) {
    final isSelected = _closingDay == day && !_isCustomRange;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          Navigator.pop(context);
          setState(() {
            _setClosingDayPeriod(day);
          });
        }
      },
    );
  }

  /// カスタム日付範囲選択
  Future<void> _showCustomDateRangePicker(AppTranslations t) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('ja', 'JP'),
      helpText: t.text('selectPeriod'),
      cancelText: t.text('cancel'),
      confirmText: t.text('confirm'),
      saveText: t.text('confirm'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _isCustomRange = true;
      });
    }
  }

  Widget _buildMonthlySummary(StaffUser staffUser) {
    final t = ref.read(translationProvider);

    return StreamBuilder<List<Shift>>(
      stream: _shiftService.getMyShifts(staffUser.id, _startDate, _endDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final shifts = snapshot.data!;
        final approvedShifts = shifts.where((s) => s.status == ShiftStatus.approved).toList();
        final pendingShifts = shifts.where((s) => s.status == ShiftStatus.pending).toList();

        int approvedMinutes = 0;
        int pendingMinutes = 0;

        for (final shift in approvedShifts) {
          approvedMinutes += shift.workMinutes;
        }

        for (final shift in pendingShifts) {
          pendingMinutes += shift.workMinutes;
        }

        final hourlyWage = staffUser.hourlyWage;
        final approvedEarnings = (approvedMinutes / 60.0) * hourlyWage;
        final pendingEarnings = (pendingMinutes / 60.0) * hourlyWage;

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  t.text('confirmedShift'),
                  '${(approvedMinutes / 60.0).toStringAsFixed(1)}${t.text('hours')}',
                  '¥${approvedEarnings.toStringAsFixed(0)}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  t.text('reservationPending'),
                  '${(pendingMinutes / 60.0).toStringAsFixed(1)}${t.text('hours')}',
                  '¥${pendingEarnings.toStringAsFixed(0)}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String hours, String earnings, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hours,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            earnings,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftsList(StaffUser staffUser) {
    final t = ref.read(translationProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return StreamBuilder<List<Shift>>(
      stream: _shiftService.getMyShifts(staffUser.id, _startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${t.text('errorOccurred')}: ${snapshot.error}'));
        }

        final shifts = snapshot.data ?? [];

        if (shifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: isTablet ? 80 : 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  t.text('noShiftsThisMonth'),
                  style: TextStyle(fontSize: isTablet ? 18 : 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // 日付でグループ化
        final groupedShifts = <String, List<Shift>>{};
        for (final shift in shifts) {
          final dateKey = DateFormat('yyyy-MM-dd').format(shift.shiftDate);
          groupedShifts.putIfAbsent(dateKey, () => []);
          groupedShifts[dateKey]!.add(shift);
        }

        // タブレットの場合はGridView、スマホの場合はListView
        if (isTablet) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: screenWidth > 900 ? 3 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.0,
            ),
            itemCount: groupedShifts.length,
            itemBuilder: (context, index) {
              final dateKey = groupedShifts.keys.elementAt(index);
              final dayShifts = groupedShifts[dateKey]!;
              final date = dayShifts.first.shiftDate;

              return _buildShiftCard(date, dayShifts, staffUser, t, isTablet: true);
            },
          );
        }

        return ListView.builder(
          itemCount: groupedShifts.length,
          itemBuilder: (context, index) {
            final dateKey = groupedShifts.keys.elementAt(index);
            final dayShifts = groupedShifts[dateKey]!;
            final date = dayShifts.first.shiftDate;

            return _buildShiftCard(date, dayShifts, staffUser, t);
          },
        );
      },
    );
  }

  Widget _buildShiftCard(DateTime date, List<Shift> dayShifts, StaffUser staffUser, AppTranslations t, {bool isTablet = false}) {
            return Card(
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 8, vertical: isTablet ? 0 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('M/d (E)').format(date),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${dayShifts.length}${t.text('shiftCount')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayShifts.map((shift) => _buildShiftTile(shift, staffUser)),
                ],
              ),
            );
  }

  Widget _buildShiftTile(Shift shift, StaffUser staffUser) {
    final t = ref.read(translationProvider);
    Color statusColor;
    String statusText;

    switch (shift.status) {
      case ShiftStatus.approved:
        statusColor = Colors.green;
        statusText = t.text('shiftApproved');
        break;
      case ShiftStatus.rejected:
        statusColor = Colors.red;
        statusText = t.text('shiftRejected');
        break;
      default:
        statusColor = Colors.orange;
        statusText = t.text('reservationPending');
    }

    final hourlyWage = staffUser.hourlyWage;
    final earnings = shift.workHours * hourlyWage;

    // 未来のシフトのみ変更希望可能
    final canRequestChange = shift.shiftDate.isAfter(DateTime.now()) &&
                             shift.status == ShiftStatus.approved;

    return ListTile(
      onTap: canRequestChange ? () => _showShiftChangeDialog(shift, staffUser, t) : null,
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, color: statusColor, size: 24),
            const SizedBox(height: 2),
            Text(
              '${shift.workHours.toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${shift.startTime} - ${shift.endTime}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (canRequestChange)
            Icon(Icons.edit_calendar, size: 18, color: Colors.grey[400]),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${t.text('breakLabel')}: ${shift.breakMinutes}${t.text('elapsedMin')}'),
          if (shift.note != null && shift.note!.isNotEmpty)
            Text(
              shift.note!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${earnings.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// シフト変更希望ダイアログを表示
  void _showShiftChangeDialog(Shift shift, StaffUser staffUser, AppTranslations t) {
    ShiftChangeType selectedType = ShiftChangeType.swap;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('シフト変更希望')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // シフト情報表示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('M/d (E)').format(shift.shiftDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${shift.startTime} - ${shift.endTime}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 変更タイプ選択
                const Text(
                  '変更タイプ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.swap_horiz, size: 16),
                          SizedBox(width: 4),
                          Text('交代希望'),
                        ],
                      ),
                      selected: selectedType == ShiftChangeType.swap,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedType = ShiftChangeType.swap);
                        }
                      },
                      selectedColor: Colors.orange.shade100,
                    ),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.event_busy, size: 16),
                          SizedBox(width: 4),
                          Text('休み希望'),
                        ],
                      ),
                      selected: selectedType == ShiftChangeType.dayOff,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => selectedType = ShiftChangeType.dayOff);
                        }
                      },
                      selectedColor: Colors.red.shade100,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedType == ShiftChangeType.swap
                      ? '※ 交代希望を出すと、シフト募集に自動反映されます'
                      : '※ 休み希望は管理者の承認が必要です',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                // 理由入力
                const Text(
                  '理由（必須）',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: selectedType == ShiftChangeType.swap
                        ? '例: 私用のため交代をお願いしたいです'
                        : '例: 体調不良のため休ませてください',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.text('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('理由を入力してください'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _submitShiftChangeRequest(
                  shift,
                  staffUser,
                  selectedType,
                  reasonController.text.trim(),
                  t,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedType == ShiftChangeType.swap
                    ? Colors.orange
                    : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(selectedType == ShiftChangeType.swap
                  ? '交代希望を出す'
                  : '休み希望を出す'),
            ),
          ],
        ),
      ),
    );
  }

  /// シフト変更希望を送信
  Future<void> _submitShiftChangeRequest(
    Shift shift,
    StaffUser staffUser,
    ShiftChangeType changeType,
    String reason,
    AppTranslations t,
  ) async {
    try {
      final employeeName = '${staffUser.lastName} ${staffUser.firstName}'.trim();

      await _shiftService.createShiftChangeRequest(
        shopId: staffUser.shopId,
        shift: shift,
        employeeId: staffUser.id,
        employeeName: employeeName.isNotEmpty ? employeeName : 'スタッフ',
        changeType: changeType,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changeType == ShiftChangeType.swap
                ? '交代希望を出しました。シフト募集に反映されます。'
                : '休み希望を出しました。管理者の承認をお待ちください。'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// バックタブを構築
  Widget _buildBackTab(StaffUser staffUser) {
    final t = ref.read(translationProvider);

    return FutureBuilder<List<BackDetailInfo>>(
      future: _fetchBackDetails(staffUser),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${t.text('errorOccurred')}: ${snapshot.error}'));
        }

        final backDetails = snapshot.data ?? [];
        double totalBackAmount = backDetails.fold(0, (sum, item) => sum + item.backAmount);

        return Column(
          children: [
            // サマリー
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.text('totalBack') ?? '合計バック',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥${totalBackAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${backDetails.length}${t.text('salesCount') ?? '件'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        t.text('confirmedSales') ?? '確定済み販売',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // バック明細リスト
            Expanded(
              child: backDetails.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_money, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            t.text('noBackData') ?? 'バックデータがありません',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '会計時に担当者として選択された場合に\nバックが記録されます',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        itemCount: backDetails.length,
                        itemBuilder: (context, index) {
                          final item = backDetails[index];
                          return _buildBackDetailTile(item, t);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// バック明細を取得（posCheckouts + checkouts）
  /// 承認済み（approved）のバックのみ表示
  Future<List<BackDetailInfo>> _fetchBackDetails(StaffUser staffUser) async {
    final List<BackDetailInfo> results = [];
    final firestore = FirebaseFirestore.instance;

    // 1. POS会計からバック情報を取得
    final posCheckoutsSnapshot = await firestore
        .collection('posCheckouts')
        .where('shopId', isEqualTo: staffUser.shopId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    for (final doc in posCheckoutsSnapshot.docs) {
      final data = doc.data();
      final salesStaff = data['salesStaff'] as List<dynamic>? ?? [];

      for (final staff in salesStaff) {
        // 自分のバック && 承認済みのみ
        if (staff['staffId'] == staffUser.id && staff['backStatus'] == 'approved') {
          final total = (data['total'] ?? 0).toDouble();
          final shareRate = (staff['shareRate'] ?? 100).toDouble() / 100;
          final backRate = (staff['backRate'] ?? 0.5).toDouble();
          final backAmount = total * shareRate * backRate;

          results.add(BackDetailInfo(
            checkoutId: doc.id,
            type: 'pos',
            customerName: data['customerName'] ?? '匿名',
            total: total,
            shareRate: shareRate * 100,
            backRate: backRate * 100,
            backAmount: backAmount,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            items: List<Map<String, dynamic>>.from(data['items'] ?? []),
          ));
        }
      }
    }

    // 2. テーブル会計からバック情報を取得
    final checkoutsSnapshot = await firestore
        .collection('checkouts')
        .where('shopId', isEqualTo: staffUser.shopId)
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    for (final doc in checkoutsSnapshot.docs) {
      final data = doc.data();
      final salesStaff = data['salesStaff'] as List<dynamic>? ?? [];

      for (final staff in salesStaff) {
        // 自分のバック && 承認済みのみ
        if (staff['staffId'] == staffUser.id && staff['backStatus'] == 'approved') {
          final total = (data['total'] ?? 0).toDouble();
          final shareRate = (staff['shareRate'] ?? 100).toDouble() / 100;
          final backRate = (staff['backRate'] ?? 0.5).toDouble();
          final backAmount = total * shareRate * backRate;

          results.add(BackDetailInfo(
            checkoutId: doc.id,
            type: 'table',
            customerName: data['tableName'] ?? 'テーブル${data['tableNumber'] ?? ''}',
            total: total,
            shareRate: shareRate * 100,
            backRate: backRate * 100,
            backAmount: backAmount,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            items: [],
          ));
        }
      }
    }

    // 日付でソート（新しい順）
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// バック明細のタイル
  Widget _buildBackDetailTile(BackDetailInfo item, AppTranslations t) {
    final isPos = item.type == 'pos';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPos ? Icons.point_of_sale : Icons.table_restaurant,
                size: 20,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 2),
              Text(
                '¥${item.backAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          item.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('M/d (E) HH:mm').format(item.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '売上 ¥${item.total.toStringAsFixed(0)} × ${item.shareRate.toStringAsFixed(0)}% × ${item.backRate.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPos ? Colors.blue.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPos ? 'POS' : 'テーブル',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isPos ? Colors.blue.shade700 : Colors.orange.shade700,
            ),
          ),
        ),
        children: isPos && item.items.isNotEmpty
            ? [
                Container(
                  color: Colors.grey.shade50,
                  child: Column(
                    children: item.items.map((menuItem) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.restaurant_menu, size: 18),
                        title: Text(
                          menuItem['menuName'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: Text(
                          '×${menuItem['quantity']} ¥${(menuItem['price'] * menuItem['quantity']).toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}
