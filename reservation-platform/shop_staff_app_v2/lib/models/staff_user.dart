import 'package:cloud_firestore/cloud_firestore.dart';

class StaffUser {
  final String id;
  final String email;
  final String name; // firstName + lastName の組み合わせ
  final String firstName;
  final String lastName;
  final String role; // 'owner', 'manager', 'staff'
  final String shopId;
  final bool isWorking; // 現在出勤中かどうか
  final double hourlyWage; // 時給
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StaffUser({
    required this.id,
    required this.email,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.shopId,
    this.isWorking = false,
    this.hourlyWage = 1000.0, // デフォルト時給
    this.createdAt,
    this.updatedAt,
  });

  factory StaffUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // personalInfoから名前を取得
    final personalInfo = data['personalInfo'] as Map<String, dynamic>?;
    final firstName = personalInfo?['firstName'] as String? ?? '';
    final lastName = personalInfo?['lastName'] as String? ?? '';
    final fullName = '$lastName $firstName'.trim();

    // currentWorkStatusから出勤状態を取得
    final currentWorkStatus = data['currentWorkStatus'] as Map<String, dynamic>?;
    final isWorking = currentWorkStatus?['isWorking'] as bool? ?? false;

    // 時給を取得（employmentInfoまたはルートから）
    final employmentInfo = data['employmentInfo'] as Map<String, dynamic>?;
    final hourlyWage = (employmentInfo?['hourlyWage'] ?? data['hourlyWage'] ?? 1000).toDouble();

    return StaffUser(
      id: doc.id,
      email: data['email'] ?? '',
      name: fullName.isNotEmpty ? fullName : (data['name'] ?? ''),
      firstName: firstName,
      lastName: lastName,
      role: data['role'] ?? 'staff',
      shopId: data['shopId'] ?? '',
      isWorking: isWorking,
      hourlyWage: hourlyWage,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'shopId': shopId,
      'hourlyWage': hourlyWage,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
