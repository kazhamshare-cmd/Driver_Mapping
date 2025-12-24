import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  completed,
  noShow;

  String get label {
    switch (this) {
      case ReservationStatus.pending:
        return '承認待ち';
      case ReservationStatus.confirmed:
        return '確定';
      case ReservationStatus.cancelled:
        return 'キャンセル';
      case ReservationStatus.completed:
        return '完了';
      case ReservationStatus.noShow:
        return '無断キャンセル';
    }
  }

  static ReservationStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return ReservationStatus.pending;
      case 'confirmed':
        return ReservationStatus.confirmed;
      case 'cancelled':
        return ReservationStatus.cancelled;
      case 'completed':
        return ReservationStatus.completed;
      case 'no_show':
        return ReservationStatus.noShow;
      default:
        return ReservationStatus.pending;
    }
  }

  String toFirestore() {
    switch (this) {
      case ReservationStatus.pending:
        return 'pending';
      case ReservationStatus.confirmed:
        return 'confirmed';
      case ReservationStatus.cancelled:
        return 'cancelled';
      case ReservationStatus.completed:
        return 'completed';
      case ReservationStatus.noShow:
        return 'no_show';
    }
  }
}

class Reservation {
  final String id;
  final String shopId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final String? userLineId;
  final String menuId;
  final String menuName;
  final String? staffId;
  final String? staffName;
  final DateTime reservationDate;
  final String startTime;
  final String endTime;
  final int duration;
  final double totalPrice;
  final int? numberOfPeople;
  final ReservationStatus status;
  final String? notes;
  final String? cancellationReason;
  final String? cancelledBy; // 'shop' or 'customer'
  final DateTime? checkedInAt;
  final String? tableId;
  final String? tableNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 席種別選択方式用フィールド
  final String? seatType;           // 希望席種別
  final List<String> requestedFeatures; // 希望条件
  final List<String> tableIds;      // 割り当てられたテーブルID（複数可）
  final bool isCombined;            // 結合予約かどうか

  /// 席種別の表示名を取得
  String get seatTypeName {
    switch (seatType) {
      case 'counter':
        return 'カウンター';
      case 'table':
        return 'テーブル席';
      case 'privateRoom':
        return '個室';
      case 'semiPrivate':
        return '半個室';
      case 'tatami':
        return '座敷';
      case 'terrace':
        return 'テラス';
      default:
        return seatType ?? '指定なし';
    }
  }

  /// 希望条件の表示名リストを取得
  List<String> get requestedFeatureNames {
    return requestedFeatures.map((f) {
      switch (f) {
        case 'smoking':
          return '喫煙可';
        case 'window':
          return '窓際';
        case 'kids':
          return '子連れOK';
        case 'wheelchair':
          return '車椅子対応';
        case 'horigotatsu':
          return '掘りごたつ';
        default:
          return f;
      }
    }).toList();
  }

  Reservation({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.userLineId,
    required this.menuId,
    required this.menuName,
    this.staffId,
    this.staffName,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalPrice,
    this.numberOfPeople,
    required this.status,
    this.notes,
    this.cancellationReason,
    this.cancelledBy,
    this.checkedInAt,
    this.tableId,
    this.tableNumber,
    required this.createdAt,
    required this.updatedAt,
    this.seatType,
    this.requestedFeatures = const [],
    this.tableIds = const [],
    this.isCombined = false,
  });

  factory Reservation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Reservation(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userPhone: data['userPhone'] ?? '',
      userLineId: data['userLineId'],
      menuId: data['menuId'] ?? '',
      menuName: data['menuName'] ?? '',
      staffId: data['staffId'],
      staffName: data['staffName'],
      reservationDate: (data['reservationDate'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      duration: data['duration'] ?? 0,
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      numberOfPeople: data['numberOfPeople'],
      status: ReservationStatus.fromString(data['status'] ?? 'pending'),
      notes: data['notes'],
      cancellationReason: data['cancellationReason'],
      cancelledBy: data['cancelledBy'],
      checkedInAt: data['checkedInAt'] != null
          ? (data['checkedInAt'] as Timestamp).toDate()
          : null,
      tableId: data['tableId'],
      tableNumber: data['tableNumber'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      seatType: data['seatType'],
      requestedFeatures: List<String>.from(data['requestedFeatures'] ?? []),
      tableIds: List<String>.from(data['tableIds'] ?? []),
      isCombined: data['isCombined'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      if (userLineId != null) 'userLineId': userLineId,
      'menuId': menuId,
      'menuName': menuName,
      if (staffId != null) 'staffId': staffId,
      if (staffName != null) 'staffName': staffName,
      'reservationDate': Timestamp.fromDate(reservationDate),
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'totalPrice': totalPrice,
      if (numberOfPeople != null) 'numberOfPeople': numberOfPeople,
      'status': status.toFirestore(),
      if (notes != null) 'notes': notes,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (cancelledBy != null) 'cancelledBy': cancelledBy,
      if (checkedInAt != null) 'checkedInAt': Timestamp.fromDate(checkedInAt!),
      if (tableId != null) 'tableId': tableId,
      if (tableNumber != null) 'tableNumber': tableNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (seatType != null) 'seatType': seatType,
      'requestedFeatures': requestedFeatures,
      'tableIds': tableIds,
      'isCombined': isCombined,
    };
  }

  Reservation copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    String? userLineId,
    String? menuId,
    String? menuName,
    String? staffId,
    String? staffName,
    DateTime? reservationDate,
    String? startTime,
    String? endTime,
    int? duration,
    double? totalPrice,
    int? numberOfPeople,
    ReservationStatus? status,
    String? notes,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? checkedInAt,
    String? tableId,
    String? tableNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? seatType,
    List<String>? requestedFeatures,
    List<String>? tableIds,
    bool? isCombined,
  }) {
    return Reservation(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      userLineId: userLineId ?? this.userLineId,
      menuId: menuId ?? this.menuId,
      menuName: menuName ?? this.menuName,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      reservationDate: reservationDate ?? this.reservationDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      totalPrice: totalPrice ?? this.totalPrice,
      numberOfPeople: numberOfPeople ?? this.numberOfPeople,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      seatType: seatType ?? this.seatType,
      requestedFeatures: requestedFeatures ?? this.requestedFeatures,
      tableIds: tableIds ?? this.tableIds,
      isCombined: isCombined ?? this.isCombined,
    );
  }
}
