import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_user.dart';
import 'auth_provider.dart';

/// 従業員一覧ストリームプロバイダー（マネージャー/オーナー用フィルター表示）
final employeesProvider = StreamProvider.autoDispose<List<StaffUser>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('employees')
      .where('shopId', isEqualTo: staffUser.shopId)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => StaffUser.fromFirestore(doc)).toList());
});

/// 選択中のスタッフフィルター（null = 全員表示）
final selectedStaffFilterProvider = StateProvider<String?>((ref) => null);
