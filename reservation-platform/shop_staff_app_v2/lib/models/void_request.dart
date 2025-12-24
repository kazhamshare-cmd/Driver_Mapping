import 'package:cloud_firestore/cloud_firestore.dart';

/// バック（取消）申請のステータス
enum VoidRequestStatus {
  pending,
  approved,
  rejected,
}

extension VoidRequestStatusExtension on VoidRequestStatus {
  String get label {
    switch (this) {
      case VoidRequestStatus.pending:
        return '承認待ち';
      case VoidRequestStatus.approved:
        return '承認済み';
      case VoidRequestStatus.rejected:
        return '却下';
    }
  }
}

/// バック（取消）申請モデル
class VoidRequest {
  final String id;
  final String shopId;
  final String orderId;
  final String? itemId;
  final String itemName;
  final int quantity;
  final int price;
  final String reason;
  final String requestedBy;
  final String requestedByName;
  final DateTime requestedAt;
  final VoidRequestStatus status;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewComment;

  VoidRequest({
    required this.id,
    required this.shopId,
    required this.orderId,
    this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewComment,
  });

  factory VoidRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VoidRequest(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      orderId: data['orderId'] ?? '',
      itemId: data['itemId'],
      itemName: data['itemName'] ?? '',
      quantity: data['quantity'] ?? 1,
      price: data['price'] ?? 0,
      reason: data['reason'] ?? '',
      requestedBy: data['requestedBy'] ?? '',
      requestedByName: data['requestedByName'] ?? '',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: VoidRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => VoidRequestStatus.pending,
      ),
      reviewedBy: data['reviewedBy'],
      reviewedByName: data['reviewedByName'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewComment: data['reviewComment'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'orderId': orderId,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'price': price,
      'reason': reason,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedByName': reviewedByName,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewComment': reviewComment,
    };
  }
}
