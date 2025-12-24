import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift.dart';
import '../models/shift_request.dart';
import '../models/shift_change_request.dart';

class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 自分のシフトを取得（期間指定）
  Stream<List<Shift>> getMyShifts(String employeeId, DateTime startDate, DateTime endDate) {
    return _firestore
        .collection('shifts')
        .where('employeeId', isEqualTo: employeeId)
        .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('shiftDate', isLessThan: Timestamp.fromDate(endDate.add(const Duration(days: 1))))
        .orderBy('shiftDate')
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Shift.fromFirestore(doc)).toList());
  }

  // 今月のシフトを取得
  Stream<List<Shift>> getMyShiftsThisMonth(String employeeId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getMyShifts(employeeId, startOfMonth, endOfMonth);
  }

  // 募集中のシフトを取得（自分の店舗）- 通常募集と交代希望の両方を含む
  Stream<List<ShiftRequest>> getOpenShiftRequests(String shopId) {
    return _firestore
        .collection('shiftRequests')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftRequest.fromFirestore(doc)).toList());
  }

  // シフト募集に応募
  Future<void> applyForShift(String requestId, String employeeId, String employeeName) async {
    final requestRef = _firestore.collection('shiftRequests').doc(requestId);

    await requestRef.update({
      'responses': FieldValue.arrayUnion([
        {
          'employeeId': employeeId,
          'employeeName': employeeName,
          'respondedAt': Timestamp.now(),
          'status': 'pending',
        }
      ]),
      'updatedAt': Timestamp.now(),
    });
  }

  // 応募をキャンセル
  Future<void> cancelApplication(String requestId, String employeeId) async {
    final requestRef = _firestore.collection('shiftRequests').doc(requestId);
    final requestDoc = await requestRef.get();

    if (!requestDoc.exists) return;

    final data = requestDoc.data()!;
    final responses = (data['responses'] as List<dynamic>? ?? [])
        .where((r) => (r as Map<String, dynamic>)['employeeId'] != employeeId)
        .toList();

    await requestRef.update({
      'responses': responses,
      'updatedAt': Timestamp.now(),
    });
  }

  // ========== シフト変更希望機能 ==========

  /// シフト変更希望を作成
  Future<String> createShiftChangeRequest({
    required String shopId,
    required Shift shift,
    required String employeeId,
    required String employeeName,
    required ShiftChangeType changeType,
    required String reason,
  }) async {
    final docRef = _firestore.collection('shiftChangeRequests').doc();

    final request = ShiftChangeRequest(
      id: docRef.id,
      shopId: shopId,
      shiftId: shift.id,
      employeeId: employeeId,
      employeeName: employeeName,
      changeType: changeType,
      reason: reason,
      status: ShiftChangeStatus.pending,
      shiftDate: shift.shiftDate,
      startTime: shift.startTime,
      endTime: shift.endTime,
      breakMinutes: shift.breakMinutes,
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toFirestore());

    // 交代希望の場合、シフト募集にも自動的に追加
    if (changeType == ShiftChangeType.swap) {
      await _createShiftRequestFromChangeRequest(request);
    }

    return docRef.id;
  }

  /// シフト変更希望からシフト募集を作成
  Future<void> _createShiftRequestFromChangeRequest(ShiftChangeRequest changeRequest) async {
    final shiftRequestRef = _firestore.collection('shiftRequests').doc();

    await shiftRequestRef.set({
      'shopId': changeRequest.shopId,
      'requestType': 'shift_change',  // 変更希望からの募集
      'changeRequestId': changeRequest.id,  // 元の変更希望ID
      'newShift': {
        'shiftDate': Timestamp.fromDate(changeRequest.shiftDate),
        'startTime': changeRequest.startTime,
        'endTime': changeRequest.endTime,
        'breakMinutes': changeRequest.breakMinutes,
        'requiredStaffCount': 1,
      },
      'isOpenToAll': true,
      'status': 'open',
      'responses': [],
      'message': '【交代希望】${changeRequest.employeeName}さんの代わりを募集中\n理由: ${changeRequest.reason}',
      'title': '${changeRequest.employeeName}さんのシフト交代募集',
      'originalEmployeeId': changeRequest.employeeId,
      'originalEmployeeName': changeRequest.employeeName,
      'createdAt': Timestamp.now(),
    });
  }

  /// 自分のシフト変更希望を取得
  Stream<List<ShiftChangeRequest>> getMyShiftChangeRequests(String employeeId) {
    return _firestore
        .collection('shiftChangeRequests')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftChangeRequest.fromFirestore(doc)).toList());
  }

  /// 店舗のシフト変更希望一覧を取得（管理者用）
  Stream<List<ShiftChangeRequest>> getShopShiftChangeRequests(String shopId, {String? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('shiftChangeRequests')
        .where('shopId', isEqualTo: shopId);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ShiftChangeRequest.fromFirestore(doc)).toList());
  }

  /// シフト変更希望を承認
  Future<void> approveShiftChangeRequest(
    String requestId, {
    required String reviewedByStaffId,
    required String reviewedByStaffName,
    String? reviewNote,
  }) async {
    await _firestore.collection('shiftChangeRequests').doc(requestId).update({
      'status': 'approved',
      'reviewedByStaffId': reviewedByStaffId,
      'reviewedByStaffName': reviewedByStaffName,
      'reviewNote': reviewNote,
      'reviewedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// シフト変更希望を却下
  Future<void> rejectShiftChangeRequest(
    String requestId, {
    required String reviewedByStaffId,
    required String reviewedByStaffName,
    String? reviewNote,
  }) async {
    await _firestore.collection('shiftChangeRequests').doc(requestId).update({
      'status': 'rejected',
      'reviewedByStaffId': reviewedByStaffId,
      'reviewedByStaffName': reviewedByStaffName,
      'reviewNote': reviewNote,
      'reviewedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // 関連するシフト募集をクローズ
    await _closeRelatedShiftRequest(requestId);
  }

  /// シフト変更希望をキャンセル
  Future<void> cancelShiftChangeRequest(String requestId) async {
    await _firestore.collection('shiftChangeRequests').doc(requestId).delete();

    // 関連するシフト募集もクローズ
    await _closeRelatedShiftRequest(requestId);
  }

  /// 関連するシフト募集をクローズ
  Future<void> _closeRelatedShiftRequest(String changeRequestId) async {
    final relatedRequests = await _firestore
        .collection('shiftRequests')
        .where('changeRequestId', isEqualTo: changeRequestId)
        .get();

    for (final doc in relatedRequests.docs) {
      await doc.reference.update({
        'status': 'closed',
        'updatedAt': Timestamp.now(),
      });
    }
  }

  /// シフト交代に応募した場合の処理（代替者として確定）
  Future<void> confirmShiftCover({
    required String changeRequestId,
    required String coveredByEmployeeId,
    required String coveredByEmployeeName,
    required String reviewedByStaffId,
    required String reviewedByStaffName,
  }) async {
    // 変更希望を更新
    await _firestore.collection('shiftChangeRequests').doc(changeRequestId).update({
      'status': 'covered',
      'coveredByEmployeeId': coveredByEmployeeId,
      'coveredByEmployeeName': coveredByEmployeeName,
      'reviewedByStaffId': reviewedByStaffId,
      'reviewedByStaffName': reviewedByStaffName,
      'reviewedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    // 関連するシフト募集をクローズ
    await _closeRelatedShiftRequest(changeRequestId);
  }

  /// 特定シフトに対する変更希望があるかチェック
  Future<ShiftChangeRequest?> getChangeRequestForShift(String shiftId) async {
    final snapshot = await _firestore
        .collection('shiftChangeRequests')
        .where('shiftId', isEqualTo: shiftId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ShiftChangeRequest.fromFirestore(snapshot.docs.first);
  }

  // 労働時間集計（期間指定）
  Future<WorkTimeStats> calculateWorkTime(
    String employeeId,
    DateTime startDate,
    DateTime endDate,
    double hourlyWage,
  ) async {
    final shiftsSnapshot = await _firestore
        .collection('shifts')
        .where('employeeId', isEqualTo: employeeId)
        .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('shiftDate', isLessThan: Timestamp.fromDate(endDate.add(const Duration(days: 1))))
        .get();

    final shifts = shiftsSnapshot.docs.map((doc) => Shift.fromFirestore(doc)).toList();

    int totalMinutes = 0;
    int approvedMinutes = 0;
    int pendingMinutes = 0;

    for (final shift in shifts) {
      totalMinutes += shift.workMinutes;
      if (shift.status == ShiftStatus.approved) {
        approvedMinutes += shift.workMinutes;
      } else if (shift.status == ShiftStatus.pending) {
        pendingMinutes += shift.workMinutes;
      }
    }

    return WorkTimeStats(
      totalHours: totalMinutes / 60.0,
      approvedHours: approvedMinutes / 60.0,
      pendingHours: pendingMinutes / 60.0,
      estimatedEarnings: (approvedMinutes / 60.0) * hourlyWage,
      potentialEarnings: (totalMinutes / 60.0) * hourlyWage,
      shiftCount: shifts.length,
      approvedShiftCount: shifts.where((s) => s.status == ShiftStatus.approved).length,
    );
  }

  // 今月の労働時間集計
  Future<WorkTimeStats> calculateWorkTimeThisMonth(String employeeId, double hourlyWage) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return calculateWorkTime(employeeId, startOfMonth, endOfMonth, hourlyWage);
  }
}

class WorkTimeStats {
  final double totalHours;
  final double approvedHours;
  final double pendingHours;
  final double estimatedEarnings; // 承認済みシフトの見込み給与
  final double potentialEarnings; // 全シフト（承認待ち含む）の見込み給与
  final int shiftCount;
  final int approvedShiftCount;

  WorkTimeStats({
    required this.totalHours,
    required this.approvedHours,
    required this.pendingHours,
    required this.estimatedEarnings,
    required this.potentialEarnings,
    required this.shiftCount,
    required this.approvedShiftCount,
  });
}
