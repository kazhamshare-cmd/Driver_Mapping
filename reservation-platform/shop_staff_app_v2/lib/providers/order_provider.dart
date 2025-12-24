import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import 'auth_provider.dart';

// 注文一覧をリアルタイムで監視（アクティブな注文のみ）
final activeOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) {
    return Stream.value([]);
  }

  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchOrdersByStatus(
    staffUser.shopId,
    [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.served,
      OrderStatus.completed,  // 会計済みも含める
    ],
  );
});

// 全注文履歴をリアルタイムで監視
final allOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) {
    return Stream.value([]);
  }

  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.watchOrders(staffUser.shopId);
});

// 注文ステータス更新
final updateOrderStatusProvider = Provider((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return (String orderId, OrderStatus status, {String? staffId, String? staffName, String? reason}) async {
    await firebaseService.updateOrderStatus(orderId, status, staffId: staffId, staffName: staffName, reason: reason);
  };
});

// 注文アイテムステータス更新
final updateOrderItemStatusProvider = Provider((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return (String orderId, String itemId, String status) async {
    await firebaseService.updateOrderItemStatus(orderId, itemId, status);
  };
});
