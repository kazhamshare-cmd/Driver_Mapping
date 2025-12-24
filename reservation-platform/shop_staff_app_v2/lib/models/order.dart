import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  served,
  completed,
  cancelled,
}

enum PaymentStatus {
  unpaid,
  paid,
  refunded,
}

class OrderedBy {
  final String userId;
  final String? userName;
  final String? userPhone;
  final String? userEmail;
  final bool isStaffOrder;
  final String? staffId;
  final String? staffName;

  OrderedBy({
    required this.userId,
    this.userName,
    this.userPhone,
    this.userEmail,
    this.isStaffOrder = false,
    this.staffId,
    this.staffName,
  });

  factory OrderedBy.fromFirestore(Map<String, dynamic> data) {
    return OrderedBy(
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userPhone: data['userPhone'],
      userEmail: data['userEmail'],
      isStaffOrder: data['isStaffOrder'] ?? false,
      staffId: data['staffId'],
      staffName: data['staffName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'isStaffOrder': isStaffOrder,
      'staffId': staffId,
      'staffName': staffName,
    };
  }
}

class OrderItemOption {
  final String optionId;
  final String optionName;
  final String choiceId;
  final String choiceName;
  final double price;

  OrderItemOption({
    required this.optionId,
    required this.optionName,
    required this.choiceId,
    required this.choiceName,
    required this.price,
  });

  String get value => choiceName;

  factory OrderItemOption.fromFirestore(Map<String, dynamic> data) {
    return OrderItemOption(
      optionId: data['optionId'] ?? '',
      optionName: data['optionName'] ?? '',
      choiceId: data['choiceId'] ?? '',
      choiceName: data['choiceName'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'optionId': optionId,
      'optionName': optionName,
      'choiceId': choiceId,
      'choiceName': choiceName,
      'price': price,
    };
  }
}

/// 販売スタッフ情報
class SalesStaffInfo {
  final String staffId;
  final String staffName;
  final double shareRate;  // 分配率（例: 0.8 = 80%）
  final double? backRate;  // 個別バック率
  final double? backAmount;  // 計算済みバック金額

  SalesStaffInfo({
    required this.staffId,
    required this.staffName,
    required this.shareRate,
    this.backRate,
    this.backAmount,
  });

  factory SalesStaffInfo.fromMap(Map<String, dynamic> data) {
    return SalesStaffInfo(
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      shareRate: (data['shareRate'] ?? 1.0).toDouble(),
      backRate: data['backRate']?.toDouble(),
      backAmount: data['backAmount']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'shareRate': shareRate,
      if (backRate != null) 'backRate': backRate,
      if (backAmount != null) 'backAmount': backAmount,
    };
  }
}

/// 原価情報
class CostInfo {
  final double cost;  // 商品原価
  final double baseBackRate;  // 基本バック率

  CostInfo({
    required this.cost,
    required this.baseBackRate,
  });

