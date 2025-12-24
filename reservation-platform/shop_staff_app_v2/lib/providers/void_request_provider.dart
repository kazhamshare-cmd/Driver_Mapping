import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/void_request.dart';
import 'auth_provider.dart';

/// 承認待ちのバック申請リスト
final pendingVoidRequestsProvider = StreamProvider<List<VoidRequest>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('voidRequests')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('status', isEqualTo: 'pending')
      .orderBy('requestedAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => VoidRequest.fromFirestore(doc)).toList());
});

/// 承認待ちのバック申請数
final pendingVoidRequestCountProvider = Provider<int>((ref) {
  final requests = ref.watch(pendingVoidRequestsProvider).value ?? [];
  return requests.length;
});

/// 全てのバック申請リスト（履歴含む）
final allVoidRequestsProvider = StreamProvider<List<VoidRequest>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('voidRequests')
      .where('shopId', isEqualTo: staffUser.shopId)
      .orderBy('requestedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => VoidRequest.fromFirestore(doc)).toList());
});

/// バック申請を作成
final createVoidRequestProvider = Provider((ref) {
  return ({
    required String orderId,
    String? itemId,
    required String itemName,
    required int quantity,
    required int price,
    required String reason,
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ユーザー情報が取得できません');

    final request = VoidRequest(
      id: '',
      shopId: staffUser.shopId,
      orderId: orderId,
      itemId: itemId,
      itemName: itemName,
      quantity: quantity,
      price: price,
      reason: reason,
      requestedBy: staffUser.id,
      requestedByName: staffUser.name,
      requestedAt: DateTime.now(),
      status: VoidRequestStatus.pending,
    );

    await FirebaseFirestore.instance
        .collection('voidRequests')
        .add(request.toFirestore());
  };
});

/// バック申請を承認
final approveVoidRequestProvider = Provider((ref) {
  return (String requestId, {String? comment}) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ユーザー情報が取得できません');

    // 申請を取得
    final doc = await FirebaseFirestore.instance
        .collection('voidRequests')
        .doc(requestId)
        .get();

    if (!doc.exists) throw Exception('申請が見つかりません');

    final request = VoidRequest.fromFirestore(doc);

    // 申請を承認
    await FirebaseFirestore.instance
        .collection('voidRequests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'reviewedBy': staffUser.id,
      'reviewedByName': staffUser.name,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewComment': comment,
    });

    // 注文からアイテムを削除または注文全体をキャンセル
    if (request.itemId != null) {
      // 個別アイテムの削除
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(request.orderId)
          .get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

        // アイテムを削除
        items.removeWhere((item) => item['id'] == request.itemId);

        // 合計を再計算
        int newTotal = 0;
        for (final item in items) {
          newTotal += (item['price'] as int) * (item['quantity'] as int);
        }

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(request.orderId)
            .update({
          'items': items,
          'totalPrice': newTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  };
});

/// バック申請を却下
final rejectVoidRequestProvider = Provider((ref) {
  return (String requestId, {String? comment}) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ユーザー情報が取得できません');

    await FirebaseFirestore.instance
        .collection('voidRequests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'reviewedBy': staffUser.id,
      'reviewedByName': staffUser.name,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewComment': comment,
    });
  };
});
