import 'package:cloud_firestore/cloud_firestore.dart';

/// 予約ブロック種別
enum ReservationBlockType {
  /// 臨時休業
  closed,
  /// 予約受付停止
  noReservation,
  /// 満席
  full,
  /// スタッフ休暇
  staffOff,
  /// その他
  other;

  String get label {
    switch (this) {
      case ReservationBlockType.closed:
        return '臨時休業';
      case ReservationBlockType.noReservation:
        return '予約受付停止';
      case ReservationBlockType.full:
        return '満席';
      case ReservationBlockType.staffOff:
        return 'スタッフ休暇';
      case ReservationBlockType.other:
        return 'その他';
    }
  }

  static ReservationBlockType fromString(String value) {
    switch (value) {
      case 'closed':
        return ReservationBlockType.closed;
      case 'noReservation':
        return ReservationBlockType.noReservation;
      case 'full':
        return ReservationBlockType.full;
      case 'staffOff':
        return ReservationBlockType.staffOff;
      default:
        return ReservationBlockType.other;
    }
  }

  String toFirestore() {
    switch (this) {
      case ReservationBlockType.closed:
        return 'closed';
      case ReservationBlockType.noReservation:
        return 'noReservation';
      case ReservationBlockType.full:
        return 'full';
      case ReservationBlockType.staffOff:
        return 'staffOff';
      case ReservationBlockType.other:
        return 'other';
    }
  }
}

/// 予約ブロック（特定の時間帯の予約受付を停止）
class ReservationBlock {
  final String id;
  final String shopId;
  final DateTime date;
  final String? startTime; // null = 終日
  final String? endTime;   // null = 終日
  final bool isAllDay;
  final ReservationBlockType type;
  final String? staffId;   // スタッフ休暇の場合
  final String? staffName;
  final String? reason;
  final DateTime createdAt;
  final String createdBy;

  ReservationBlock({
    required this.id,
    required this.shopId,
    required this.date,
    this.startTime,
    this.endTime,
    this.isAllDay = false,
    required this.type,
    this.staffId,
    this.staffName,
    this.reason,
    required this.createdAt,
    required this.createdBy,
  });

  factory ReservationBlock.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReservationBlock(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'],
      endTime: data['endTime'],
      isAllDay: data['isAllDay'] ?? false,
      type: ReservationBlockType.fromString(data['type'] ?? 'other'),
      staffId: data['staffId'],
      staffName: data['staffName'],
      reason: data['reason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'date': Timestamp.fromDate(date),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'isAllDay': isAllDay,
      'type': type.toFirestore(),
      if (staffId != null) 'staffId': staffId,
      if (staffName != null) 'staffName': staffName,
      if (reason != null) 'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  /// 時間帯の表示文字列
  String get timeRangeLabel {
    if (isAllDay) return '終日';
    if (startTime == null || endTime == null) return '終日';
    return '$startTime - $endTime';
  }
}
