import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftRequest {
  final String id;
  final String shopId;
  final String requestType; // 'shift_wanted', 'shift_change'
  final NewShiftData? newShift;
  final bool isOpenToAll;
  final String status; // 'open', 'closed'
  final List<WorkerResponse> responses;
  final String? message;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  // シフト交代募集用の追加フィールド
  final String? changeRequestId;      // 元のShiftChangeRequestのID
  final String? originalEmployeeId;   // 交代を希望しているスタッフID
  final String? originalEmployeeName; // 交代を希望しているスタッフ名

  ShiftRequest({
    required this.id,
    required this.shopId,
    required this.requestType,
    this.newShift,
    required this.isOpenToAll,
    required this.status,
    required this.responses,
    this.message,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.changeRequestId,
    this.originalEmployeeId,
    this.originalEmployeeName,
  });

  /// シフト交代募集かどうか
  bool get isShiftChange => requestType == 'shift_change';

  factory ShiftRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShiftRequest(
      id: doc.id,
      shopId: data['shopId'] as String,
      requestType: data['requestType'] as String,
      newShift: data['newShift'] != null
          ? NewShiftData.fromMap(data['newShift'] as Map<String, dynamic>)
          : null,
      isOpenToAll: data['isOpenToAll'] as bool? ?? false,
      status: data['status'] as String,
      responses: (data['responses'] as List<dynamic>?)
              ?.map((r) => WorkerResponse.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      message: data['message'] as String?,
      title: data['title'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      changeRequestId: data['changeRequestId'] as String?,
      originalEmployeeId: data['originalEmployeeId'] as String?,
      originalEmployeeName: data['originalEmployeeName'] as String?,
    );
  }

  // 自分が既に応募しているかチェック
  bool hasResponded(String employeeId) {
    return responses.any((r) => r.employeeId == employeeId);
  }

  // 募集人数に対する応募状況
  String getResponseStatus() {
    final required = newShift?.requiredStaffCount ?? 1;
    final responseCount = responses.length;
    return '$responseCount/$required名応募';
  }
}

class NewShiftData {
  final DateTime shiftDate;
  final String startTime;
  final String endTime;
  final int breakMinutes;
  final String? position;
  final int requiredStaffCount;

  NewShiftData({
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.breakMinutes,
    this.position,
    required this.requiredStaffCount,
  });

  factory NewShiftData.fromMap(Map<String, dynamic> map) {
    return NewShiftData(
      shiftDate: (map['shiftDate'] as Timestamp).toDate(),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      breakMinutes: map['breakMinutes'] as int? ?? 0,
      position: map['position'] as String?,
      requiredStaffCount: map['requiredStaffCount'] as int? ?? 1,
    );
  }

  // 労働時間を計算（分単位）
  int get workMinutes {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    int minutes = end - start - breakMinutes;

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

class WorkerResponse {
  final String employeeId;
  final String? employeeName;
  final DateTime respondedAt;
  final String status; // 'pending', 'accepted', 'rejected'

  WorkerResponse({
    required this.employeeId,
    this.employeeName,
    required this.respondedAt,
    required this.status,
  });

  factory WorkerResponse.fromMap(Map<String, dynamic> map) {
    return WorkerResponse(
      employeeId: map['employeeId'] as String,
      employeeName: map['employeeName'] as String?,
      respondedAt: (map['respondedAt'] as Timestamp).toDate(),
      status: map['status'] as String? ?? 'pending',
    );
  }
}
