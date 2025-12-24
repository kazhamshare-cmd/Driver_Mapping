import 'package:cloud_firestore/cloud_firestore.dart';

/// 支払い方法設定
class PaymentMethodSetting {
  final String id;
  final String code;
  final String name;
  final String? nameEn;
  final String? nameTh;
  final String type; // 'cash', 'card', 'qr', 'transfer', 'other'
  final bool isActive;
  final int sortOrder;
  final String? icon;
  final String? color;

  PaymentMethodSetting({
    required this.id,
    required this.code,
    required this.name,
    this.nameEn,
    this.nameTh,
    required this.type,
    required this.isActive,
    required this.sortOrder,
    this.icon,
    this.color,
  });

  factory PaymentMethodSetting.fromMap(Map<String, dynamic> data) {
    return PaymentMethodSetting(
      id: data['id'] ?? '',
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      nameEn: data['nameEn'],
      nameTh: data['nameTh'],
      type: data['type'] ?? 'other',
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
      icon: data['icon'],
      color: data['color'],
    );
  }
}

class Shop {
  final String id;
  final String? shopCode;  // 店舗コード（QRコードURL用）
  final String shopName;
  final String ownerId;
  final String ownerEmail;
  final String? phoneNumber;
  final String? postalCode;
  final String? prefecture;
  final String? city;
  final String? address;
  final String? building;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // レシート設定
  final Map<String, dynamic>? receiptSettings;
  // 支払い方法マスタ
  final List<PaymentMethodSetting> paymentMethods;
  // 予約リソース設定（staff, room, table）
  final String? reservationResourceType;
  // モバイルオーダー有効フラグ
  final bool mobileOrderEnabled;

  Shop({
    required this.id,
    this.shopCode,
    required this.shopName,
    required this.ownerId,
    required this.ownerEmail,
    this.phoneNumber,
    this.postalCode,
    this.prefecture,
    this.city,
    this.address,
    this.building,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
    this.receiptSettings,
    this.paymentMethods = const [],
    this.reservationResourceType,
    this.mobileOrderEnabled = false,
  });

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 支払い方法を解析
    List<PaymentMethodSetting> paymentMethods = [];
    if (data['paymentMethods'] != null && data['paymentMethods'] is List) {
      paymentMethods = (data['paymentMethods'] as List)
          .map((m) => PaymentMethodSetting.fromMap(m as Map<String, dynamic>))
          .where((m) => m.isActive)
          .toList();
      paymentMethods.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return Shop(
      id: doc.id,
      shopCode: data['shopCode'],
      shopName: data['shopName'] ?? data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      phoneNumber: data['phoneNumber'],
      postalCode: data['postalCode'],
      prefecture: data['prefecture'],
      city: data['city'],
      address: data['address'],
      building: data['building'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      receiptSettings: data['receiptSettings'] as Map<String, dynamic>?,
      paymentMethods: paymentMethods,
      reservationResourceType: (data['reservationResourceSettings'] as Map<String, dynamic>?)?['resourceType'],
      mobileOrderEnabled: data['mobileOrderEnabled'] ?? false,
    );
  }
}