  factory CostInfo.fromMap(Map<String, dynamic> data) {
    return CostInfo(
      cost: (data['cost'] ?? 0).toDouble(),
      baseBackRate: (data['baseBackRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cost': cost,
      'baseBackRate': baseBackRate,
    };
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String? categoryId;  // カテゴリID（キッチン担当別フィルター用）
  final String productName;
  final String? productNameEn;
  final String? productNameTh;
  final int quantity;
  final double unitPrice;
  final List<OrderItemOption> selectedOptions;
  final double subtotal;
  final String? notes;
  final String status;
  final bool isAskPrice;  // ASK商品（価格後入力）
  final double? askPrice;  // 入力された価格
  final CostInfo? costInfo;  // 原価情報
  final List<SalesStaffInfo>? salesStaff;  // 販売スタッフ情報
  final Map<String, dynamic>? discountInfo;  // 割引情報（元価格、割引タイプ、割引値）

  OrderItem({
    required this.id,
    required this.productId,
    this.categoryId,
    required this.productName,
    this.productNameEn,
    this.productNameTh,
    required this.quantity,
    required this.unitPrice,
    required this.selectedOptions,
    required this.subtotal,
    this.notes,
    this.status = 'pending',
    this.isAskPrice = false,
    this.askPrice,
    this.costInfo,
    this.salesStaff,
    this.discountInfo,
  });

  factory OrderItem.fromFirestore(Map<String, dynamic> data) {
    // ▼▼▼ 修正箇所：オプションの読み込みロジックを強化 ▼▼▼
    List<OrderItemOption> options = [];
    
    // Reactアプリ(MobileOrderPage)は 'options' フィールドに保存している
    var rawOptions = data['options'];
    // 互換性のため 'selectedOptions' も確認
    if (rawOptions == null) {
      rawOptions = data['selectedOptions'];
    }

    if (rawOptions != null && rawOptions is List) {
      for (var opt in rawOptions) {
        if (opt is Map<String, dynamic>) {
          // パターンA: Reactアプリ形式（ネストされた choices 配列がある）
          if (opt['choices'] != null && opt['choices'] is List) {
            final choices = opt['choices'] as List;
            for (var choice in choices) {
              if (choice is Map<String, dynamic>) {
                options.add(OrderItemOption(
                  optionId: opt['optionId'] ?? '',
                  optionName: opt['optionName'] ?? '',
                  choiceId: choice['id'] ?? '',
                  choiceName: choice['name'] ?? '',
                  price: (choice['price'] ?? 0).toDouble(),
                ));
              }
            }
          } 
          // パターンB: フラットな構造（既存アプリ形式）
          else if (opt['choiceName'] != null) {
             options.add(OrderItemOption.fromFirestore(opt));
          }
        }
      }
    }
    // ▲▲▲ 修正箇所ここまで ▲▲▲

    // 原価情報
    CostInfo? costInfo;
    if (data['costInfo'] != null && data['costInfo'] is Map<String, dynamic>) {
      costInfo = CostInfo.fromMap(data['costInfo']);
    }

    // 販売スタッフ情報
    List<SalesStaffInfo>? salesStaff;
    if (data['salesStaff'] != null && data['salesStaff'] is List) {
      salesStaff = (data['salesStaff'] as List)
          .map((s) => SalesStaffInfo.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    return OrderItem(
      id: data['id'] ?? '',
      productId: data['productId'] ?? '',
      categoryId: data['categoryId'],  // カテゴリID
      productName: data['productName'] ?? '',
      productNameEn: data['productNameEn'],
      productNameTh: data['productNameTh'],
      quantity: data['quantity'] ?? 0,
      unitPrice: (data['price'] ?? data['unitPrice'] ?? 0).toDouble(),
      selectedOptions: options,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      notes: data['notes'] ?? data['note'],
      status: data['status'] ?? 'pending',
      isAskPrice: data['isAskPrice'] ?? false,
      askPrice: data['askPrice'] != null ? (data['askPrice']).toDouble() : null,
      costInfo: costInfo,
      salesStaff: salesStaff,
      discountInfo: data['discountInfo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productId': productId,
      'categoryId': categoryId,  // カテゴリID
      'productName': productName,
      'productNameEn': productNameEn,
      'productNameTh': productNameTh,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'selectedOptions': selectedOptions.map((opt) => opt.toFirestore()).toList(),
      'subtotal': subtotal,
      'notes': notes,
      'status': status,
      'isAskPrice': isAskPrice,
      'askPrice': askPrice,
      if (costInfo != null) 'costInfo': costInfo!.toMap(),
      if (salesStaff != null && salesStaff!.isNotEmpty)
        'salesStaff': salesStaff!.map((s) => s.toMap()).toList(),
      if (discountInfo != null) 'discountInfo': discountInfo,
    };
  }

  /// ASK商品の実際の価格（askPriceが設定されていればそれ、なければunitPrice）
  double get effectivePrice => isAskPrice && askPrice != null ? askPrice! : unitPrice;

  /// ASK商品の実際の小計
  double get effectiveSubtotal => isAskPrice && askPrice != null ? askPrice! * quantity : subtotal;
}

/// キャンセル情報
class CancelInfo {
  final String? staffId;
  final String? staffName;
  final String? reason;
  final DateTime cancelledAt;

  CancelInfo({
    this.staffId,
    this.staffName,
    this.reason,
    required this.cancelledAt,
  });

  factory CancelInfo.fromMap(Map<String, dynamic> data) {
    return CancelInfo(
      staffId: data['staffId'],
      staffName: data['staffName'],
      reason: data['reason'],
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'reason': reason,
      'cancelledAt': Timestamp.fromDate(cancelledAt),
    };
  }
}

class OrderModel {
  final String id;
  final String shopId;
  final String tableId;
  final String tableNumber;
  final String orderNumber;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final OrderedBy? orderedBy;
  final String? notes;
  final DateTime orderedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? printedAt;  // キッチン伝票印刷済み日時
  final CancelInfo? cancelInfo;  // キャンセル情報
  final String? paymentMethod;  // 支払い方法
  final double? receivedAmount;  // お預かり金額
  final double? changeAmount;  // お釣り

  OrderModel({
    required this.id,
    required this.shopId,
    required this.tableId,
    required this.tableNumber,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.status,
    required this.paymentStatus,
    this.orderedBy,
    this.notes,
    required this.orderedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.printedAt,
    this.cancelInfo,
    this.paymentMethod,
    this.receivedAmount,
    this.changeAmount,
  });

  /// 印刷済みかどうか
  bool get isPrinted => printedAt != null;

  /// キャンセル済みかどうか
  bool get isCancelled => status == OrderStatus.cancelled;

  double get totalAmount => total;

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final itemsList = data['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((item) => OrderItem.fromFirestore(item as Map<String, dynamic>))
        .toList();

    final DateTime now = DateTime.now();
    final DateTime createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
    final DateTime updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? now;
    final DateTime orderedAt = (data['orderedAt'] as Timestamp?)?.toDate() ?? createdAt;

    return OrderModel(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      tableId: data['tableId'] ?? '',
      tableNumber: data['tableNumber']?.toString() ?? '',
      orderNumber: data['orderNumber']?.toString() ?? '',
      items: items,
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      status: _parseOrderStatus(data['status']),
      paymentStatus: _parsePaymentStatus(data['paymentStatus']),
      orderedBy: data['orderedBy'] != null
          ? OrderedBy.fromFirestore(data['orderedBy'] as Map<String, dynamic>)
          : null,
      notes: data['notes'],
      orderedAt: orderedAt,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      printedAt: (data['printedAt'] as Timestamp?)?.toDate(),
      cancelInfo: data['cancelInfo'] != null
          ? CancelInfo.fromMap(data['cancelInfo'] as Map<String, dynamic>)
          : null,
      paymentMethod: data['paymentMethod'],
      receivedAmount: (data['receivedAmount'] as num?)?.toDouble(),
      changeAmount: (data['changeAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'tableId': tableId,
      'tableNumber': tableNumber,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toFirestore()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'status': status.name,
      'paymentStatus': paymentStatus.name,
      'orderedBy': orderedBy?.toFirestore(),
      'notes': notes,
      'orderedAt': Timestamp.fromDate(orderedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'printedAt': printedAt != null ? Timestamp.fromDate(printedAt!) : null,
      'cancelInfo': cancelInfo?.toMap(),
      'paymentMethod': paymentMethod,
      'receivedAmount': receivedAmount,
      'changeAmount': changeAmount,
    };
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
        return OrderStatus.served;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'paid':
        return PaymentStatus.paid;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.unpaid;
    }
  }

  String getStatusText() {
    switch (status) {
      case OrderStatus.pending:
        return '注文受付';
      case OrderStatus.confirmed:
        return '確認済み';
      case OrderStatus.preparing:
        return '準備中';
      case OrderStatus.ready:
        return '提供準備完了';
      case OrderStatus.served:
        return '提供済み';
      case OrderStatus.completed:
        return '会計済み';
      case OrderStatus.cancelled:
        return 'キャンセル';
    }
  }

  String getPaymentStatusText() {
    switch (paymentStatus) {
      case PaymentStatus.unpaid:
        return '未払い';
      case PaymentStatus.paid:
        return '支払済み';
      case PaymentStatus.refunded:
        return '返金済み';
    }
  }
}