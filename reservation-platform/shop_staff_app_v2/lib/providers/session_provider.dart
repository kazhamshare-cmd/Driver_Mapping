import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/reservation.dart';
import 'auth_provider.dart';

/// 本日のアクティブセッション一覧
final activeSessionsProvider = StreamProvider.autoDispose<List<Session>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('sessions')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('status', isEqualTo: 'in_progress')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        return list;
      });
});

/// 特定日のセッション一覧
final sessionsForDateProvider = StreamProvider.autoDispose
    .family<List<Session>, DateTime>((ref, date) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('sessions')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList();
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        return list;
      });
});

/// セッション詳細
final sessionDetailProvider = StreamProvider.autoDispose
    .family<Session?, String>((ref, sessionId) {
  if (sessionId.isEmpty) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('sessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) => doc.exists ? Session.fromFirestore(doc) : null);
});

/// 予約から来店セッションを開始
final startSessionFromReservationProvider = Provider((ref) {
  return ({
    required Reservation reservation,
    required int actualCount,
    required String tableId,
    required String tableName,
    String? primaryStaffId,
    String? primaryStaffName,
    List<SessionItem>? initialItems,
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインが必要です');

    final now = DateTime.now();

    // 予約メニューがある場合は初期アイテムとして追加
    final items = initialItems ?? <SessionItem>[];

    // セッションデータの作成
    final sessionData = {
      'shopId': staffUser.shopId,
      'reservationId': reservation.id,
      'customerId': reservation.userId,
      'customerName': reservation.userName,
      'reservedCount': reservation.numberOfPeople,
      'actualCount': actualCount,
      'tableId': tableId,
      'tableName': tableName,
      'primaryStaffId': primaryStaffId ?? reservation.staffId,
      'primaryStaffName': primaryStaffName ?? reservation.staffName,
      'startTime': Timestamp.fromDate(now),
      'status': 'in_progress',
      'items': items.map((item) => item.toMap()).toList(),
      'createdBy': staffUser.id,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    // Firestoreに保存
    final docRef = await FirebaseFirestore.instance
        .collection('sessions')
        .add(sessionData);

    // 予約ステータスを更新（来店済みに）
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservation.id)
        .update({
      'status': 'checked_in',
      'checkedInAt': Timestamp.fromDate(now),
      'sessionId': docRef.id,
      'updatedAt': Timestamp.fromDate(now),
    });

    return docRef.id;
  };
});

/// ウォークイン（予約なし）でセッションを開始
final startWalkInSessionProvider = Provider((ref) {
  return ({
    required int actualCount,
    required String tableId,
    required String tableName,
    String? customerName,
    String? primaryStaffId,
    String? primaryStaffName,
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインが必要です');

    final now = DateTime.now();

    final sessionData = {
      'shopId': staffUser.shopId,
      'customerName': customerName,
      'actualCount': actualCount,
      'tableId': tableId,
      'tableName': tableName,
      if (primaryStaffId != null) 'primaryStaffId': primaryStaffId,
      if (primaryStaffName != null) 'primaryStaffName': primaryStaffName,
      'startTime': Timestamp.fromDate(now),
      'status': 'in_progress',
      'items': [],
      'createdBy': staffUser.id,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await FirebaseFirestore.instance
        .collection('sessions')
        .add(sessionData);

    return docRef.id;
  };
});

/// セッションにアイテムを追加
final addSessionItemProvider = Provider((ref) {
  return (String sessionId, SessionItem item) async {
    final now = DateTime.now();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .update({
      'items': FieldValue.arrayUnion([item.toMap()]),
      'updatedAt': Timestamp.fromDate(now),
    });
  };
});

/// セッションを完了（会計完了）
final completeSessionProvider = Provider((ref) {
  return ({
    required String sessionId,
    required double totalAmount,
    String? paymentId,
    List<StaffCommission>? staffCommissions,
  }) async {
    final now = DateTime.now();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .update({
      'status': 'completed',
      'endTime': Timestamp.fromDate(now),
      'totalAmount': totalAmount,
      if (paymentId != null) 'paymentId': paymentId,
      if (staffCommissions != null)
        'staffCommissions': staffCommissions.map((c) => c.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(now),
    });

    // 関連する予約があれば完了に更新
    final sessionDoc = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .get();

    final reservationId = sessionDoc.data()?['reservationId'];
    if (reservationId != null) {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
        'status': 'completed',
        'completedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    }
  };
});

/// セッションをキャンセル
final cancelSessionProvider = Provider((ref) {
  return (String sessionId, {String? reason}) async {
    final now = DateTime.now();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .update({
      'status': 'cancelled',
      'endTime': Timestamp.fromDate(now),
      if (reason != null) 'cancellationReason': reason,
      'updatedAt': Timestamp.fromDate(now),
    });
  };
});

/// テーブルIDで現在のセッションを取得
final sessionByTableProvider = StreamProvider.autoDispose
    .family<Session?, String>((ref, tableId) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null || tableId.isEmpty) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('sessions')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('tableId', isEqualTo: tableId)
      .where('status', isEqualTo: 'in_progress')
      .limit(1)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.isNotEmpty ? Session.fromFirestore(snapshot.docs.first) : null);
});
