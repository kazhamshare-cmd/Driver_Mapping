import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/shift_request.dart';
import '../../models/staff_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/shift_service.dart';

class ShiftRequestsScreen extends ConsumerWidget {
  const ShiftRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            title: Text(t.text('shiftRecruitment')),
          ),
          body: _buildRequestsList(context, staffUser, ref),
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

  Widget _buildRequestsList(BuildContext context, StaffUser staffUser, WidgetRef ref) {
    final shiftService = ShiftService();
    final t = ref.read(translationProvider);

    return StreamBuilder<List<ShiftRequest>>(
      stream: shiftService.getOpenShiftRequests(staffUser.shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${t.text('errorOccurred')}: ${snapshot.error}'));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.work_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  t.text('noOpenShifts'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(context, request, staffUser, ref);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, ShiftRequest request, StaffUser staffUser, WidgetRef ref) {
    if (request.newShift == null) return const SizedBox.shrink();
    final t = ref.read(translationProvider);

    final newShift = request.newShift!;
    final hasResponded = request.hasResponded(staffUser.id);
    final hourlyWage = staffUser.hourlyWage;
    final estimatedEarnings = newShift.workHours * hourlyWage;
    final isShiftChange = request.isShiftChange;
    // 自分が出した交代希望には応募できない
    final isOwnRequest = request.originalEmployeeId == staffUser.id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _showRequestDetail(context, request, staffUser, ref);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // シフト交代募集バッジ
              if (isShiftChange) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '交代募集：${request.originalEmployeeName ?? ''}さん',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // ヘッダー行
              Row(
                children: [
                  // 日付バッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isShiftChange ? Colors.orange.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('M/d').format(newShift.shiftDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isShiftChange ? Colors.orange : Colors.blue,
                          ),
                        ),
                        Text(
                          DateFormat('(E)').format(newShift.shiftDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isShiftChange ? Colors.orange.shade700 : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 時間と休憩
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${newShift.startTime} - ${newShift.endTime}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${t.text('breakLabel')}: ${newShift.breakMinutes}${t.text('elapsedMin')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${t.text('workTimeLabel')}: ${newShift.workHours.toStringAsFixed(1)}${t.text('hours')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 募集人数と応募状況
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          request.getResponseStatus(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (newShift.position != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        newShift.position!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // 見込み給与
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '¥${estimatedEarnings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (request.message != null && request.message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.message!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              // アクションボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isOwnRequest)
                    // 自分が出した交代希望
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'あなたの交代募集です',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  else if (hasResponded)
                    OutlinedButton.icon(
                      onPressed: () {
                        _cancelApplication(context, request, staffUser, ref);
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                      label: Text(t.text('cancelApplication')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        _applyForShift(context, request, staffUser, ref);
                      },
                      icon: Icon(
                        isShiftChange ? Icons.swap_horiz : Icons.check_circle,
                        size: 18,
                      ),
                      label: Text(isShiftChange ? '代わりに出勤する' : t.text('applyForShift')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isShiftChange ? Colors.orange : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetail(BuildContext context, ShiftRequest request, StaffUser staffUser, WidgetRef ref) {
    final t = ref.read(translationProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final newShift = request.newShift!;
        final hasResponded = request.hasResponded(staffUser.id);
        final hourlyWage = staffUser.hourlyWage;
        final estimatedEarnings = newShift.workHours * hourlyWage;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    t.text('shiftRecruitmentDetails'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(
                    Icons.calendar_today,
                    t.text('dateLabel'),
                    DateFormat('yyyy/M/d (E)').format(newShift.shiftDate),
                  ),
                  _buildDetailRow(
                    Icons.access_time,
                    t.text('workTimeLabel'),
                    '${newShift.startTime} - ${newShift.endTime}',
                  ),
                  _buildDetailRow(
                    Icons.free_breakfast,
                    t.text('breakLabel'),
                    '${newShift.breakMinutes}${t.text('elapsedMin')}',
                  ),
                  _buildDetailRow(
                    Icons.timer,
                    t.text('actualWorkTime'),
                    '${newShift.workHours.toStringAsFixed(1)}${t.text('hours')}',
                  ),
                  _buildDetailRow(
                    Icons.attach_money,
                    t.text('estimatedPay'),
                    '¥${estimatedEarnings.toStringAsFixed(0)}',
                  ),
                  if (newShift.position != null)
                    _buildDetailRow(
                      Icons.work,
                      t.text('positionLabel'),
                      newShift.position!,
                    ),
                  _buildDetailRow(
                    Icons.people,
                    t.text('recruitmentCount'),
                    '${newShift.requiredStaffCount}${t.text('people')} (${request.responses.length}${t.text('currentApplicants')})',
                  ),
                  if (request.message != null && request.message!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      t.text('messageLabel'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        request.message!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: hasResponded
                        ? OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _cancelApplication(context, request, staffUser, ref);
                            },
                            icon: const Icon(Icons.cancel),
                            label: Text(t.text('cancelApplication')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyForShift(context, request, staffUser, ref);
                            },
                            icon: const Icon(Icons.check_circle),
                            label: Text(t.text('applyForThisShift')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyForShift(BuildContext context, ShiftRequest request, StaffUser staffUser, WidgetRef ref) async {
    final t = ref.read(translationProvider);
    try {
      final shiftService = ShiftService();
      final employeeName = '${staffUser.lastName} ${staffUser.firstName}'.trim();

      await shiftService.applyForShift(request.id, staffUser.id, employeeName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('applicationSuccess')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('applicationFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelApplication(BuildContext context, ShiftRequest request, StaffUser staffUser, WidgetRef ref) async {
    final t = ref.read(translationProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('cancelApplicationConfirm')),
        content: Text(t.text('actionCannotBeUndone')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.text('cancelApplication')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final shiftService = ShiftService();
      await shiftService.cancelApplication(request.id, staffUser.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('applicationCancelSuccess')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('applicationCancelFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
