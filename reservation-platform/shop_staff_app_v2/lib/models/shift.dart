import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftStatus {
  pending,    // 希望中
  approved,   // 承認済み
  rejected,   // 却下
}

class Shift {
  final String id;
  final String shopId;
  final String employeeId;
  final DateTime shiftDate;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final String shiftType;
  final String? note;
  final ShiftStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Shift({
    required this.id,
    required this.shopId,
    required this.employeeId,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.breakMinutes,
    required this.shiftType,
    this.note,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Shift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shift(
      id: doc.id,
      shopId: data['shopId'] as String,
      employeeId: data['employeeId'] as String,
      shiftDate: (data['shiftDate'] as Timestamp).toDate(),
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      breakMinutes: data['breakMinutes'] as int? ?? 0,
      shiftType: data['shiftType'] as String? ?? 'regular',
      note: data['note'] as String?,
      status: _parseStatus(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static ShiftStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return ShiftStatus.approved;
      case 'rejected':
        return ShiftStatus.rejected;
      default:
        return ShiftStatus.pending;
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

  // 労働時間（時間単位、小数点）
  double get workHours => workMinutes / 60.0;

  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
