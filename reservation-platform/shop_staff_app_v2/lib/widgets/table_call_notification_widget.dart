import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/table_call.dart';
import '../providers/table_call_provider.dart';

/// テーブル呼び出し通知のポップアップダイアログ
class TableCallNotificationDialog extends ConsumerWidget {
  const TableCallNotificationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCallsAsync = ref.watch(activeTableCallsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'テーブル呼び出し',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // コンテンツ
            Flexible(
              child: activeCallsAsync.when(
                data: (calls) {
                  if (calls.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            '現在、呼び出しはありません',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: calls.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      return _TableCallItem(call: calls[index]);
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('エラー: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 個別のテーブル呼び出しアイテム
class _TableCallItem extends ConsumerWidget {
  final TableCall call;

  const _TableCallItem({required this.call});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = call.status == TableCallStatus.pending;
    final isInProgress = call.status == TableCallStatus.inProgress;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending ? Colors.red.shade300 : Colors.orange.shade300,
          width: isPending ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // テーブル番号と呼び出し種類
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    call.displayTableName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildCallTypeBadge(call.type),
                const Spacer(),
                Text(
                  call.elapsedTimeString,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            // メッセージがある場合
            if (call.message != null && call.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                call.message!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            // 対応中の場合はスタッフ名を表示
            if (isInProgress && call.assignedStaffName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${call.assignedStaffName} が対応中',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // アクションボタン
            Row(
              children: [
                if (isPending) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ref
                            .read(tableCallNotifierProvider.notifier)
                            .respondToCall(call.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${call.displayTableName} の対応を開始しました'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('対応する'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else if (isInProgress) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final success = await ref
                            .read(tableCallNotifierProvider.notifier)
                            .cancelResponse(call.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('対応をキャンセルしました'),
                              backgroundColor: Colors.grey,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('キャンセル'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await ref
                            .read(tableCallNotifierProvider.notifier)
                            .resolveCall(call.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${call.displayTableName} の対応を完了しました'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('完了'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTypeBadge(TableCallType type) {
    IconData icon;
    Color color;

    switch (type) {
      case TableCallType.waiter:
        icon = Icons.person_outline;
        color = Colors.blue;
        break;
      case TableCallType.order:
        icon = Icons.restaurant_menu;
        color = Colors.green;
        break;
      case TableCallType.bill:
        icon = Icons.receipt_long;
        color = Colors.purple;
        break;
      case TableCallType.water:
        icon = Icons.water_drop;
        color = Colors.cyan;
        break;
      case TableCallType.other:
        icon = Icons.more_horiz;
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            call.typeDisplayName,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// テーブル呼び出し通知のバッジ付きベルアイコン
class TableCallBellIcon extends ConsumerWidget {
  final VoidCallback? onTap;

  const TableCallBellIcon({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingTableCallCountProvider);
    final activeCalls = ref.watch(activeTableCallsProvider).value ?? [];

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            pendingCount > 0 ? Icons.notifications_active : Icons.notifications_outlined,
            color: pendingCount > 0 ? Colors.orange : null,
          ),
          onPressed: onTap ?? () {
            showDialog(
              context: context,
              builder: (context) => const TableCallNotificationDialog(),
            );
          },
        ),
        if (activeCalls.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: pendingCount > 0 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                activeCalls.length > 99 ? '99+' : activeCalls.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
