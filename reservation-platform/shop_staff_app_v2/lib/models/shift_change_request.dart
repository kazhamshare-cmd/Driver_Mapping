import 'package:cloud_firestore/cloud_firestore.dart';

/// シフト変更希望タイプ
enum ShiftChangeType {
  dayOff,     // 休みたい
  swap,       // 交代希望
}

/// シフト変更希望ステータス
enum ShiftChangeStatus {
  pending,    // 申請中
  approved,   // 承認済み
  rejected,   // 却下
  covered,    // 代わりが見つかった
}

/// シフト変更希望モデル
class ShiftChangeRequest {
  final String id;
  final String shopId;
  final String shiftId;            // 対象シフトID
  final String employeeId;          // 申請者ID
  final String employeeName;        // 申請者名
  final ShiftChangeType changeType; // 変更タイプ
  final String reason;              // 理由
  final ShiftChangeStatus status;   // ステータス
  final DateTime shiftDate;         // シフト日
  final String startTime;           // シフト開始時間
  final String endTime;             // シフト終了時間
  final int breakMinutes;           // 休憩時間
  final String? coveredByEmployeeId;   // 代わりのスタッフID
  final String? coveredByEmployeeName; // 代わりのスタッフ名
  final String? reviewedByStaffId;     // 承認/却下したスタッフID
  final String? reviewedByStaffName;   // 承認/却下したスタッフ名
  final String? reviewNote;            // 承認/却下時のコメント
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  ShiftChangeRequest({
    required this.id,
    required this.shopId,
    required this.shiftId,
    required this.employeeId,
    required this.employeeName,
    required this.changeType,
    required this.reason,
    required this.status,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.breakMinutes,
    this.coveredByEmployeeId,
    this.coveredByEmployeeName,
    this.reviewedByStaffId,
    this.reviewedByStaffName,
    this.reviewNote,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
  });

  factory ShiftChangeRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftChangeRequest(
      id: doc.id,
      shopId: data['shopId'] as String,
      shiftId: data['shiftId'] as String,
      employeeId: data['employeeId'] as String,
      employeeName: data['employeeName'] as String? ?? '',
      changeType: _parseChangeType(data['changeType'] as String?),
      reason: data['reason'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      shiftDate: (data['shiftDate'] as Timestamp).toDate(),
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      breakMinutes: data['breakMinutes'] as int? ?? 0,
      coveredByEmployeeId: data['coveredByEmployeeId'] as String?,
      coveredByEmployeeName: data['coveredByEmployeeName'] as String?,
      reviewedByStaffId: data['reviewedByStaffId'] as String?,
      reviewedByStaffName: data['reviewedByStaffName'] as String?,
      reviewNote: data['reviewNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'shiftId': shiftId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'changeType': changeType.name,
      'reason': reason,
      'status': status.name,
      'shiftDate': Timestamp.fromDate(shiftDate),
      'startTime': startTime,
      'endTime': endTime,
      'breakMinutes': breakMinutes,
      'coveredByEmployeeId': coveredByEmployeeId,
      'coveredByEmployeeName': coveredByEmployeeName,
      'reviewedByStaffId': reviewedByStaffId,
      'reviewedByStaffName': reviewedByStaffName,
      'reviewNote': reviewNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  static ShiftChangeType _parseChangeType(String? type) {
    switch (type) {
      case 'swap':
        return ShiftChangeType.swap;
      default:
        return ShiftChangeType.dayOff;
    }
  }

  static ShiftChangeStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return ShiftChangeStatus.approved;
      case 'rejected':
        return ShiftChangeStatus.rejected;
      case 'covered':
        return ShiftChangeStatus.covered;
      default:
        return ShiftChangeStatus.pending;
    }
  }

  /// 変更タイプのテキスト
  String getChangeTypeText() {
    switch (changeType) {
      case ShiftChangeType.dayOff:
        return '休み希望';
      case ShiftChangeType.swap:
        return '交代希望';
    }
  }

  /// ステータスのテキスト
  String getStatusText() {
    switch (status) {
      case ShiftChangeStatus.pending:
        return '申請中';
      case ShiftChangeStatus.approved:
        return '承認済み';
      case ShiftChangeStatus.rejected:
        return '却下';
      case ShiftChangeStatus.covered:
        return '代替者決定';
    }
  }

  // 労働時間を計算（分単位）
  int get workMinutes {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    int minutes = end - start - breakMinutes;

    // 翌日にまたがる場合
    if (end < start) {
      minutes = (24 * 60) - start + end - breakMinutes;
    }

    return minutes > 0 ? minutes : 0;
  }

  double get workHours => workMinutes / 60.0;

  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
