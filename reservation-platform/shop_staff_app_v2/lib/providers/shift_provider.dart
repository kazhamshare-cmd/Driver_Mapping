import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift.dart';
import 'auth_provider.dart';

/// 選択日プロバイダー
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// 選択日のシフト一覧ストリームプロバイダー
final shiftsForDateProvider = StreamProvider.autoDispose<List<Shift>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  final selectedDate = ref.watch(selectedDateProvider);
  if (staffUser == null) return Stream.value([]);

  final startOfDay =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('shifts')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('shiftDate', isLessThan: Timestamp.fromDate(endOfDay))
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => Shift.fromFirestore(doc)).toList());
});

/// 特定スタッフのシフトを取得
final staffShiftProvider =
    Provider.autoDispose.family<Shift?, String>((ref, employeeId) {
  final shifts = ref.watch(shiftsForDateProvider).value ?? [];
  try {
    return shifts.firstWhere((s) => s.employeeId == employeeId);
  } catch (_) {
    return null;
  }
});
