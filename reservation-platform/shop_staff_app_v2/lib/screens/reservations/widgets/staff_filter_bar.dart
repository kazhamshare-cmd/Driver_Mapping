import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employee_provider.dart';
import 'shift_timeline.dart';

/// スタッフフィルターバー（マネージャー/オーナーのみ表示）
class StaffFilterBar extends ConsumerWidget {
  const StaffFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUser = ref.watch(staffUserProvider).value;
    final employeesAsync = ref.watch(employeesProvider);
    final selectedStaff = ref.watch(selectedStaffFilterProvider);

    // スタッフロールの場合は非表示
    if (staffUser == null || staffUser.role == 'staff') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // スタッフ選択チップ
        Container(
          color: Colors.grey.shade50,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: employeesAsync.when(
              data: (employees) => Row(
                children: [
                  // 全員チップ
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('全員'),
                      selected: selectedStaff == null,
                      onSelected: (_) {
                        ref.read(selectedStaffFilterProvider.notifier).state = null;
                      },
                      selectedColor: Colors.blue.shade100,
                    ),
                  ),
                  // スタッフチップ
                  ...employees.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(e.name.isNotEmpty ? e.name : e.email),
                          selected: selectedStaff == e.id,
                          onSelected: (_) {
                            ref.read(selectedStaffFilterProvider.notifier).state = e.id;
                          },
                          selectedColor: Colors.blue.shade100,
                        ),
                      )),
                ],
              ),
              loading: () => const SizedBox(
                height: 32,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const Text('スタッフ読み込みエラー'),
            ),
          ),
        ),
        // シフトタイムライン（スタッフ選択時のみ表示）
        if (selectedStaff != null) ShiftTimeline(employeeId: selectedStaff),
      ],
    );
  }
}
