import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation.dart';
import '../services/reservation_service.dart';
import 'auth_provider.dart';
import 'employee_provider.dart';
import 'shift_provider.dart';

final reservationServiceProvider = Provider((ref) => ReservationService());

/// 全予約一覧プロバイダー
final reservationsProvider =
    StreamProvider.autoDispose<List<Reservation>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final service = ref.watch(reservationServiceProvider);
  return service.getReservations(staffUser.shopId);
});

/// 承認待ち予約一覧プロバイダー
final pendingReservationsProvider =
    StreamProvider.autoDispose<List<Reservation>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final service = ref.watch(reservationServiceProvider);
  return service.getPendingReservations(staffUser.shopId);
});

/// 確定済み予約一覧プロバイダー
final confirmedReservationsProvider =
    StreamProvider.autoDispose<List<Reservation>>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value([]);

  final service = ref.watch(reservationServiceProvider);
  return service.getConfirmedReservations(staffUser.shopId);
});

/// 未読の承認待ち予約数プロバイダー
final pendingReservationCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  final staffUser = ref.watch(staffUserProvider).value;
  if (staffUser == null) return Stream.value(0);

  final service = ref.watch(reservationServiceProvider);
  return service
      .getPendingReservations(staffUser.shopId)
      .map((reservations) => reservations.length);
});

/// 選択日+スタッフフィルター+ロールベースでフィルタリングされた予約一覧
final filteredReservationsProvider =
    Provider.autoDispose<List<Reservation>>((ref) {
  final reservations = ref.watch(reservationsProvider).value ?? [];
  final staffUser = ref.watch(staffUserProvider).value;
  final selectedStaff = ref.watch(selectedStaffFilterProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  if (staffUser == null) return [];

  // 日付でフィルター
  var filtered = reservations.where((r) =>
      r.reservationDate.year == selectedDate.year &&
      r.reservationDate.month == selectedDate.month &&
      r.reservationDate.day == selectedDate.day).toList();

  // ロールベースフィルター
  if (staffUser.role == 'staff') {
    // スタッフは自分の予約のみ表示
    filtered = filtered.where((r) => r.staffId == staffUser.id).toList();
  } else if (selectedStaff != null) {
    // マネージャー/オーナーでフィルター選択時
    filtered = filtered.where((r) => r.staffId == selectedStaff).toList();
  }

  return filtered;
});

/// テーブル別に整理した予約一覧（ガントチャート用）
/// キー: tableId または '__unassigned__' (テーブル未割当)
final reservationsByTableProvider =
    Provider.autoDispose<Map<String, List<Reservation>>>((ref) {
  final reservations = ref.watch(filteredReservationsProvider);

  final Map<String, List<Reservation>> byTable = {};
  for (final r in reservations) {
    // キャンセル済みは除外
    if (r.status == ReservationStatus.cancelled) continue;

    // tableIdsがあればそれを使用、なければtableIdを使用
    final tableIds = r.tableIds.isNotEmpty ? r.tableIds : (r.tableId != null ? [r.tableId!] : []);

    if (tableIds.isEmpty) {
      // テーブル未割当の予約
      byTable.putIfAbsent('__unassigned__', () => []).add(r);
    } else {
      for (final tableId in tableIds) {
        byTable.putIfAbsent(tableId, () => []).add(r);
      }
    }
  }

  // 各リストを開始時間でソート
  for (final list in byTable.values) {
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  return byTable;
});

/// テーブル未割当の予約一覧（ガントチャート用）
final unassignedReservationsProvider =
    Provider.autoDispose<List<Reservation>>((ref) {
  final reservationsByTable = ref.watch(reservationsByTableProvider);
  return reservationsByTable['__unassigned__'] ?? [];
});
