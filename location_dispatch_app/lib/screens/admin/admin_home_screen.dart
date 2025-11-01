import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/organization_service.dart';
import '../../models/app_user.dart';
import '../../models/organization.dart';
import '../../models/service_request.dart';
import '../../models/request_status.dart';
import '../../models/invoice.dart';
import '../../models/subscription_plan.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'organization_settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _organizationService = OrganizationService();

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('管理者ダッシュボード'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboardTab(),
          _buildSimpleTab('スタッフ管理', Icons.people),
          _buildSimpleTab('財務管理', Icons.attach_money),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'ダッシュボード',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'スタッフ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: '財務',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
      // 一時的にBottomNavigationBarをコメントアウト
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   currentIndex: _selectedIndex,
      //   onTap: (index) => setState(() => _selectedIndex = index),
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.dashboard),
      //       label: 'ダッシュボード',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.people),
      //       label: 'スタッフ',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.attach_money),
      //       label: '財務',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.settings),
      //       label: '設定',
      //     ),
      //   ],
      // ),
    );
  }

  /// シンプルなプレースホルダータブ
  Widget _buildSimpleTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '開発中...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// 設定タブ
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 組織設定
        Card(
          child: ListTile(
            leading: const Icon(Icons.business, color: Colors.blue),
            title: const Text('組織設定'),
            subtitle: const Text('組織名・連絡先・地図の初期表示位置などを設定'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrganizationSettingsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // サービスタイプ管理
        Card(
          child: ListTile(
            leading: const Icon(Icons.category, color: Colors.orange),
            title: const Text('サービスタイプ管理'),
            subtitle: const Text('業種マスタの管理（鍵・水道・電気など）'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.serviceTypeManagement);
            },
          ),
        ),
        const SizedBox(height: 8),

        // アプリ情報
        const Card(
          child: ListTile(
            leading: Icon(Icons.info, color: Colors.grey),
            title: Text('アプリ情報'),
            subtitle: Text('バージョン: 1.0.0'),
          ),
        ),
      ],
    );
  }

  /// ダッシュボードタブ
  Widget _buildDashboardTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Center(child: Text('ログインしてください'));

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError) {
          print('管理者ダッシュボード - ユーザーデータ取得エラー: ${userSnapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('データの取得に失敗しました\n${userSnapshot.error}'),
              ],
            ),
          );
        }

        if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
          print('管理者ダッシュボード - ユーザーデータが見つかりません');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_outlined, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text('ユーザーデータが見つかりません'),
              ],
            ),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final organizationId = userData['organizationId'] as String;
        print('管理者ダッシュボード - 組織ID: $organizationId');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrganizationInfo(organizationId),
              const SizedBox(height: 16),
              _buildTodayStats(organizationId),
              const SizedBox(height: 16),
              _buildRecentRequests(organizationId),
            ],
          ),
        );
      },
    );
  }

  /// 組織情報カード
  Widget _buildOrganizationInfo(String organizationId) {
    return StreamBuilder<Organization?>(
      stream: _organizationService.watchOrganization(organizationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('組織情報を読み込み中...');
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          print('組織情報取得エラー: ${snapshot.error}');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('組織情報の取得に失敗しました\n${snapshot.error}'),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          print('組織データが見つかりません: $organizationId');
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('組織データが見つかりません')),
            ),
          );
        }

        final org = snapshot.data!;
        print('組織情報取得成功: ${org.name}');
        final isExpired = !org.isSubscriptionActive;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 40,
                      color: isExpired ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            org.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            org.businessType.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      'スタッフ数',
                      '${org.activeUserCount}人',
                      Colors.blue,
                    ),
                    _buildInfoItem(
                      'プラン',
                      org.subscriptionPlan.displayName,
                      isExpired ? Colors.red : Colors.green,
                    ),
                    _buildInfoItem(
                      '月額',
                      '¥${org.monthlyTotal.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                      Colors.orange,
                    ),
                  ],
                ),
                if (isExpired) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'サブスクリプションの期限が切れています',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 今日の統計
  Widget _buildTodayStats(String organizationId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('今日の統計を読み込み中...');
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          print('今日の統計取得エラー: ${snapshot.error}');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange),
                    const SizedBox(height: 8),
                    Text(
                      '統計データの取得に失敗しました\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          print('今日の統計データなし');
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('データがありません')),
            ),
          );
        }

        print('今日の統計取得成功: ${snapshot.data!.docs.length}件');

        final requests = snapshot.data!.docs
            .map((doc) => ServiceRequest.fromFirestore(doc))
            .toList();

        final total = requests.length;
        final completed =
            requests.where((r) => r.status == RequestStatus.completed).length;
        final inProgress =
            requests.where((r) => r.status == RequestStatus.inProgress).length;
        final pending = requests
            .where((r) =>
                r.status == RequestStatus.pending ||
                r.status == RequestStatus.workerAssigned)
            .length;

        final totalRevenue = requests
            .where((r) => r.status == RequestStatus.completed)
            .fold<int>(0, (sum, r) => sum + r.totalPrice);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日の実績',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('総依頼数', '$total件', Colors.blue),
                    _buildStatItem('完了', '$completed件', Colors.green),
                    _buildStatItem('進行中', '$inProgress件', Colors.orange),
                    _buildStatItem('待機', '$pending件', Colors.grey),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '今日の売上: ',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '¥${totalRevenue.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 最近の依頼
  Widget _buildRecentRequests(String organizationId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近の依頼',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('requests')
              .where('organizationId', isEqualTo: organizationId)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('最近の依頼を読み込み中...');
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('最近の依頼取得エラー: ${snapshot.error}');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.orange),
                        const SizedBox(height: 8),
                        Text(
                          '依頼データの取得に失敗しました\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              print('最近の依頼データなし');
              return const Center(child: CircularProgressIndicator());
            }

            print('最近の依頼取得成功: ${snapshot.data!.docs.length}件');

            final requests = snapshot.data!.docs
                .map((doc) => ServiceRequest.fromFirestore(doc))
                .toList();

            if (requests.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'まだ依頼がありません',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: requests
                  .map((request) => _buildRequestListItem(request))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestListItem(ServiceRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: request.status.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(request.status),
            color: request.status.color,
            size: 24,
          ),
        ),
        title: Text(
          request.serviceMenuName ?? 'サービス',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${request.customerName} 様 - ${DateFormat('M/d HH:mm').format(request.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              request.status.displayName,
              style: TextStyle(
                fontSize: 11,
                color: request.status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              request.totalPriceDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.requestDetail,
          arguments: request,
        ),
      ),
    );
  }

  IconData _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.hourglass_empty;
      case RequestStatus.workerAssigned:
        return Icons.person_add;
      case RequestStatus.driverAssigned:
        return Icons.local_shipping;
      case RequestStatus.inProgress:
        return Icons.build;
      case RequestStatus.completed:
        return Icons.check_circle;
      case RequestStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// スタッフタブ
  Widget _buildStaffTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Center(child: Text('ログインしてください'));

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final organizationId = userData['organizationId'] as String;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'スタッフ管理',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddStaffDialog(organizationId),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('新規追加',
                        style: TextStyle(color: Colors.white)),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('users')
                    .where('organizationId', isEqualTo: organizationId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.docs
                      .map((doc) => AppUser.fromFirestore(doc))
                      .toList();

                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'スタッフがいません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildStaffCard(user);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaffCard(AppUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.role.color,
          child: Text(
            user.name.isNotEmpty ? user.name[0] : '?',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.role.displayName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(user.status.icon, size: 14, color: user.status.color),
                const SizedBox(width: 4),
                Text(
                  user.status.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: user.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditStaffDialog(user);
            } else if (value == 'delete') {
              _confirmDeleteStaff(user);
            }
          },
        ),
      ),
    );
  }

  /// 財務タブ
  Widget _buildFinanceTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Center(child: Text('ログインしてください'));

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final organizationId = userData['organizationId'] as String;

        return Column(
          children: [
            _buildFinanceSummary(organizationId),
            const Divider(height: 1),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: '請求書'),
                        Tab(text: '売上履歴'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildInvoicesList(organizationId),
                          _buildRevenueHistory(organizationId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinanceSummary(String organizationId) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!.docs
            .map((doc) => ServiceRequest.fromFirestore(doc))
            .toList();

        final monthlyRevenue =
            requests.fold<int>(0, (sum, r) => sum + r.totalPrice);

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.withOpacity(0.1),
          child: Column(
            children: [
              const Text(
                '今月の売上',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${monthlyRevenue.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${requests.length}件の依頼',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicesList(String organizationId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('invoices')
          .where('organizationId', isEqualTo: organizationId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final invoices = snapshot.data!.docs
            .map((doc) => Invoice.fromFirestore(doc))
            .toList();

        if (invoices.isEmpty) {
          return const Center(
            child: Text(
              '請求書がありません',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final invoice = invoices[index];
            return _buildInvoiceCard(invoice);
          },
        );
      },
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: invoice.status.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getInvoiceIcon(invoice.status),
            color: invoice.status.color,
            size: 24,
          ),
        ),
        title: Text(
          invoice.workerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${invoice.periodDisplay}\n${DateFormat('yyyy/M/d').format(invoice.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              invoice.status.displayName,
              style: TextStyle(
                fontSize: 11,
                color: invoice.status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              invoice.totalAmountDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        onTap: () => _showInvoiceDetail(invoice),
      ),
    );
  }

  IconData _getInvoiceIcon(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Icons.edit;
      case InvoiceStatus.submitted:
        return Icons.send;
      case InvoiceStatus.approved:
        return Icons.check_circle;
      case InvoiceStatus.paid:
        return Icons.payments;
      case InvoiceStatus.rejected:
        return Icons.cancel;
    }
  }

  Widget _buildRevenueHistory(String organizationId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('requests')
          .where('organizationId', isEqualTo: organizationId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs
            .map((doc) => ServiceRequest.fromFirestore(doc))
            .toList();

        if (requests.isEmpty) {
          return const Center(
            child: Text(
              '売上履歴がありません',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt, color: Colors.green),
                title: Text(
                  request.serviceMenuName ?? 'サービス',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${request.customerName} 様\n完了: ${request.completedAt != null ? DateFormat('M/d HH:mm').format(request.completedAt!) : '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  request.totalPriceDisplay,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildSettingSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    String label,
    String value,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: onTap != null
          ? const Icon(Icons.edit, size: 20, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }

  // ダイアログ関数（実装例）
  Future<void> _showAddStaffDialog(String organizationId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スタッフ追加'),
        content: const Text(
            'スタッフ追加機能は別途Firebase Authenticationでのユーザー作成が必要です。\n\n管理者コンソールまたはオペレーター画面から追加してください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditStaffDialog(AppUser user) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スタッフ編集'),
        content: Text('${user.name}の編集機能は今後実装予定です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteStaff(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('スタッフ削除'),
        content: Text('${user.name}を削除しますか?\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(user.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('スタッフを削除しました'),
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
      }
    }
  }

  Future<void> _showInvoiceDetail(Invoice invoice) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('請求書詳細 - ${invoice.workerName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ステータス: ${invoice.status.displayName}'),
              Text('金額: ${invoice.totalAmountDisplay}'),
              Text('期間: ${invoice.periodDisplay}'),
              if (invoice.workerNote != null) ...[
                const SizedBox(height: 8),
                const Text('技術者メモ:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(invoice.workerNote!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditOrgNameDialog(Organization org) async {
    final controller = TextEditingController(text: org.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('組織名変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '組織名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await _organizationService.updateOrganization(
                organizationId: org.id,
                name: controller.text,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('組織名を更新しました')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditOrgPhoneDialog(Organization org) async {
    final controller = TextEditingController(text: org.phone);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('電話番号変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '電話番号'),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await _organizationService.updateOrganization(
                organizationId: org.id,
                phone: controller.text,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('電話番号を更新しました')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditOrgEmailDialog(Organization org) async {
    final controller = TextEditingController(text: org.email);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メールアドレス変更'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'メールアドレス'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              await _organizationService.updateOrganization(
                organizationId: org.id,
                email: controller.text,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('メールアドレスを更新しました')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubscriptionDialog(Organization org) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サブスクリプションプラン'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubscriptionPlan.values.map((plan) {
            return RadioListTile<SubscriptionPlan>(
              title: Text(plan.displayName),
              subtitle: Text(
                  '¥${plan.monthlyPrice}/人/月${plan.maxUsers != null ? ' (最大${plan.maxUsers}人)' : ''}'),
              value: plan,
              groupValue: org.subscriptionPlan,
              onChanged: (value) async {
                if (value != null) {
                  await _organizationService.updateSubscriptionPlan(
                    organizationId: org.id,
                    plan: value,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('プランを${value.displayName}に変更しました')),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _showComingSoonDialog(String feature) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('準備中'),
        content: Text('$featureは今後実装予定です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}
