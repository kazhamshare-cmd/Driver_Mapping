import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../models/organization.dart';
import 'package:intl/intl.dart';

/// システム管理者専用のホーム画面
/// 全組織を横断管理できる
class SystemAdminHomeScreen extends StatefulWidget {
  const SystemAdminHomeScreen({super.key});

  @override
  State<SystemAdminHomeScreen> createState() => _SystemAdminHomeScreenState();
}

class _SystemAdminHomeScreenState extends State<SystemAdminHomeScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text('システム管理者ダッシュボード'),
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
          _buildOrganizationsTab(),
          _buildUsersTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'ダッシュボード',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: '組織管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'ユーザー管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'システム設定',
          ),
        ],
      ),
    );
  }

  /// ダッシュボードタブ
  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('organizations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('データがありません'));
        }

        final organizations = snapshot.data!.docs
            .map((doc) => Organization.fromFirestore(doc))
            .toList();

        final totalOrgs = organizations.length;
        final activeOrgs =
            organizations.where((org) => org.isActive).length;
        final totalUsers = organizations.fold<int>(
            0, (sum, org) => sum + org.activeUserCount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 統計カード
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '総組織数',
                      totalOrgs.toString(),
                      Icons.business,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      '稼働中',
                      activeOrgs.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '総ユーザー数',
                      totalUsers.toString(),
                      Icons.people,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      '非稼働',
                      (totalOrgs - activeOrgs).toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 最近の組織
              const Text(
                '最近追加された組織',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...organizations.take(5).map((org) => _buildOrgCard(org)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgCard(Organization org) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: org.isActive ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.business,
            color: org.isActive ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          org.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${org.businessType.displayName} | ${org.activeUserCount}人 | ${org.subscriptionPlan.displayName}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(
          org.isActive ? Icons.check_circle : Icons.cancel,
          color: org.isActive ? Colors.green : Colors.red,
        ),
        onTap: () => _showOrganizationDetail(org),
      ),
    );
  }

  /// 組織管理タブ
  Widget _buildOrganizationsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '組織一覧',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: 組織追加ダイアログ
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('組織追加機能は今後実装予定です')),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('新規組織',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('organizations')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('組織がありません'));
              }

              final organizations = snapshot.data!.docs
                  .map((doc) => Organization.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: organizations.length,
                itemBuilder: (context, index) {
                  return _buildOrgCard(organizations[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// ユーザー管理タブ
  Widget _buildUsersTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '全ユーザー一覧',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('ユーザーがいません'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(data['name']?[0] ?? '?'),
                      ),
                      title: Text(data['name'] ?? '名前なし'),
                      subtitle: Text(
                        '${data['email'] ?? ''}\nロール: ${data['role'] ?? ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        data['organizationId'] ?? '',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 設定タブ
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'システム設定',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text('システム情報'),
                subtitle: const Text('バージョン: 1.0.0'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.category, color: Colors.orange),
                title: const Text('サービスタイプマスタ'),
                subtitle: const Text('全組織共通の業種マスタ管理'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: サービスタイプマスタ管理画面へ
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('今後実装予定です')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.backup, color: Colors.green),
                title: const Text('バックアップ'),
                subtitle: const Text('データベースのバックアップ'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('今後実装予定です')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 組織詳細ダイアログ
  Future<void> _showOrganizationDetail(Organization org) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              org.isActive ? Icons.check_circle : Icons.cancel,
              color: org.isActive ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(org.name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('組織ID', org.id),
              _buildDetailRow('会社名', org.companyName ?? '未設定'),
              _buildDetailRow('業種', org.businessType.displayName),
              _buildDetailRow('電話番号', org.phone ?? '未設定'),
              _buildDetailRow('メールアドレス', org.email ?? '未設定'),
              _buildDetailRow('住所', org.address ?? '未設定'),
              const Divider(),
              _buildDetailRow('プラン', org.subscriptionPlan.displayName),
              _buildDetailRow('ユーザー数', '${org.activeUserCount}人'),
              if (org.maxUsers != null)
                _buildDetailRow('最大ユーザー数', '${org.maxUsers}人'),
              _buildDetailRow(
                '月額料金',
                '¥${org.monthlyTotal.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
              ),
              const Divider(),
              _buildDetailRow(
                '作成日',
                DateFormat('yyyy/MM/dd HH:mm').format(org.createdAt),
              ),
              _buildDetailRow(
                '更新日',
                DateFormat('yyyy/MM/dd HH:mm').format(org.updatedAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 組織編集画面へ
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('組織編集機能は今後実装予定です')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('編集', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
