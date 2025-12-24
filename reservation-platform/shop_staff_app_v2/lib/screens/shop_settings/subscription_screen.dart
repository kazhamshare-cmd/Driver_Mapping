import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

/// サブスクリプション・プラン確認画面
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUser = ref.watch(staffUserProvider).value;

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ご利用プラン'),
        backgroundColor: Colors.purple.shade700,
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

          final shop = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final plan = shop['plan'] as String? ?? 'free';
          final planExpiry = (shop['planExpiry'] as Timestamp?)?.toDate();
          final createdAt = (shop['createdAt'] as Timestamp?)?.toDate();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 現在のプラン
                _buildCurrentPlanCard(context, plan, planExpiry),
                const SizedBox(height: 24),

                // 利用状況
                _buildUsageCard(staffUser.shopId),
                const SizedBox(height: 24),

                // プラン一覧
                _buildPlanComparisonCard(plan),
                const SizedBox(height: 24),

                // 契約情報
                _buildContractInfoCard(createdAt, planExpiry),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(BuildContext context, String plan, DateTime? expiry) {
    final planInfo = _getPlanInfo(plan);

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [planInfo['color'] as Color, (planInfo['color'] as Color).withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(planInfo['icon'] as IconData, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    planInfo['name'] as String,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                planInfo['description'] as String,
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    planInfo['price'] as String,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ' / 月',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
              if (expiry != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '有効期限: ${DateFormat('yyyy/MM/dd').format(expiry)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageCard(String shopId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今月の利用状況',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            FutureBuilder<Map<String, int>>(
              future: _getUsageStats(shopId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data!;
                return Column(
                  children: [
                    _buildUsageRow('注文件数', '${stats['orders']}件', Icons.receipt),
                    _buildUsageRow('予約件数', '${stats['reservations']}件', Icons.calendar_today),
                    _buildUsageRow('登録スタッフ', '${stats['staff']}名', Icons.people),
                    _buildUsageRow('登録商品', '${stats['products']}点', Icons.inventory),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanComparisonCard(String currentPlan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プラン比較',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildPlanRow('Free', '無料', ['基本機能', '3スタッフまで'], currentPlan == 'free'),
            const Divider(),
            _buildPlanRow('Basic', '¥5,000/月', ['全機能', '10スタッフまで', 'メールサポート'], currentPlan == 'basic'),
            const Divider(),
            _buildPlanRow('Pro', '¥15,000/月', ['全機能', '無制限スタッフ', '優先サポート', 'API連携'], currentPlan == 'pro'),
            const Divider(),
            _buildPlanRow('Enterprise', '要相談', ['カスタマイズ', '専任サポート', 'SLA保証'], currentPlan == 'enterprise'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanRow(String name, String price, List<String> features, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.purple : null,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '現在',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  price,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text(f, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractInfoCard(DateTime? createdAt, DateTime? expiry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '契約情報',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: const Text('契約開始日'),
              trailing: Text(
                createdAt != null ? DateFormat('yyyy/MM/dd').format(createdAt) : '-',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('次回更新日'),
              trailing: Text(
                expiry != null ? DateFormat('yyyy/MM/dd').format(expiry) : '-',
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // お問い合わせフォームへ
                },
                icon: const Icon(Icons.mail),
                label: const Text('プラン変更のお問い合わせ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getPlanInfo(String plan) {
    switch (plan) {
      case 'basic':
        return {
          'name': 'Basic',
          'description': 'スモールビジネス向けの基本プラン',
          'price': '¥5,000',
          'color': Colors.blue,
          'icon': Icons.star,
        };
      case 'pro':
        return {
          'name': 'Pro',
          'description': '成長企業向けのプロフェッショナルプラン',
          'price': '¥15,000',
          'color': Colors.purple,
          'icon': Icons.diamond,
        };
      case 'enterprise':
        return {
          'name': 'Enterprise',
          'description': '大規模企業向けのエンタープライズプラン',
          'price': '要相談',
          'color': Colors.indigo,
          'icon': Icons.business,
        };
      default:
        return {
          'name': 'Free',
          'description': '無料でお試しいただけるプラン',
          'price': '無料',
          'color': Colors.grey,
          'icon': Icons.star_border,
        };
    }
  }

  Future<Map<String, int>> _getUsageStats(String shopId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // 注文数
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();

    // 予約数
    final reservationsSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('reservations')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();

    // スタッフ数
    final staffSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('employees')
        .count()
        .get();

    // 商品数
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .count()
        .get();

    return {
      'orders': ordersSnapshot.count ?? 0,
      'reservations': reservationsSnapshot.count ?? 0,
      'staff': staffSnapshot.count ?? 0,
      'products': productsSnapshot.count ?? 0,
    };
  }
}
