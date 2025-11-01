import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';
import 'user_status.dart';
import 'notification_setting.dart';
import 'payment_method.dart';

class AppUser {
  final String id;
  final String organizationId;
  final String name;
  final String phone;
  final UserRole role;                    // メインロール（後方互換性のため保持）
  final List<UserRole> roles;             // 複数ロール対応
  final UserRole activeRole;              // 現在アクティブなロール
  final UserStatus status;
  final GeoPoint? location;
  final String? geohash;
  final String? fcmToken;
  final NotificationSetting notificationSetting;

  // 支払い関連情報
  final PaymentMethod? preferredPaymentMethod; // 希望支払い方法
  final String? address;                       // 住所
  final String? invoiceNumber;                 // インボイス番号（適格請求書発行事業者登録番号）
  final String? bankName;                      // 銀行名
  final String? bankBranch;                    // 支店名
  final String? bankAccountType;               // 口座種別（普通/当座）
  final String? bankAccountNumber;             // 口座番号
  final String? bankAccountHolder;             // 口座名義

  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.phone,
    required this.role,
    List<UserRole>? roles,
    UserRole? activeRole,
    required this.status,
    this.location,
    this.geohash,
    this.fcmToken,
    this.notificationSetting = NotificationSetting.nominatedEvenWhenOff,
    this.preferredPaymentMethod,
    this.address,
    this.invoiceNumber,
    this.bankName,
    this.bankBranch,
    this.bankAccountType,
    this.bankAccountNumber,
    this.bankAccountHolder,
    required this.createdAt,
    required this.updatedAt,
  })  : roles = roles ?? [role],
        activeRole = activeRole ?? role;

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mainRole = UserRole.fromJson(data['role'] ?? 'worker');

    // rolesがFirestoreに保存されていない場合はmainRoleを使用
    final List<UserRole> rolesList;
    if (data['roles'] != null && data['roles'] is List) {
      rolesList = (data['roles'] as List)
          .map((r) => UserRole.fromJson(r as String))
          .toList();
    } else {
      rolesList = [mainRole];
    }

    // activeRoleがFirestoreに保存されていない場合はmainRoleを使用
    final activeRoleValue = data['activeRole'] != null
        ? UserRole.fromJson(data['activeRole'] as String)
        : mainRole;

    return AppUser(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: mainRole,
      roles: rolesList,
      activeRole: activeRoleValue,
      status: UserStatus.fromJson(data['status'] ?? 'offline'),
      location: data['location'] as GeoPoint?,
      geohash: data['geohash'] as String?,
      fcmToken: data['fcmToken'] as String?,
      notificationSetting: NotificationSetting.fromJson(
        data['notificationSetting'] ?? 'nominatedEvenWhenOff',
      ),
      preferredPaymentMethod: data['preferredPaymentMethod'] != null
          ? PaymentMethod.fromJson(data['preferredPaymentMethod'] as String)
          : null,
      address: data['address'] as String?,
      invoiceNumber: data['invoiceNumber'] as String?,
      bankName: data['bankName'] as String?,
      bankBranch: data['bankBranch'] as String?,
      bankAccountType: data['bankAccountType'] as String?,
      bankAccountNumber: data['bankAccountNumber'] as String?,
      bankAccountHolder: data['bankAccountHolder'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organizationId,
      'name': name,
      'phone': phone,
      'role': role.toJson(),
      'roles': roles.map((r) => r.toJson()).toList(),
      'activeRole': activeRole.toJson(),
      'status': status.toJson(),
      'location': location,
      'geohash': geohash,
      'fcmToken': fcmToken,
      'notificationSetting': notificationSetting.toJson(),
      'preferredPaymentMethod': preferredPaymentMethod?.toJson(),
      'address': address,
      'invoiceNumber': invoiceNumber,
      'bankName': bankName,
      'bankBranch': bankBranch,
      'bankAccountType': bankAccountType,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountHolder': bankAccountHolder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUser copyWith({
    String? organizationId,
    String? name,
    String? phone,
    UserRole? role,
    List<UserRole>? roles,
    UserRole? activeRole,
    UserStatus? status,
    GeoPoint? location,
    String? geohash,
    String? fcmToken,
    NotificationSetting? notificationSetting,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      activeRole: activeRole ?? this.activeRole,
      status: status ?? this.status,
      location: location ?? this.location,
      geohash: geohash ?? this.geohash,
      fcmToken: fcmToken ?? this.fcmToken,
      notificationSetting: notificationSetting ?? this.notificationSetting,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 複数ロールを持っているかどうか
  bool get hasMultipleRoles => roles.length > 1;

  // 指定されたロールを持っているかどうか
  bool hasRole(UserRole targetRole) => roles.contains(targetRole);
}

