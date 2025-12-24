import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/table.dart';
import 'auth_provider.dart';

/// テーブル一覧ストリームプロバイダー
final tablesProvider = StreamProvider.autoDispose<List<TableModel>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('tables')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => TableModel.fromFirestore(doc)).toList());
});

/// ソート済みテーブル一覧（ガントチャート表示用）
final sortedTablesProvider = Provider.autoDispose<List<TableModel>>((ref) {
  final tables = ref.watch(tablesProvider).value ?? [];
  return [...tables]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});
