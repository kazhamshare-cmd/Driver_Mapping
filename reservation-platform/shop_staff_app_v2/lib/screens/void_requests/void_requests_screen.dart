import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/void_request.dart';
import '../../providers/void_request_provider.dart';
import '../../providers/auth_provider.dart';

/// バック承認画面（管理者用）
class VoidRequestsScreen extends ConsumerStatefulWidget {
  const VoidRequestsScreen({super.key});

  @override
  ConsumerState<VoidRequestsScreen> createState() => _VoidRequestsScreenState();
}

class _VoidRequestsScreenState extends ConsumerState<VoidRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final canManage = ref.watch(canManageVoidRequestsProvider);
    final pendingCount = ref.watch(pendingVoidRequestCountProvider);

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('バック承認')),
        body: const Center(
          child: Text('この画面はマネージャー・オーナーのみアクセスできます'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('バック承認'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('承認待ち'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: '履歴'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final pendingRequests = ref.watch(pendingVoidRequestsProvider);

    return pendingRequests.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '承認待ちの申請はありません',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request, showActions: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildHistoryTab() {
    final allRequests = ref.watch(allVoidRequestsProvider);

    return allRequests.when(
      data: (requests) {
        final historyRequests = requests
            .where((r) => r.status != VoidRequestStatus.pending)
            .toList();

        if (historyRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  '履歴はありません',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: historyRequests.length,
          itemBuilder: (context, index) {
            final request = historyRequests[index];
            return _buildRequestCard(request, showActions: false);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('エラー: $error')),
    );
  }

  Widget _buildRequestCard(VoidRequest request, {required bool showActions}) {
    final dateFormat = DateFormat('MM/dd HH:mm');

    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case VoidRequestStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case VoidRequestStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case VoidRequestStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ステータスと日時
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  request.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(request.requestedAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            const Divider(),

            // 商品情報
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '数量: ${request.quantity} / 金額: ¥${request.price}',
                        style: TextStyle(color: Colors.grey.shade700),
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
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-¥${request.price * request.quantity}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 理由
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '取消理由',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(request.reason),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 申請者
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '申請者: ${request.requestedByName}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            // 承認者（履歴の場合）
            if (!showActions && request.reviewedByName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.verified_user, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '承認者: ${request.reviewedByName}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  if (request.reviewedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(request.reviewedAt!),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // レビューコメント
            if (!showActions && request.reviewComment != null && request.reviewComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'コメント: ${request.reviewComment}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],

            // アクションボタン
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(request),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('却下'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(request),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('承認'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showApproveDialog(VoidRequest request) async {
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('バック承認'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.itemName}の取消を承認しますか？',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '取消金額: ¥${request.price * request.quantity}',
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'コメント（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('承認する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final approve = ref.read(approveVoidRequestProvider);
        await approve(request.id, comment: commentController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バックを承認しました'),
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

    commentController.dispose();
  }

  Future<void> _showRejectDialog(VoidRequest request) async {
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('バック却下'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.itemName}の取消申請を却下しますか？',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: '却下理由',
                border: OutlineInputBorder(),
                hintText: '理由を入力してください',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('却下する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reject = ref.read(rejectVoidRequestProvider);
        await reject(request.id, comment: commentController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('バック申請を却下しました'),
              backgroundColor: Colors.orange,
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

    commentController.dispose();
  }
}
