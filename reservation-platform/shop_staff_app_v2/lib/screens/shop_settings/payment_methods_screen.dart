import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

/// 支払方法設定画面
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _isLoading = false;

  // 利用可能な支払方法のマスターリスト
  static const List<PaymentMethodInfo> _availableMethods = [
    PaymentMethodInfo(
      id: 'cash',
      name: '現金',
      icon: Icons.money,
      color: Colors.green,
      category: 'basic',
    ),
    PaymentMethodInfo(
      id: 'credit_card',
      name: 'クレジットカード',
      icon: Icons.credit_card,
      color: Colors.blue,
      category: 'card',
    ),
    PaymentMethodInfo(
      id: 'debit_card',
      name: 'デビットカード',
      icon: Icons.credit_card_outlined,
      color: Colors.indigo,
      category: 'card',
    ),
    PaymentMethodInfo(
      id: 'paypay',
      name: 'PayPay',
      icon: Icons.qr_code,
      color: Colors.red,
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'linepay',
      name: 'LINE Pay',
      icon: Icons.qr_code_2,
      color: Color(0xFF06C755),
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'merpay',
      name: 'メルペイ',
      icon: Icons.qr_code,
      color: Colors.pink,
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'rakutenpay',
      name: '楽天ペイ',
      icon: Icons.qr_code,
      color: Colors.red,
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'aupay',
      name: 'au PAY',
      icon: Icons.qr_code,
      color: Colors.orange,
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'd_payment',
      name: 'd払い',
      icon: Icons.qr_code,
      color: Colors.red,
      category: 'qr',
    ),
    PaymentMethodInfo(
      id: 'suica',
      name: '交通系IC（Suica等）',
      icon: Icons.contactless,
      color: Colors.green,
      category: 'ic',
    ),
    PaymentMethodInfo(
      id: 'id',
      name: 'iD',
      icon: Icons.contactless,
      color: Colors.red,
      category: 'ic',
    ),
    PaymentMethodInfo(
      id: 'quicpay',
      name: 'QUICPay',
      icon: Icons.contactless,
      color: Colors.purple,
      category: 'ic',
    ),
    PaymentMethodInfo(
      id: 'promptpay',
      name: 'PromptPay（タイ）',
      icon: Icons.qr_code,
      color: Colors.blue,
      category: 'international',
    ),
    PaymentMethodInfo(
      id: 'alipay',
      name: 'Alipay',
      icon: Icons.qr_code,
      color: Colors.blue,
      category: 'international',
    ),
    PaymentMethodInfo(
      id: 'wechatpay',
      name: 'WeChat Pay',
      icon: Icons.qr_code,
      color: Colors.green,
      category: 'international',
    ),
    PaymentMethodInfo(
      id: 'coupon',
      name: 'クーポン',
      icon: Icons.discount,
      color: Colors.amber,
      category: 'other',
    ),
    PaymentMethodInfo(
      id: 'gift_card',
      name: 'ギフトカード',
      icon: Icons.card_giftcard,
      color: Colors.purple,
      category: 'other',
    ),
    PaymentMethodInfo(
      id: 'invoice',
      name: '請求書払い',
      icon: Icons.receipt_long,
      color: Colors.brown,
      category: 'other',
    ),
  ];

  static const Map<String, String> _categoryNames = {
    'basic': '基本',
    'card': 'カード決済',
    'qr': 'QRコード決済',
    'ic': '電子マネー',
    'international': '海外決済',
    'other': 'その他',
  };

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('支払方法設定'),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(staffUser.shopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('店舗情報が見つかりません'));
          }

          final shop = snapshot.data!.data() as Map<String, dynamic>;
          final enabledMethods = List<String>.from(shop['enabledPaymentMethods'] ?? ['cash']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 説明カード
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '有効にした支払方法がレジ画面で選択可能になります',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // カテゴリ別に表示
              ..._categoryNames.entries.map((category) {
                final methodsInCategory = _availableMethods
                    .where((m) => m.category == category.key)
                    .toList();

                return _buildCategorySection(
                  title: category.value,
                  methods: methodsInCategory,
                  enabledMethods: enabledMethods,
                  shopId: staffUser.shopId,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required List<PaymentMethodInfo> methods,
    required List<String> enabledMethods,
    required String shopId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Card(
          child: Column(
            children: methods.map((method) {
              final isEnabled = enabledMethods.contains(method.id);
              return SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: method.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(method.icon, color: method.color),
                ),
                title: Text(method.name),
                value: isEnabled,
                onChanged: _isLoading
                    ? null
                    : (value) => _togglePaymentMethod(
                          shopId,
                          method.id,
                          value,
                          enabledMethods,
                        ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _togglePaymentMethod(
    String shopId,
    String methodId,
    bool enable,
    List<String> currentMethods,
  ) async {
    // 現金は無効化できない
    if (methodId == 'cash' && !enable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('現金は無効化できません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> updatedMethods;
      if (enable) {
        updatedMethods = [...currentMethods, methodId];
      } else {
        updatedMethods = currentMethods.where((m) => m != methodId).toList();
      }

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({
        'enabledPaymentMethods': updatedMethods,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable ? '支払方法を有効化しました' : '支払方法を無効化しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class PaymentMethodInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String category;

  const PaymentMethodInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
  });
}
