import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/table_call.dart';
import 'auth_provider.dart';

/// アクティブなテーブル呼び出し（未対応・対応中）を監視するプロバイダー
final activeTableCallsProvider = StreamProvider<List<TableCall>>((ref) {
  final staffUserAsync = ref.watch(staffUserProvider);
  final staffUser = staffUserAsync.value;

  if (staffUser == null) {
    return Stream.value([]);
  }

  // whereInとorderByの組み合わせはインデックス設定が複雑になるため、
  // resolved以外のステータスを取得してクライアント側でソート
  return FirebaseFirestore.instance
      .collection('tableCalls')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('status', whereIn: ['pending', 'inProgress'])
      .snapshots()
      .map((snapshot) {
        final calls = snapshot.docs
            .map((doc) => TableCall.fromFirestore(doc))
            .toList();
        // 古い呼び出しから表示（createdAtで昇順ソート）
        calls.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return calls;
      });
});

/// 未対応のテーブル呼び出しのみを取得するプロバイダー
final pendingTableCallsProvider = Provider<List<TableCall>>((ref) {
  final activeCalls = ref.watch(activeTableCallsProvider).value ?? [];
  return activeCalls.where((call) => call.status == TableCallStatus.pending).toList();
});

/// 未対応のテーブル呼び出し数を取得するプロバイダー
final pendingTableCallCountProvider = Provider<int>((ref) {
  return ref.watch(pendingTableCallsProvider).length;
});

/// テーブル呼び出しの操作を管理するNotifier
class TableCallNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  TableCallNotifier(this.ref) : super(const AsyncValue.data(null));

  /// テーブル呼び出しに対応を開始する
  Future<bool> respondToCall(String callId) async {
    state = const AsyncValue.loading();
    try {
      final staffUser = ref.read(staffUserProvider).value;
      if (staffUser == null) {
        throw Exception('ログインが必要です');
      }

      await FirebaseFirestore.instance.collection('tableCalls').doc(callId).update({
        'status': 'inProgress',
        'assignedStaffId': staffUser.id,
        'assignedStaffName': staffUser.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// テーブル呼び出しを完了にする
  Future<bool> resolveCall(String callId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseFirestore.instance.collection('tableCalls').doc(callId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// テーブル呼び出しをキャンセルする（誤操作時など）
  Future<bool> cancelResponse(String callId) async {
    state = const AsyncValue.loading();
    try {
      await FirebaseFirestore.instance.collection('tableCalls').doc(callId).update({
        'status': 'pending',
        'assignedStaffId': FieldValue.delete(),
        'assignedStaffName': FieldValue.delete(),
        'respondedAt': FieldValue.delete(),
      });

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// テーブル呼び出し操作用のプロバイダー
final tableCallNotifierProvider =
    StateNotifierProvider<TableCallNotifier, AsyncValue<void>>((ref) {
  return TableCallNotifier(ref);
});
