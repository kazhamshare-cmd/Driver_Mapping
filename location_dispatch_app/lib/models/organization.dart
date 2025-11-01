import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'business_type.dart';
import 'subscription_plan.dart';

class Organization {
  final String id;
  final String name;
  final String? companyName;
  final BusinessType businessType;
  final String? serviceTypeId;        // サービスタイプID（業種）
  final SubscriptionPlan subscriptionPlan;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final int activeUserCount;
  final int? maxUsers;                // ユーザー数上限（null=無制限）
  final String ownerId;
  final String? phone;
  final String? email;
  final String? address;
  final GeoPoint? mapCenterLocation;  // 地図の初期表示位置
  final double? mapDefaultZoom;       // 地図の初期ズームレベル
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Organization({
    required this.id,
    required this.name,
    this.companyName,
    required this.businessType,
    this.serviceTypeId,
    required this.subscriptionPlan,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    required this.activeUserCount,
    this.maxUsers,
    required this.ownerId,
    this.phone,
    this.email,
    this.address,
    this.mapCenterLocation,
    this.mapDefaultZoom,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Organization.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] ?? '',
      companyName: data['companyName'] as String?,
      businessType: BusinessType.fromJson(data['businessType'] ?? 'other'),
      serviceTypeId: data['serviceTypeId'] as String?,
      subscriptionPlan: SubscriptionPlan.fromJson(
        data['subscriptionPlan'] ?? 'free',
      ),
      subscriptionStartDate: data['subscriptionStartDate'] != null
          ? (data['subscriptionStartDate'] as Timestamp).toDate()
          : null,
      subscriptionEndDate: data['subscriptionEndDate'] != null
          ? (data['subscriptionEndDate'] as Timestamp).toDate()
          : null,
      activeUserCount: data['activeUserCount'] ?? 0,
      maxUsers: data['maxUsers'] as int?,
      ownerId: data['ownerId'] ?? '',
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      address: data['address'] as String?,
      mapCenterLocation: data['mapCenterLocation'] as GeoPoint?,
      mapDefaultZoom: data['mapDefaultZoom'] as double?,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'companyName': companyName,
      'businessType': businessType.toJson(),
      'serviceTypeId': serviceTypeId,
      'subscriptionPlan': subscriptionPlan.toJson(),
      'subscriptionStartDate': subscriptionStartDate != null
          ? Timestamp.fromDate(subscriptionStartDate!)
          : null,
      'subscriptionEndDate': subscriptionEndDate != null
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
      'activeUserCount': activeUserCount,
      'maxUsers': maxUsers,
      'ownerId': ownerId,
      'phone': phone,
      'email': email,
      'address': address,
      'mapCenterLocation': mapCenterLocation,
      'mapDefaultZoom': mapDefaultZoom,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // サブスクリプションが有効かチェック
  bool get isSubscriptionActive {
    if (!isActive) return false;
    if (subscriptionPlan == SubscriptionPlan.free) return true;
    if (subscriptionEndDate == null) return false;
    return subscriptionEndDate!.isAfter(DateTime.now());
  }

  // ユーザー追加可能かチェック
  bool get canAddUser {
    // maxUsersが設定されている場合はそれを使用、なければプランの制限を使用
    final limit = maxUsers ?? subscriptionPlan.maxUsers;
    if (limit == null) return true; // 無制限
    return activeUserCount < limit;
  }

  // 地図の中心位置をLatLngで取得
  LatLng? get mapCenter {
    if (mapCenterLocation == null) return null;
    return LatLng(
      mapCenterLocation!.latitude,
      mapCenterLocation!.longitude,
    );
  }

  // 月額料金計算
  int get monthlyTotal {
    return subscriptionPlan.monthlyPrice * activeUserCount;
  }

  Organization copyWith({
    String? name,
    String? companyName,
    BusinessType? businessType,
    String? serviceTypeId,
    SubscriptionPlan? subscriptionPlan,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    int? activeUserCount,
    int? maxUsers,
    String? ownerId,
    String? phone,
    String? email,
    String? address,
    GeoPoint? mapCenterLocation,
    double? mapDefaultZoom,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      businessType: businessType ?? this.businessType,
      serviceTypeId: serviceTypeId ?? this.serviceTypeId,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStartDate:
          subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      activeUserCount: activeUserCount ?? this.activeUserCount,
      maxUsers: maxUsers ?? this.maxUsers,
      ownerId: ownerId ?? this.ownerId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      mapCenterLocation: mapCenterLocation ?? this.mapCenterLocation,
      mapDefaultZoom: mapDefaultZoom ?? this.mapDefaultZoom,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
