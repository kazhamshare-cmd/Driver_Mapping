import 'package:cloud_firestore/cloud_firestore.dart';

/// 来店セッションのステータス
enum SessionStatus {
  inProgress, // 利用中
  completed,  // 完了（会計済み）
  cancelled,  // キャンセル
}

/// セッション内の注文アイテム
class SessionItem {
  final String id;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final String? performerStaffId; // 施術者/担当者
  final String? referrerStaffId;  // 紹介者（物販の場合）
  final double? nominationFee;    // 指名料
  final Map<String, dynamic>? options; // オプション選択
  final DateTime createdAt;

  SessionItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.performerStaffId,
    this.referrerStaffId,
    this.nominationFee,
    this.options,
    required this.createdAt,
  });

  factory SessionItem.fromMap(Map<String, dynamic> data) {
    return SessionItem(
      id: data['id'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      performerStaffId: data['performerStaffId'],
      referrerStaffId: data['referrerStaffId'],
      nominationFee: (data['nominationFee'] as num?)?.toDouble(),
      options: data['options'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      if (performerStaffId != null) 'performerStaffId': performerStaffId,
      if (referrerStaffId != null) 'referrerStaffId': referrerStaffId,
      if (nominationFee != null) 'nominationFee': nominationFee,
      if (options != null) 'options': options,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// アイテムの合計金額（指名料含む）
  double get totalWithNomination => subtotal + (nominationFee ?? 0);
}

/// スタッフへのバック/コミッション
class StaffCommission {
  final String staffId;
  final String staffName;
  final String type; // 'service', 'nomination', 'sales', 'referral'
  final double amount;
  final String? productId;
  final String? productName;

  StaffCommission({
    required this.staffId,
    required this.staffName,
    required this.type,
    required this.amount,
    this.productId,
    this.productName,
  });

  factory StaffCommission.fromMap(Map<String, dynamic> data) {
    return StaffCommission(
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      type: data['type'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      productId: data['productId'],
      productName: data['productName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'type': type,
      'amount': amount,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
    };
  }
}

/// 来店セッション
class Session {
  final String id;
  final String shopId;
  final String? reservationId; // 予約からの場合
  final String? customerId;
  final String? customerName;

  // 人数関連（主に飲食店）
  final int? reservedCount;  // 予約人数
  final int actualCount;      // 実来店人数

  // 席・担当
  final String? tableId;
  final String? tableName;
  final String? primaryStaffId;  // 主担当/指名スタッフ
  final String? primaryStaffName;

  // 時間
  final DateTime startTime;
  final DateTime? endTime;

  // ステータス
  final SessionStatus status;

  // 注文アイテム
  final List<SessionItem> items;

  // 会計情報
  final String? paymentId;
  final double? totalAmount;
  final double? nominationTotal; // 指名料合計
  final List<StaffCommission>? staffCommissions;

  // メタ情報
  final String? createdBy; // セッション開始したスタッフID
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
    required this.id,
    required this.shopId,
    this.reservationId,
    this.customerId,
    this.customerName,
    this.reservedCount,
    required this.actualCount,
    this.tableId,
    this.tableName,
    this.primaryStaffId,
    this.primaryStaffName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.items,
    this.paymentId,
    this.totalAmount,
    this.nominationTotal,
    this.staffCommissions,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // アイテムのパース
    final itemsData = data['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => SessionItem.fromMap(item as Map<String, dynamic>))
        .toList();

    // コミッションのパース
    final commissionsData = data['staffCommissions'] as List<dynamic>?;
    final commissions = commissionsData
        ?.map((c) => StaffCommission.fromMap(c as Map<String, dynamic>))
        .toList();

    // ステータスのパース
    SessionStatus status;
    switch (data['status']) {
      case 'completed':
        status = SessionStatus.completed;
        break;
      case 'cancelled':
        status = SessionStatus.cancelled;
        break;
      default:
        status = SessionStatus.inProgress;
    }

    return Session(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      reservationId: data['reservationId'],
      customerId: data['customerId'],
      customerName: data['customerName'],
      reservedCount: data['reservedCount'],
      actualCount: data['actualCount'] ?? 1,
      tableId: data['tableId'],
      tableName: data['tableName'],
      primaryStaffId: data['primaryStaffId'],
      primaryStaffName: data['primaryStaffName'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      status: status,
      items: items,
      paymentId: data['paymentId'],
      totalAmount: (data['totalAmount'] as num?)?.toDouble(),
      nominationTotal: (data['nominationTotal'] as num?)?.toDouble(),
      staffCommissions: commissions,
      createdBy: data['createdBy'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    String statusStr;
    switch (status) {
      case SessionStatus.completed:
        statusStr = 'completed';
        break;
      case SessionStatus.cancelled:
        statusStr = 'cancelled';
        break;
      default:
        statusStr = 'in_progress';
    }

    return {
      'shopId': shopId,
      if (reservationId != null) 'reservationId': reservationId,
      if (customerId != null) 'customerId': customerId,
      if (customerName != null) 'customerName': customerName,
      if (reservedCount != null) 'reservedCount': reservedCount,
      'actualCount': actualCount,
      if (tableId != null) 'tableId': tableId,
      if (tableName != null) 'tableName': tableName,
      if (primaryStaffId != null) 'primaryStaffId': primaryStaffId,
      if (primaryStaffName != null) 'primaryStaffName': primaryStaffName,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'status': statusStr,
      'items': items.map((item) => item.toMap()).toList(),
      if (paymentId != null) 'paymentId': paymentId,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (nominationTotal != null) 'nominationTotal': nominationTotal,
      if (staffCommissions != null)
        'staffCommissions': staffCommissions!.map((c) => c.toMap()).toList(),
      if (createdBy != null) 'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// 利用中かどうか
  bool get isInProgress => status == SessionStatus.inProgress;

  /// 完了済みかどうか
  bool get isCompleted => status == SessionStatus.completed;

  /// アイテムの小計
  double get itemsSubtotal =>
      items.fold(0, (sum, item) => sum + item.subtotal);

  /// 指名料の合計
  double get calculatedNominationTotal =>
      items.fold(0, (sum, item) => sum + (item.nominationFee ?? 0));

  /// 合計金額
  double get calculatedTotal => itemsSubtotal + calculatedNominationTotal;

  /// アイテムを追加した新しいセッションを返す
  Session addItem(SessionItem item) {
    return copyWith(
      items: [...items, item],
      updatedAt: DateTime.now(),
    );
  }

  /// コピーメソッド
  Session copyWith({
    String? id,
    String? shopId,
    String? reservationId,
    String? customerId,
    String? customerName,
    int? reservedCount,
    int? actualCount,
    String? tableId,
    String? tableName,
    String? primaryStaffId,
    String? primaryStaffName,
    DateTime? startTime,
    DateTime? endTime,
    SessionStatus? status,
    List<SessionItem>? items,
    String? paymentId,
    double? totalAmount,
    double? nominationTotal,
    List<StaffCommission>? staffCommissions,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      reservationId: reservationId ?? this.reservationId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      reservedCount: reservedCount ?? this.reservedCount,
      actualCount: actualCount ?? this.actualCount,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      primaryStaffId: primaryStaffId ?? this.primaryStaffId,
      primaryStaffName: primaryStaffName ?? this.primaryStaffName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      items: items ?? this.items,
      paymentId: paymentId ?? this.paymentId,
      totalAmount: totalAmount ?? this.totalAmount,
      nominationTotal: nominationTotal ?? this.nominationTotal,
      staffCommissions: staffCommissions ?? this.staffCommissions,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
