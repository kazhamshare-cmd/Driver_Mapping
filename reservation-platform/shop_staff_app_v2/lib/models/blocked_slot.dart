import 'package:cloud_firestore/cloud_firestore.dart';

/// 受付不可ブロック
class BlockedSlot {
  final String id;
  final String shopId;
  final String? staffId;      // null = 店舗全体、指定 = 特定スタッフのみ
  final String? staffName;    // 表示用
  final DateTime date;
  final String startTime;     // "12:00"
  final String endTime;       // "14:00"
  final String? reason;       // "休憩" "満席" "研修" など
  final bool isAllDay;        // 終日ブロック
  final String createdBy;
  final DateTime createdAt;

  BlockedSlot({
    required this.id,
    required this.shopId,
    this.staffId,
    this.staffName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.reason,
    this.isAllDay = false,
    required this.createdBy,
    required this.createdAt,
  });

  factory BlockedSlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BlockedSlot(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      staffId: data['staffId'],
      staffName: data['staffName'],
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      reason: data['reason'],
      isAllDay: data['isAllDay'] ?? false,
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      if (staffId != null) 'staffId': staffId,
      if (staffName != null) 'staffName': staffName,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'startTime': startTime,
      'endTime': endTime,
      if (reason != null) 'reason': reason,
      'isAllDay': isAllDay,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 開始時刻をDateTimeで取得
  DateTime get startDateTime {
    final parts = startTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 終了時刻をDateTimeで取得
  DateTime get endDateTime {
    final parts = endTime.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// 指定時刻がブロック範囲内かチェック
  bool containsTime(String time) {
    final timeParts = time.split(':');
    final checkMinutes = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);

    final startParts = startTime.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final endParts = endTime.split(':');
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    return checkMinutes >= startMinutes && checkMinutes < endMinutes;
  }

  /// 時間範囲が重複するかチェック
  bool overlaps(String otherStart, String otherEnd) {
    final startParts = startTime.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final endParts = endTime.split(':');
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    final otherStartParts = otherStart.split(':');
    final otherStartMinutes = int.parse(otherStartParts[0]) * 60 + int.parse(otherStartParts[1]);

    final otherEndParts = otherEnd.split(':');
    final otherEndMinutes = int.parse(otherEndParts[0]) * 60 + int.parse(otherEndParts[1]);

    return startMinutes < otherEndMinutes && endMinutes > otherStartMinutes;
  }

  BlockedSlot copyWith({
    String? id,
    String? shopId,
    String? staffId,
    String? staffName,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? reason,
    bool? isAllDay,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return BlockedSlot(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      reason: reason ?? this.reason,
      isAllDay: isAllDay ?? this.isAllDay,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
