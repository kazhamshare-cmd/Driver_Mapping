import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../models/user_status.dart';
import '../../models/service_request.dart';
import '../../models/request_status.dart';
import 'create_dispatch_screen.dart';
import 'live_map_screen.dart';

class OperatorHomeScreen extends ConsumerStatefulWidget {
  const OperatorHomeScreen({super.key});

  @override
  ConsumerState<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends ConsumerState<OperatorHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  int _selectedIndex = 0;

  // 札幌市中心部をデフォルト位置に設定
  static const LatLng _sapporoCenter = LatLng(43.0642, 141.3469);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('オペレーター画面'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRequestsTab(),
          _buildMapTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: '依頼一覧',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'マップ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateDispatchScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('新規依頼'),
            )
          : null,
    );
  }

  /// 依頼一覧タブ
  Widget _buildRequestsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade100,
          child: const Row(
            children: [
              Icon(Icons.assignment, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '配車依頼',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('requests')
                .where('status',
                    whereIn: [
                      RequestStatus.pending.toJson(),
                      RequestStatus.workerAssigned.toJson(),
                      RequestStatus.inProgress.toJson(),
                    ])
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('現在、配車依頼はありません'),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final request = ServiceRequest.fromFirestore(
                    snapshot.data!.docs[index],
                  );
                  return _buildRequestCard(request);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// マップタブ
  Widget _buildMapTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade100,
          child: const Row(
            children: [
              Icon(Icons.map, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '待機中のスタッフ位置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('status', isEqualTo: UserStatus.available.toJson())
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final availableUsers = snapshot.data!.docs
                  .map((doc) => AppUser.fromFirestore(doc))
                  .where((user) =>
                      user.location != null &&
                      (user.role == UserRole.worker ||
                          user.role == UserRole.driver))
                  .toList();

              return _buildMapWithStaff(availableUsers);
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
          '設定・その他',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text('リアルタイムマップ'),
                subtitle: const Text('全スタッフの位置をリアルタイムで表示'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveMapScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.orange),
                title: const Text('履歴'),
                subtitle: const Text('過去の配車依頼履歴'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('履歴機能は今後実装予定です')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications, color: Colors.purple),
                title: const Text('通知設定'),
                subtitle: const Text('プッシュ通知の設定'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('通知設定は今後実装予定です')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 地図とスタッフマーカーを表示
  Widget _buildMapWithStaff(List<AppUser> availableUsers) {
    final markers = <Marker>{};

    // スタッフごとにマーカーを作成
    for (final user in availableUsers) {
      if (user.location == null) continue;

      final markerId = MarkerId(user.id);
      final position = LatLng(
        user.location!.latitude,
        user.location!.longitude,
      );

      // 役割に応じてマーカーの色を変える
      BitmapDescriptor markerColor;
      if (user.role == UserRole.worker) {
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else {
        // driver
        markerColor = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }

      markers.add(
        Marker(
          markerId: markerId,
          position: position,
          icon: markerColor,
          infoWindow: InfoWindow(
            title: user.name,
            snippet: '${user.role.displayName} - ${user.status.displayName}',
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _sapporoCenter,
        zoom: 12,
      ),
      markers: markers,
      onMapCreated: (controller) {
        _mapController = controller;
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
    );
  }

  /// 依頼カードを作成
  Widget _buildRequestCard(ServiceRequest request) {
    Color statusColor;
    switch (request.status) {
      case RequestStatus.pending:
        statusColor = Colors.orange;
        break;
      case RequestStatus.workerAssigned:
      case RequestStatus.driverAssigned:
        statusColor = Colors.blue;
        break;
      case RequestStatus.inProgress:
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 8,
          color: statusColor,
        ),
        title: Text(
          request.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.serviceType.displayName),
            Text(request.dispatchType.displayName),
            if (request.assignedWorkerId != null)
              Text(
                '担当者: アサイン済み',
                style: TextStyle(color: Colors.blue.shade700),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                request.status.displayName,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getUrgencyColor(request.urgency).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '緊急度: ${request.urgency.displayName}',
                style: TextStyle(
                  color: _getUrgencyColor(request.urgency),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: 依頼詳細画面へ遷移
          _showRequestDetail(request);
        },
      ),
    );
  }

  Color _getUrgencyColor(Urgency urgency) {
    switch (urgency) {
      case Urgency.low:
        return Colors.green;
      case Urgency.medium:
        return Colors.orange;
      case Urgency.high:
        return Colors.red;
    }
  }

  /// 依頼詳細ダイアログを表示
  void _showRequestDetail(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request.customerName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('サービス種別', request.serviceType.displayName),
              _buildDetailRow('配車タイプ', request.dispatchType.displayName),
              _buildDetailRow('緊急度', request.urgency.displayName),
              _buildDetailRow('ステータス', request.status.displayName),
              _buildDetailRow('電話番号', request.customerPhone),
              if (request.customerAddress != null)
                _buildDetailRow('住所', request.customerAddress!),
              if (request.description != null)
                _buildDetailRow('詳細', request.description!),
              if (request.serviceMenuName != null)
                _buildDetailRow('メニュー', request.serviceMenuName!),
              if (request.estimatedPrice != null)
                _buildDetailRow('見積金額', '¥${request.estimatedPrice}'),
              if (request.specialNotes != null)
                _buildDetailRow('特記事項', request.specialNotes!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
