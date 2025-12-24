import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/export_service.dart';

/// 分析・売上レポート画面
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _periodType = 'daily'; // daily, weekly, monthly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('analytics')),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '売上'),
            Tab(text: '商品'),
            Tab(text: '時間帯'),
            Tab(text: 'スタッフ'),
            Tab(text: '言語別'),
          ],
        ),
        actions: [
          // エクスポートボタン
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            tooltip: 'エクスポート',
            onSelected: (value) => _handleExport(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 20),
                    SizedBox(width: 8),
                    Text('CSV出力'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 20),
                    SizedBox(width: 8),
                    Text('PDF出力'),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            initialValue: _periodType,
            onSelected: (value) {
              setState(() {
                _periodType = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'daily', child: Text('日別')),
              const PopupMenuItem(value: 'weekly', child: Text('週別')),
              const PopupMenuItem(value: 'monthly', child: Text('月別')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 日付選択
          _buildDateSelector(),
          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSalesTab(),
                _buildProductsTab(),
                _buildHourlyTab(),
                _buildStaffTab(),
                _buildLanguageTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// エクスポート処理
  Future<void> _handleExport(String type) async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    final (startDate, endDate) = _getDateRange();
    final exportService = ExportService();

    if (type == 'csv') {
      await exportService.exportSalesCSV(
        shopId: staffUser.shopId,
        startDate: startDate,
        endDate: endDate,
        context: context,
      );
    } else if (type == 'pdf') {
      // 店舗名を取得
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(staffUser.shopId)
          .get();
      final shopName = shopDoc.data()?['name'] ?? '店舗';

      await exportService.exportSalesPDF(
        shopId: staffUser.shopId,
        shopName: shopName,
        startDate: startDate,
        endDate: endDate,
        context: context,
      );
    }
  }

  Widget _buildDateSelector() {
    String dateLabel;
    switch (_periodType) {
      case 'daily':
        dateLabel = DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate);
        break;
      case 'weekly':
        final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        dateLabel = '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)}';
        break;
      case 'monthly':
        dateLabel = DateFormat('yyyy年MM月', 'ja').format(_selectedDate);
        break;
      default:
        dateLabel = DateFormat('yyyy年MM月dd日', 'ja').format(_selectedDate);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                switch (_periodType) {
                  case 'daily':
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    break;
                  case 'weekly':
                    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                    break;
                  case 'monthly':
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                    break;
                }
              });
            },
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                switch (_periodType) {
                  case 'daily':
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                    break;
                  case 'weekly':
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                    break;
                  case 'monthly':
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                    break;
                }
              });
            },
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

  (DateTime, DateTime) _getDateRange() {
    switch (_periodType) {
      case 'daily':
        final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
      case 'weekly':
        final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(const Duration(days: 7));
        return (start, end);
      case 'monthly':
        final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
        return (start, end);
      default:
        final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        final end = start.add(const Duration(days: 1));
        return (start, end);
    }
  }

  /// 売上タブ
  Widget _buildSalesTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (startDate, endDate) = _getDateRange();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('status', whereIn: ['served', 'completed'])
          .where('orderedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderedAt', isLessThan: Timestamp.fromDate(endDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        // 売上計算
        double totalSales = 0;
        double totalTax = 0;
        int orderCount = 0;
        int itemCount = 0;
        double cashSales = 0;
        double cardSales = 0;
        double otherSales = 0;

        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final total = (data['total'] as num?)?.toDouble() ?? 0;
          final tax = (data['tax'] as num?)?.toDouble() ?? 0;
          final paymentMethod = data['paymentMethod'] as String? ?? 'cash';
          final items = data['items'] as List? ?? [];

          totalSales += total;
          totalTax += tax;
          orderCount++;
          itemCount += items.length;

          switch (paymentMethod) {
            case 'cash':
              cashSales += total;
              break;
            case 'card':
            case 'credit':
              cardSales += total;
              break;
            default:
              otherSales += total;
          }
        }

        final avgOrderValue = orderCount > 0 ? totalSales / orderCount : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // メイン売上カード
              Card(
                elevation: 3,
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        '総売上',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¥${NumberFormat('#,###').format(totalSales.toInt())}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '(税込)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 統計グリッド
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '注文数',
                      '$orderCount 件',
                      Icons.receipt_long,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '商品数',
                      '$itemCount 点',
                      Icons.shopping_bag,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '客単価',
                      '¥${NumberFormat('#,###').format(avgOrderValue.toInt())}',
                      Icons.person,
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      '消費税',
                      '¥${NumberFormat('#,###').format(totalTax.toInt())}',
                      Icons.account_balance,
                      Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 支払方法別売上
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '支払方法別売上',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentRow('現金', cashSales, totalSales, Colors.green),
                      const SizedBox(height: 8),
                      _buildPaymentRow('カード', cardSales, totalSales, Colors.blue),
                      const SizedBox(height: 8),
                      _buildPaymentRow('その他', otherSales, totalSales, Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(String label, double amount, double total, Color color) {
    final percentage = total > 0 ? (amount / total * 100) : 0.0;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label),
        ),
        Text(
          '¥${NumberFormat('#,###').format(amount.toInt())}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${percentage.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// 商品別売上タブ
  Widget _buildProductsTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (startDate, endDate) = _getDateRange();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('status', whereIn: ['served', 'completed'])
          .where('orderedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderedAt', isLessThan: Timestamp.fromDate(endDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        // 商品別集計
        final Map<String, Map<String, dynamic>> productStats = {};

        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final items = data['items'] as List? ?? [];

          for (var item in items) {
            final productName = item['productName'] as String? ?? '不明';
            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            final subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0;

            if (productStats.containsKey(productName)) {
              productStats[productName]!['quantity'] += quantity;
              productStats[productName]!['sales'] += subtotal;
            } else {
              productStats[productName] = {
                'quantity': quantity,
                'sales': subtotal,
              };
            }
          }
        }

        // ソート（売上順）
        final sortedProducts = productStats.entries.toList()
          ..sort((a, b) => (b.value['sales'] as double).compareTo(a.value['sales'] as double));

        if (sortedProducts.isEmpty) {
          return const Center(
            child: Text('データがありません'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: sortedProducts.length,
          itemBuilder: (context, index) {
            final product = sortedProducts[index];
            final name = product.key;
            final quantity = product.value['quantity'] as int;
            final sales = product.value['sales'] as double;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: Text('$quantity 点'),
                trailing: Text(
                  '¥${NumberFormat('#,###').format(sales.toInt())}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 時間帯別売上タブ
  Widget _buildHourlyTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (startDate, endDate) = _getDateRange();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('status', whereIn: ['served', 'completed'])
          .where('orderedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderedAt', isLessThan: Timestamp.fromDate(endDate))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        // 時間帯別集計（0-23時）
        final Map<int, Map<String, dynamic>> hourlyStats = {};
        for (int i = 0; i < 24; i++) {
          hourlyStats[i] = {'count': 0, 'sales': 0.0};
        }

        double maxSales = 0;

        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final orderedAt = (data['orderedAt'] as Timestamp?)?.toDate();
          final total = (data['total'] as num?)?.toDouble() ?? 0;

          if (orderedAt != null) {
            final hour = orderedAt.hour;
            hourlyStats[hour]!['count'] = (hourlyStats[hour]!['count'] as int) + 1;
            hourlyStats[hour]!['sales'] = (hourlyStats[hour]!['sales'] as double) + total;
            if ((hourlyStats[hour]!['sales'] as double) > maxSales) {
              maxSales = hourlyStats[hour]!['sales'] as double;
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '時間帯別売上',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // 時間帯バーチャート
              ...List.generate(24, (hour) {
                final stats = hourlyStats[hour]!;
                final sales = stats['sales'] as double;
                final count = stats['count'] as int;
                final barWidth = maxSales > 0 ? (sales / maxSales) : 0.0;

                if (count == 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$hour:00',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: barWidth,
                              child: Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade400,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '¥${NumberFormat('#,###').format(sales.toInt())}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '(${count}件)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// スタッフ別売上タブ
  Widget _buildStaffTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (startDate, endDate) = _getDateRange();

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThan: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['completed', 'delivered', 'paid'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'この期間のデータはありません',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // スタッフ別に集計
        final Map<String, StaffSalesData> staffSales = {};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final staffId = data['staffId'] ?? 'unknown';
          final staffName = data['staffName'] ?? '不明';
          final total = (data['totalPrice'] as num?)?.toInt() ?? 0;

          if (!staffSales.containsKey(staffId)) {
            staffSales[staffId] = StaffSalesData(
              staffId: staffId,
              staffName: staffName,
              totalSales: 0,
              orderCount: 0,
            );
          }

          staffSales[staffId]!.totalSales += total;
          staffSales[staffId]!.orderCount++;
        }

        // 売上順にソート
        final sortedStaff = staffSales.values.toList()
          ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

        // 合計
        final grandTotal = sortedStaff.fold<int>(0, (sum, s) => sum + s.totalSales);
        final totalOrders = sortedStaff.fold<int>(0, (sum, s) => sum + s.orderCount);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // サマリーカード
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '総売上',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '¥${NumberFormat('#,###').format(grandTotal)}',
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${sortedStaff.length}',
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'スタッフ',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$totalOrders',
                            style: TextStyle(
                              color: Colors.purple.shade900,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '注文',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // スタッフランキング
            Text(
              'スタッフ別売上',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),

            ...sortedStaff.asMap().entries.map((entry) {
              final index = entry.key;
              final staff = entry.value;
              final percentage = grandTotal > 0
                  ? (staff.totalSales / grandTotal * 100).toStringAsFixed(1)
                  : '0.0';

              Color rankColor;
              IconData rankIcon;
              switch (index) {
                case 0:
                  rankColor = Colors.amber;
                  rankIcon = Icons.emoji_events;
                  break;
                case 1:
                  rankColor = Colors.grey.shade400;
                  rankIcon = Icons.emoji_events;
                  break;
                case 2:
                  rankColor = Colors.brown.shade300;
                  rankIcon = Icons.emoji_events;
                  break;
                default:
                  rankColor = Colors.grey.shade300;
                  rankIcon = Icons.person;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rankColor,
                    child: index < 3
                        ? Icon(rankIcon, color: Colors.white, size: 20)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  title: Text(
                    staff.staffName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${staff.orderCount}件の注文'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${NumberFormat('#,###').format(staff.totalSales)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 言語別売上タブ
  Widget _buildLanguageTab() {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final (startDate, endDate) = _getDateRange();

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: staffUser.shopId)
          .where('orderedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('orderedAt', isLessThan: Timestamp.fromDate(endDate))
          .where('status', whereIn: ['served', 'completed'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.language, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'この期間のデータはありません',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // 言語別に集計
        final Map<String, LanguageSalesData> languageStats = {};
        int totalOrders = 0;
        double totalSales = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final locale = data['locale'] as String? ?? data['customerLocale'] as String? ?? 'ja';
          final total = (data['total'] as num?)?.toDouble() ?? 0;

          // 言語コードを標準化
          final langCode = _normalizeLanguageCode(locale);

          if (!languageStats.containsKey(langCode)) {
            languageStats[langCode] = LanguageSalesData(
              languageCode: langCode,
              languageName: _getLanguageName(langCode),
              totalSales: 0,
              orderCount: 0,
            );
          }

          languageStats[langCode]!.totalSales += total;
          languageStats[langCode]!.orderCount++;
          totalOrders++;
          totalSales += total;
        }

        // 売上順にソート
        final sortedLanguages = languageStats.values.toList()
          ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サマリーカード
              Card(
                color: Colors.indigo.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${sortedLanguages.length}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              Text(
                                '言語',
                                style: TextStyle(color: Colors.indigo.shade600),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '$totalOrders',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              Text(
                                '注文',
                                style: TextStyle(color: Colors.indigo.shade600),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '¥${NumberFormat('#,###').format(totalSales.toInt())}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                              Text(
                                '総売上',
                                style: TextStyle(color: Colors.indigo.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 円グラフ的なバー表示
              const Text(
                '言語別売上構成',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              ...sortedLanguages.map((lang) {
                final percentage = totalSales > 0
                    ? (lang.totalSales / totalSales * 100)
                    : 0.0;
                final barWidth = percentage / 100;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _getLanguageFlag(lang.languageCode),
                          const SizedBox(width: 8),
                          Text(
                            lang.languageName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${lang.orderCount}件',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '¥${NumberFormat('#,###').format(lang.totalSales.toInt())}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getLanguageColor(lang.languageCode),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 8),
                              child: percentage >= 10
                                  ? Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // インサイト
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'インサイト',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInsight(sortedLanguages, totalOrders, totalSales),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _normalizeLanguageCode(String locale) {
    final code = locale.split('_').first.split('-').first.toLowerCase();
    return code;
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'ja':
        return '日本語';
      case 'en':
        return 'English';
      case 'th':
        return 'ภาษาไทย';
      case 'zh':
        return '中文';
      case 'ko':
        return '한국어';
      case 'vi':
        return 'Tiếng Việt';
      default:
        return code.toUpperCase();
    }
  }

  Widget _getLanguageFlag(String code) {
    String flag;
    switch (code) {
      case 'ja':
        flag = '🇯🇵';
        break;
      case 'en':
        flag = '🇺🇸';
        break;
      case 'th':
        flag = '🇹🇭';
        break;
      case 'zh':
        flag = '🇨🇳';
        break;
      case 'ko':
        flag = '🇰🇷';
        break;
      case 'vi':
        flag = '🇻🇳';
        break;
      default:
        flag = '🌐';
    }
    return Text(flag, style: const TextStyle(fontSize: 20));
  }

  Color _getLanguageColor(String code) {
    switch (code) {
      case 'ja':
        return Colors.red.shade400;
      case 'en':
        return Colors.blue.shade400;
      case 'th':
        return Colors.purple.shade400;
      case 'zh':
        return Colors.orange.shade400;
      case 'ko':
        return Colors.teal.shade400;
      case 'vi':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  Widget _buildInsight(List<LanguageSalesData> languages, int totalOrders, double totalSales) {
    if (languages.isEmpty) {
      return const Text('データがありません');
    }

    final topLanguage = languages.first;
    final foreignLanguages = languages.where((l) => l.languageCode != 'ja').toList();
    final foreignOrders = foreignLanguages.fold<int>(0, (sum, l) => sum + l.orderCount);
    final foreignSales = foreignLanguages.fold<double>(0, (sum, l) => sum + l.totalSales);
    final foreignPercentage = totalOrders > 0 ? (foreignOrders / totalOrders * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• 最も多い言語: ${topLanguage.languageName} (${topLanguage.orderCount}件)',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        if (foreignOrders > 0) ...[
          Text(
            '• 外国語での注文: ${foreignPercentage.toStringAsFixed(1)}% (¥${NumberFormat('#,###').format(foreignSales.toInt())})',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          if (foreignPercentage > 20)
            Text(
              '• インバウンド需要が高いです。多言語メニューの充実を検討してください。',
              style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.w500),
            ),
        ] else
          Text(
            '• 外国語での注文はありません',
            style: TextStyle(color: Colors.grey.shade600),
          ),
      ],
    );
  }
}

/// スタッフ売上データクラス
class StaffSalesData {
  final String staffId;
  final String staffName;
  int totalSales;
  int orderCount;

  StaffSalesData({
    required this.staffId,
    required this.staffName,
    required this.totalSales,
    required this.orderCount,
  });
}

/// 言語別売上データクラス
class LanguageSalesData {
  final String languageCode;
  final String languageName;
  double totalSales;
  int orderCount;

  LanguageSalesData({
    required this.languageCode,
    required this.languageName,
    required this.totalSales,
    required this.orderCount,
  });
}
