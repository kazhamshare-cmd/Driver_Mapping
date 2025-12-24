import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

/// 顧客管理画面
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'lastVisit'; // lastVisit, totalSpent, visitCount

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final staffUser = ref.watch(staffUserProvider).value;

    if (staffUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('customers')),
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'lastVisit', child: Text('最終来店日順')),
              const PopupMenuItem(value: 'totalSpent', child: Text('累計金額順')),
              const PopupMenuItem(value: 'visitCount', child: Text('来店回数順')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '名前、電話番号、メールで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // 顧客リスト
          Expanded(
            child: _buildCustomerList(staffUser.shopId, isOwner),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(String shopId, bool isOwner) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .orderBy(
            _sortBy == 'lastVisit' ? 'lastVisitAt' :
            _sortBy == 'totalSpent' ? 'totalSpent' : 'visitCount',
            descending: true,
          )
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var customers = snapshot.data!.docs;

        // 検索フィルター
        if (_searchQuery.isNotEmpty) {
          customers = customers.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] as String? ?? '').toLowerCase();
            final phone = (data['phone'] as String? ?? '').toLowerCase();
            final email = (data['email'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                phone.contains(_searchQuery) ||
                email.contains(_searchQuery);
          }).toList();
        }

        if (customers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '検索結果がありません',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final doc = customers[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCustomerCard(doc.id, data, isOwner);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '顧客データがありません',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '注文や予約を通じて顧客が登録されます',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(String customerId, Map<String, dynamic> data, bool isOwner) {
    final name = data['name'] as String? ?? '名前未設定';
    final phone = data['phone'] as String?;
    final email = data['email'] as String?;
    final visitCount = (data['visitCount'] as num?)?.toInt() ?? 0;
    final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0;
    final lastVisitAt = (data['lastVisitAt'] as Timestamp?)?.toDate();
    final notes = data['notes'] as String?;
    final isBlacklisted = data['isBlacklisted'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isBlacklisted ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: () => _showCustomerDetail(customerId, data, isOwner),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // アバター
              CircleAvatar(
                backgroundColor: isBlacklisted
                    ? Colors.red.shade200
                    : Colors.cyan.shade100,
                radius: 28,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isBlacklisted ? Colors.red.shade700 : Colors.cyan.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 顧客情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isBlacklisted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ブラックリスト',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (phone != null)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    if (email != null)
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatBadge(
                          Icons.repeat,
                          '$visitCount回',
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildStatBadge(
                          Icons.attach_money,
                          '¥${NumberFormat('#,###').format(totalSpent.toInt())}',
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 最終来店日
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '最終来店',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  Text(
                    lastVisitAt != null
                        ? DateFormat('MM/dd').format(lastVisitAt)
                        : '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetail(
    String customerId,
    Map<String, dynamic> data,
    bool isOwner,
  ) {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    final name = data['name'] as String? ?? '名前未設定';
    final phone = data['phone'] as String?;
    final email = data['email'] as String?;
    final visitCount = (data['visitCount'] as num?)?.toInt() ?? 0;
    final totalSpent = (data['totalSpent'] as num?)?.toDouble() ?? 0;
    final lastVisitAt = (data['lastVisitAt'] as Timestamp?)?.toDate();
    final notes = data['notes'] as String?;
    final isBlacklisted = data['isBlacklisted'] as bool? ?? false;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 顧客情報
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isBlacklisted
                        ? Colors.red.shade200
                        : Colors.cyan.shade100,
                    radius: 32,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isBlacklisted
                            ? Colors.red.shade700
                            : Colors.cyan.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isBlacklisted)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ブラックリスト登録中',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 連絡先
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '連絡先',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      if (phone != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.phone),
                          title: Text(phone),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (email != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.email),
                          title: Text(email),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (phone == null && email == null)
                        const Text(
                          '連絡先未登録',
                          style: TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 統計
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '利用統計',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailStat(
                              '来店回数',
                              '$visitCount 回',
                              Icons.repeat,
                              Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailStat(
                              '累計金額',
                              '¥${NumberFormat('#,###').format(totalSpent.toInt())}',
                              Icons.attach_money,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailStat(
                              '客単価',
                              visitCount > 0
                                  ? '¥${NumberFormat('#,###').format((totalSpent / visitCount).toInt())}'
                                  : '-',
                              Icons.person,
                              Colors.purple,
                            ),
                          ),
                          Expanded(
                            child: _buildDetailStat(
                              '最終来店',
                              lastVisitAt != null
                                  ? DateFormat('yyyy/MM/dd').format(lastVisitAt)
                                  : '-',
                              Icons.calendar_today,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // メモ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'メモ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isOwner)
                            TextButton.icon(
                              onPressed: () => _editNotes(
                                staffUser.shopId,
                                customerId,
                                notes,
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('編集'),
                            ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        notes ?? 'メモなし',
                        style: TextStyle(
                          color: notes == null ? Colors.grey : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 顧客分析カード
              _buildCustomerAnalysisCard(staffUser.shopId, customerId, visitCount, totalSpent),
              const SizedBox(height: 12),

              // 注文履歴
              _buildOrderHistoryCard(staffUser.shopId, customerId),
              const SizedBox(height: 12),

              // 登録日
              Text(
                '登録日: ${createdAt != null ? DateFormat('yyyy/MM/dd').format(createdAt) : '不明'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),

              // オーナー専用アクション
              if (isOwner) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleBlacklist(
                          staffUser.shopId,
                          customerId,
                          !isBlacklisted,
                        ),
                        icon: Icon(
                          isBlacklisted ? Icons.check_circle : Icons.block,
                        ),
                        label: Text(
                          isBlacklisted ? 'ブラックリスト解除' : 'ブラックリスト登録',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isBlacklisted
                              ? Colors.green
                              : Colors.red,
                          side: BorderSide(
                            color: isBlacklisted ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 顧客分析カード
  Widget _buildCustomerAnalysisCard(String shopId, String customerId, int visitCount, double totalSpent) {
    // VIPランク判定
    String vipRank;
    Color rankColor;
    IconData rankIcon;

    if (totalSpent >= 100000 || visitCount >= 20) {
      vipRank = 'プラチナ';
      rankColor = Colors.purple;
      rankIcon = Icons.diamond;
    } else if (totalSpent >= 50000 || visitCount >= 10) {
      vipRank = 'ゴールド';
      rankColor = Colors.amber;
      rankIcon = Icons.star;
    } else if (totalSpent >= 20000 || visitCount >= 5) {
      vipRank = 'シルバー';
      rankColor = Colors.grey;
      rankIcon = Icons.military_tech;
    } else {
      vipRank = 'レギュラー';
      rankColor = Colors.brown;
      rankIcon = Icons.person;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '顧客分析',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            // VIPランク
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rankColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(rankIcon, color: rankColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        vipRank,
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'リピート率',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      visitCount >= 2 ? '${((visitCount - 1) / visitCount * 100).toInt()}%' : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ランク説明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ランク条件',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  _buildRankRow('プラチナ', '¥100,000以上 または 20回以上', Colors.purple),
                  _buildRankRow('ゴールド', '¥50,000以上 または 10回以上', Colors.amber),
                  _buildRankRow('シルバー', '¥20,000以上 または 5回以上', Colors.grey),
                  _buildRankRow('レギュラー', 'その他', Colors.brown),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankRow(String rank, String condition, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            rank,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            condition,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 注文履歴カード
  Widget _buildOrderHistoryCard(String shopId, String customerId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近の注文',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('orders')
                  .where('shopId', isEqualTo: shopId)
                  .where('customerId', isEqualTo: customerId)
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        '注文履歴がありません',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final total = (data['total'] as num?)?.toDouble() ?? 0;
                    final itemCount = (data['items'] as List?)?.length ?? 0;
                    final status = data['status'] as String? ?? 'unknown';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt,
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '¥${NumberFormat('#,###').format(total.toInt())}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$itemCount点 • ${createdAt != null ? DateFormat('MM/dd HH:mm').format(createdAt) : '-'}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return '完了';
      case 'paid':
        return '会計済';
      case 'pending':
        return '処理中';
      case 'cancelled':
        return 'キャンセル';
      default:
        return status;
    }
  }

  Future<void> _editNotes(
    String shopId,
    String customerId,
    String? currentNotes,
  ) async {
    final controller = TextEditingController(text: currentNotes);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'アレルギー情報、好み、注意事項など',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .doc(customerId)
          .update({'notes': result.trim().isEmpty ? null : result.trim()});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メモを更新しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _toggleBlacklist(
    String shopId,
    String customerId,
    bool blacklist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blacklist ? 'ブラックリスト登録' : 'ブラックリスト解除'),
        content: Text(
          blacklist
              ? 'この顧客をブラックリストに登録しますか？\n予約時に警告が表示されます。'
              : 'ブラックリストから解除しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: blacklist ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(blacklist ? '登録' : '解除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .doc(customerId)
          .update({'isBlacklisted': blacklist});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              blacklist
                  ? 'ブラックリストに登録しました'
                  : 'ブラックリストから解除しました',
            ),
            backgroundColor: blacklist ? Colors.red : Colors.green,
          ),
        );
      }
    }
  }
}
