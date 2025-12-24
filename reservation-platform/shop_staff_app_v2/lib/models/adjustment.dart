import 'package:cloud_firestore/cloud_firestore.dart';

enum AdjustmentType {
  discountAmount,      // 金額値引き (税前)
  discountPercent,     // %割引 (税前)
  surchargeTaxExcluded,// 加算 (税別) - 特別メニューなど
  surchargeTaxIncluded,// 加算 (税込) - タバコなど
  paymentVoucher,      // 金券・予約金 (支払い充当)
}

class AdjustmentModel {
  final String name;
  final AdjustmentType type;
  final double value;

  AdjustmentModel({
    required this.name,
    required this.type,
    required this.value,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'value': value,
    };
  }

  factory AdjustmentModel.fromFirestore(Map<String, dynamic> data) {
    return AdjustmentModel(
      name: data['name'] ?? '',
      type: AdjustmentType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AdjustmentType.discountAmount,
      ),
      value: (data['value'] ?? 0).toDouble(),
    );
  }
  
  String get label {
    switch (type) {
      case AdjustmentType.discountAmount: return '値引き(円)';
      case AdjustmentType.discountPercent: return '割引(%)';
      case AdjustmentType.surchargeTaxExcluded: return '加算(税別)';
      case AdjustmentType.surchargeTaxIncluded: return '加算(税込)';
      case AdjustmentType.paymentVoucher: return '金券・内金';
    }
  }
}