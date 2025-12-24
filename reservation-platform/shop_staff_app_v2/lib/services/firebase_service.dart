import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_user.dart';
import '../models/shop.dart';
import '../models/order.dart';
import '../models/table.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // メールアドレスとパスワードでログイン
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // ログイン成功後、employeesドキュメントが存在するか確認
    // 存在しない場合は、メールアドレスに@staffが含まれていれば作成
    if (email.contains('@staff')) {
      await _ensureEmployeeDocument(credential.user!);
    }

    return credential;
  }

  // employeesドキュメントが存在しない場合は作成
  Future<void> _ensureEmployeeDocument(User user) async {
    try {
      final employeeDoc = await _firestore.collection('employees').doc(user.uid).get();

      if (!employeeDoc.exists) {
        debugPrint('employeesドキュメントが存在しないため作成します');

        await _firestore.collection('employees').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@')[0] ?? 'スタッフ',
          'shopId': '', // 初期値は空、後で設定が必要
          'role': 'staff',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('employeesドキュメントを作成しました');
      }
    } catch (e) {
      debugPrint('employeesドキュメントの確認/作成エラー: $e');
      // エラーが発生してもログインは継続
    }
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // スタッフユーザー情報を取得
  Future<StaffUser?> getStaffUser(String uid) async {
    try {
      debugPrint('🔍 getStaffUser: uid=$uid');
      final doc = await _firestore.collection('employees').doc(uid).get();
      debugPrint('🔍 Document exists: ${doc.exists}');
      if (doc.exists) {
        debugPrint('🔍 Document data: ${doc.data()}');
        final staffUser = StaffUser.fromFirestore(doc);
        debugPrint('✅ StaffUser created: ${staffUser.name}, shopId=${staffUser.shopId}');
        return staffUser;
      }
      debugPrint('❌ Document does not exist');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting staff user: $e');
      return null;
    }
  }

  // 店舗情報を取得
  Future<Shop?> getShop(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (doc.exists) {
        return Shop.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting shop: $e');
      return null;
    }
  }

  // パスワードをリセット
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // 注文をリアルタイムで監視（店舗の全注文）
  Stream<List<OrderModel>> watchOrders(String shopId) {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true) // orderedAt を createdAt に変更
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }

  // 注文をリアルタイムで監視（特定のステータスのみ）
  Stream<List<OrderModel>> watchOrdersByStatus(String shopId, List<OrderStatus> statuses) {
    final statusNames = statuses.map((s) => s.name).toList();
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: statusNames)
        .orderBy('createdAt', descending: false) // orderedAt を createdAt に変更
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });
  }

  // 注文のステータスを更新（時間記録付き）
  Future<void> updateOrderStatus(String orderId, OrderStatus status, {String? staffId, String? staffName, String? reason}) async {
    final Map<String, dynamic> updateData = {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // ステータスに応じて時間を記録
    switch (status) {
      case OrderStatus.confirmed:
        updateData['confirmedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.preparing:
        updateData['preparingStartedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.ready:
        updateData['readyAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.served:
        updateData['servedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.completed:
        updateData['completedAt'] = FieldValue.serverTimestamp();
        break;
      case OrderStatus.cancelled:
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
        // キャンセル情報を構造化して保存
        updateData['cancelInfo'] = {
          'staffId': staffId,
          'staffName': staffName,
          'reason': reason ?? '理由未入力',
          'cancelledAt': FieldValue.serverTimestamp(),
        };
        // 旧フィールドも互換性のため維持
        if (staffId != null) {
          updateData['cancelledBy'] = staffId;
        }
        if (reason != null) {
          updateData['cancelReason'] = reason;
        }
        break;
      default:
        break;
    }

    await _firestore.collection('orders').doc(orderId).update(updateData);

    // キャンセルの場合は履歴を別コレクションに保存（監査用）
    if (status == OrderStatus.cancelled) {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      final orderData = orderDoc.data();

      await _firestore.collection('orderCancellations').add({
        'orderId': orderId,
        'shopId': orderData?['shopId'],
        'tableId': orderData?['tableId'],
        'tableNumber': orderData?['tableNumber'],
        'items': orderData?['items'],
        'subtotal': orderData?['subtotal'],
        'tax': orderData?['tax'],
        'total': orderData?['total'],
        'originalOrderedAt': orderData?['orderedAt'],
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': staffId,
        'cancelledByName': staffName,
        'reason': reason ?? '理由未入力',
      });
    }
  }

  // 注文アイテムのステータスを更新
  Future<void> updateOrderItemStatus(
    String orderId,
    String itemId,
    String status,
  ) async {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    final order = OrderModel.fromFirestore(orderDoc);

    final updatedItems = order.items.map((item) {
      if (item.id == itemId) {
        return OrderItem(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          productNameEn: item.productNameEn,
          productNameTh: item.productNameTh,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          selectedOptions: item.selectedOptions,
          subtotal: item.subtotal,
          notes: item.notes,
          status: status,
        );
      }
      return item;
    }).toList();

    await _firestore.collection('orders').doc(orderId).update({
      'items': updatedItems.map((item) => item.toFirestore()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // テーブル一覧を取得
  Future<List<TableModel>> getTables(String shopId) async {
    try {
      final snapshot = await _firestore
          .collection('tables')
          .where('shopId', isEqualTo: shopId)
          .where('isActive', isEqualTo: true)
          .orderBy('tableNumber')
          .get();

      return snapshot.docs
          .map((doc) => TableModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting tables: $e');
      return [];
    }
  }

  // テーブルをリアルタイムで監視
  Stream<List<TableModel>> watchTables(String shopId) {
    return _firestore
        .collection('tables')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .orderBy('tableNumber')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TableModel.fromFirestore(doc))
          .toList();
    });
  }

  // 未読通知数を監視
  Stream<int> watchUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // テーブルステータスを更新
  Future<void> updateTableStatus(String tableId, TableStatus status) async {
    await _firestore.collection('tables').doc(tableId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
