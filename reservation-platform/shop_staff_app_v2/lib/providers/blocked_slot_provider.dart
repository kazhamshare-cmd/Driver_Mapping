import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blocked_slot.dart';
import 'auth_provider.dart';

/// 選択日のブロック一覧
final blockedSlotsForDateProvider = StreamProvider.autoDispose
    .family<List<BlockedSlot>, DateTime>((ref, date) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  return FirebaseFirestore.instance
      .collection('blockedSlots')
      .where('shopId', isEqualTo: staffUser.shopId)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThan: Timestamp.fromDate(endOfDay))
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => BlockedSlot.fromFirestore(doc))
            .toList();
      });
});

/// ブロック作成
final createBlockedSlotProvider = Provider((ref) {
  return ({
    required DateTime date,
    required String startTime,
    required String endTime,
    String? staffId,
    String? staffName,
    String? reason,
    bool isAllDay = false,
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインが必要です');

    final now = DateTime.now();

    final slotData = BlockedSlot(
      id: '',
      shopId: staffUser.shopId,
      staffId: staffId,
      staffName: staffName,
      date: date,
      startTime: isAllDay ? '00:00' : startTime,
      endTime: isAllDay ? '23:59' : endTime,
      reason: reason,
      isAllDay: isAllDay,
      createdBy: staffUser.id,
      createdAt: now,
    );

    final docRef = await FirebaseFirestore.instance
        .collection('blockedSlots')
        .add(slotData.toFirestore());

    return docRef.id;
  };
});

/// ブロック削除
final deleteBlockedSlotProvider = Provider((ref) {
  return (String slotId) async {
    await FirebaseFirestore.instance
        .collection('blockedSlots')
        .doc(slotId)
        .delete();
  };
});

/// 終日ブロック設定
final setAllDayBlockProvider = Provider((ref) {
  return ({
    required DateTime date,
    String? reason,
  }) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) throw Exception('ログインが必要です');

    final createBlock = ref.read(createBlockedSlotProvider);
    return await createBlock(
      date: date,
      startTime: '00:00',
      endTime: '23:59',
      reason: reason ?? '終日受付不可',
      isAllDay: true,
    );
  };
});

/// 指定時間がブロックされているかチェック
final isTimeBlockedProvider = Provider.family<bool, ({DateTime date, String time})>((ref, params) {
  final blockedSlots = ref.watch(blockedSlotsForDateProvider(params.date)).value ?? [];

  for (final slot in blockedSlots) {
    if (slot.containsTime(params.time)) {
      return true;
    }
  }
  return false;
});

/// 予約可能かチェック（ブロックと重複しないか）
final canBookTimeRangeProvider = Provider.family<bool, ({DateTime date, String startTime, String endTime})>((ref, params) {
  final blockedSlots = ref.watch(blockedSlotsForDateProvider(params.date)).value ?? [];

  for (final slot in blockedSlots) {
    if (slot.overlaps(params.startTime, params.endTime)) {
      return false;
    }
  }
  return true;
});
