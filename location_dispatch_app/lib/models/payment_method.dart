/// 支払い方法
enum PaymentMethod {
  cash,           // 現金
  bankTransfer,   // 銀行振込
  eMoney,         // 電子マネー
  creditCard,     // クレジットカード
  other;          // その他

  String toJson() => name;

  static PaymentMethod fromJson(String json) {
    return PaymentMethod.values.firstWhere(
      (method) => method.name == json,
      orElse: () => PaymentMethod.cash,
    );
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return '現金';
      case PaymentMethod.bankTransfer:
        return '銀行振込';
      case PaymentMethod.eMoney:
        return '電子マネー';
      case PaymentMethod.creditCard:
        return 'クレジットカード';
      case PaymentMethod.other:
        return 'その他';
    }
  }

  /// アイコンを取得
  String get icon {
    switch (this) {
      case PaymentMethod.cash:
        return '💵';
      case PaymentMethod.bankTransfer:
        return '🏦';
      case PaymentMethod.eMoney:
        return '📱';
      case PaymentMethod.creditCard:
        return '💳';
      case PaymentMethod.other:
        return '📝';
    }
  }
}
