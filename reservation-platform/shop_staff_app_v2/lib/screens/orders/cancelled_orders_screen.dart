import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

/// キャンセル・削除履歴画面（オーナー専用）
class CancelledOrdersScreen extends ConsumerStatefulWidget {
  const CancelledOrdersScreen({super.key});

  @override
  ConsumerState<CancelledOrdersScreen> createState() => _CancelledOrdersScreenState();
}

class _CancelledOrdersScreenState extends ConsumerState<CancelledOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('アクセス拒否'),
        ),
        body: const Center(
          child: Text('この画面はオーナーのみアクセスできます'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('キャンセル・削除履歴'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'キャンセル注文'),
            Tab(text: '削除済み注文'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // 日付フィルター
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                Text(
                  DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCancelledOrdersTab(),
                _buildDeletedOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ja'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// キャンセル注文タブ
  Widget _buildCancelledOrdersTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('status', isEqualTo: 'cancelled')
          .where('orderedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('orderedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('orderedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('この日のキャンセル注文はありません');
        }

        final orders = snapshot.data!.docs;
        double totalCancelledAmount = 0;
        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          totalCancelledAmount += (data['total'] as num?)?.toDouble() ?? 0;
        }

        return Column(
          children: [
            // サマリー
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('キャンセル件数', '${orders.length}件'),
                  _buildSummaryItem('キャンセル合計', '¥${totalCancelledAmount.toInt()}'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final data = orders[index].data() as Map<String, dynamic>;
                  return _buildCancelledOrderCard(data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 削除済み注文タブ
  Widget _buildDeletedOrdersTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .collection('deletedOrders')
          .where('deletedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('deletedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('deletedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('この日の削除注文はありません');
        }

        final deletedOrders = snapshot.data!.docs;
        double totalDeletedAmount = 0;
        for (var doc in deletedOrders) {
          final data = doc.data() as Map<String, dynamic>;
          totalDeletedAmount += (data['total'] as num?)?.toDouble() ?? 0;
        }

        return Column(
          children: [
            // サマリー
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('削除件数', '${deletedOrders.length}件'),
                  _buildSummaryItem('削除合計', '¥${totalDeletedAmount.toInt()}'),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: deletedOrders.length,
                itemBuilder: (context, index) {
                  final data = deletedOrders[index].data() as Map<String, dynamic>;
                  return _buildDeletedOrderCard(data);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledOrderCard(Map<String, dynamic> data) {
    final orderedAt = (data['orderedAt'] as Timestamp?)?.toDate();
    final cancelledAt = (data['cancelledAt'] as Timestamp?)?.toDate();
    final dateFormatter = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'テーブル ${data['tableNumber'] ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data['orderNumber'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '¥${((data['total'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '注文: ${orderedAt != null ? dateFormatter.format(orderedAt) : '-'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.cancel, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'キャンセル: ${cancelledAt != null ? dateFormatter.format(cancelledAt) : '-'}',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ],
            ),
            if (data['cancelledBy'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '担当: ${data['cancelledByName'] ?? data['cancelledBy']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (data['cancelReason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'キャンセル理由:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      data['cancelReason'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeletedOrderCard(Map<String, dynamic> data) {
    final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();
    final dateFormatter = DateFormat('HH:mm');
    final originalData = data['originalOrderData'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'テーブル ${data['tableNumber'] ?? '-'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data['orderNumber'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '¥${((data['total'] as num?)?.toInt() ?? 0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Row(
              children: [
                Icon(Icons.delete_forever, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  '削除: ${deletedAt != null ? dateFormatter.format(deletedAt) : '-'}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '削除者: ${data['deletedByName'] ?? data['deletedBy'] ?? '-'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (data['deleteReason'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '削除理由:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Text(
                      data['deleteReason'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            // 商品リスト（折りたたみ）
            if (originalData != null && originalData['items'] != null) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                title: Text(
                  '注文内容 (${data['itemCount'] ?? 0}点)',
                  style: const TextStyle(fontSize: 13),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  ...(originalData['items'] as List).map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item['productName']} x${item['quantity']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '¥${item['subtotal']?.toInt() ?? 0}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
