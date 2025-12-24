import 'package:cloud_firestore/cloud_firestore.dart';

class Menu {
  final String id;
  final String shopId;
  final String name;
  final String? description;
  final double price;
  final int? duration; // 所要時間（分）
  final bool isActive;
  final bool isReservationMenu;
  final DateTime createdAt;
  final DateTime updatedAt;

  Menu({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    required this.price,
    this.duration,
    this.isActive = true,
    this.isReservationMenu = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Menu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Menu(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] ?? 0).toDouble(),
      duration: data['duration'],
      isActive: data['isActive'] ?? true,
      isReservationMenu: data['isReservationMenu'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'name': name,
      if (description != null) 'description': description,
      'price': price,
      if (duration != null) 'duration': duration,
      'isActive': isActive,
      'isReservationMenu': isReservationMenu,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
