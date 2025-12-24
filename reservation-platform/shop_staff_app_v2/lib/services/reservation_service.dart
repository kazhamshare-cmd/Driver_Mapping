import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/reservation.dart';

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 店舗の予約一覧を取得（リアルタイム）
  Stream<List<Reservation>> getReservations(String shopId) {
    debugPrint('🔍 getReservations (all) called for shopId: $shopId');
    return _firestore
        .collection('reservations')
        .where('shopId', isEqualTo: shopId)
        .orderBy('reservationDate', descending: false)
        .snapshots()
        .handleError((error) {
          debugPrint('❌ getReservations error: $error');
        })
        .map((snapshot) {
      debugPrint('📦 getReservations received ${snapshot.docs.length} docs');
      // 各予約のstatusをログ出力
      for (var doc in snapshot.docs) {
        debugPrint('  - ${doc.id}: status=${doc.data()['status']}');
      }
      final reservations = snapshot.docs
          .map((doc) => Reservation.fromFirestore(doc))
          .toList();
      // クライアント側でstartTimeでソート
      reservations.sort((a, b) {
        final dateCompare = a.reservationDate.compareTo(b.reservationDate);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
      return reservations;
    });
  }

  /// 承認待ちの予約一覧を取得（リアルタイム）
  Stream<List<Reservation>> getPendingReservations(String shopId) {
    return _firestore
        .collection('reservations')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'pending')
        .orderBy('reservationDate', descending: false)
        .snapshots()
        .map((snapshot) {
      final reservations = snapshot.docs
          .map((doc) => Reservation.fromFirestore(doc))
          .toList();
      // クライアント側でstartTimeでソート
      reservations.sort((a, b) {
        final dateCompare = a.reservationDate.compareTo(b.reservationDate);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
      return reservations;
    });
  }

  /// 確定済みの予約一覧を取得（リアルタイム）
  Stream<List<Reservation>> getConfirmedReservations(String shopId) {
    debugPrint('🔍 getConfirmedReservations called for shopId: $shopId');
    return _firestore
        .collection('reservations')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('reservationDate', descending: false)
        .snapshots()
        .handleError((error) {
          debugPrint('❌ getConfirmedReservations error: $error');
        })
        .map((snapshot) {
      debugPrint('📦 getConfirmedReservations received ${snapshot.docs.length} docs');
      final reservations = snapshot.docs
          .map((doc) => Reservation.fromFirestore(doc))
          .toList();
      // クライアント側でstartTimeでソート
      reservations.sort((a, b) {
        final dateCompare = a.reservationDate.compareTo(b.reservationDate);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
      return reservations;
    });
  }

  /// 特定の日付の予約を取得
  Future<List<Reservation>> getReservationsByDate(
      String shopId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('reservations')
        .where('shopId', isEqualTo: shopId)
        .where('reservationDate', isGreaterThanOrEqualTo: startOfDay)
        .where('reservationDate', isLessThanOrEqualTo: endOfDay)
        .orderBy('reservationDate')
        .orderBy('startTime')
        .get();

    return snapshot.docs.map((doc) => Reservation.fromFirestore(doc)).toList();
  }

  /// 予約を承認する
  Future<void> approveReservation(String reservationId) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'confirmed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 予約をキャンセルする
  /// [cancelledBy] - 'shop' (店舗都合) または 'customer' (顧客都合)
  Future<void> cancelReservation(
      String reservationId, String? cancellationReason, {String cancelledBy = 'shop'}) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'cancelled',
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 予約を完了にする
  Future<void> completeReservation(String reservationId) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 予約を無断キャンセルにする
  Future<void> markAsNoShow(String reservationId) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'no_show',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// チェックインする
  Future<void> checkIn(String reservationId) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'checkedInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 予約の詳細を取得
  Future<Reservation?> getReservation(String reservationId) async {
    final doc =
        await _firestore.collection('reservations').doc(reservationId).get();
    if (!doc.exists) return null;
    return Reservation.fromFirestore(doc);
  }

  /// 予約を承認してテーブルを割り当てる
  Future<void> approveReservationWithTable(
    String reservationId, {
    required List<String> tableIds,
    bool isCombined = false,
  }) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'status': 'confirmed',
      'tableIds': tableIds,
      'isCombined': isCombined,
      // 後方互換性のため、最初のテーブルIDをtableIdにも保存
      if (tableIds.isNotEmpty) 'tableId': tableIds.first,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 予約のテーブル割り当てを更新
  Future<void> updateTableAssignment(
    String reservationId, {
    required List<String> tableIds,
    bool isCombined = false,
  }) async {
    await _firestore.collection('reservations').doc(reservationId).update({
      'tableIds': tableIds,
      'isCombined': isCombined,
      if (tableIds.isNotEmpty) 'tableId': tableIds.first,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
