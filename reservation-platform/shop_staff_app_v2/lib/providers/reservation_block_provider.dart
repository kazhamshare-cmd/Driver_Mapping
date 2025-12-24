import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_block.dart';
import 'auth_provider.dart';

/// 予約ブロック一覧を取得
final reservationBlocksProvider = StreamProvider<List<ReservationBlock>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('shops')
      .doc(staffUser.shopId)
      .collection('reservationBlocks')
      .orderBy('date', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ReservationBlock.fromFirestore(doc))
          .toList());
});

/// 特定の日付の予約ブロックを取得
final reservationBlocksByDateProvider = StreamProvider.family<List<ReservationBlock>, DateTime>((ref, date) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('shops')
      .doc(staffUser.shopId)
      .collection('reservationBlocks')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ReservationBlock.fromFirestore(doc))
          .toList());
});

/// 今後の予約ブロックを取得
final upcomingReservationBlocksProvider = StreamProvider<List<ReservationBlock>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  return FirebaseFirestore.instance
      .collection('shops')
      .doc(staffUser.shopId)
      .collection('reservationBlocks')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
      .orderBy('date')
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ReservationBlock.fromFirestore(doc))
          .toList());
});

/// 予約ブロックを作成
final createReservationBlockProvider = Provider((ref) {
  return (ReservationBlock block) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインしてください');

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(staffUser.shopId)
        .collection('reservationBlocks')
        .add(block.toFirestore());
  };
});

/// 予約ブロックを削除
final deleteReservationBlockProvider = Provider((ref) {
  return (String blockId) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインしてください');

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(staffUser.shopId)
        .collection('reservationBlocks')
        .doc(blockId)
        .delete();
  };
});

/// 日付範囲で予約ブロックを一括作成（繰り返し設定用）
final createReservationBlocksRangeProvider = Provider((ref) {
  return ({
    required DateTime startDate,
    required DateTime endDate,
    required ReservationBlockType type,
    String? startTime,
    String? endTime,
    bool isAllDay = false,
    String? staffId,
    String? staffName,
    String? reason,
    List<int>? weekdays, // 0=月, 1=火, ... 6=日
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインしてください');

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance
        .collection('shops')
        .doc(staffUser.shopId)
        .collection('reservationBlocks');

    var currentDate = startDate;
    while (!currentDate.isAfter(endDate)) {
      // 曜日フィルタがある場合
      if (weekdays != null && weekdays.isNotEmpty) {
        final weekday = currentDate.weekday - 1; // Dartは月曜=1なので-1
        if (!weekdays.contains(weekday)) {
          currentDate = currentDate.add(const Duration(days: 1));
          continue;
        }
      }

      final block = ReservationBlock(
        id: '',
        shopId: staffUser.shopId,
        date: currentDate,
        startTime: isAllDay ? null : startTime,
        endTime: isAllDay ? null : endTime,
        isAllDay: isAllDay,
        type: type,
        staffId: staffId,
        staffName: staffName,
        reason: reason,
        createdAt: DateTime.now(),
        createdBy: staffUser.id,
      );

      batch.set(collection.doc(), block.toFirestore());
      currentDate = currentDate.add(const Duration(days: 1));
    }

    await batch.commit();
  };
});
