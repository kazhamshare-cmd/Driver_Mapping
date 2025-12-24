import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../models/order.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/printer_service.dart';
import '../../../services/unified_printer_service.dart';

class OrderDetailSheet extends ConsumerWidget {
  final OrderModel order;

  const OrderDetailSheet({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateOrderStatus = ref.read(updateOrderStatusProvider);
    final t = ref.watch(translationProvider);
    final dateFormatter = DateFormat('yyyy/MM/dd HH:mm');

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ヘッダー
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.text('table')} ${order.tableNumber}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.orderNumber,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // コンテンツ
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 注文情報
                    _buildInfoCard(
                      context,
                      title: t.text('orderDetails'),
                      children: [
                        _buildInfoRow(t.text('orderedAt'), dateFormatter.format(order.orderedAt)),
                        _buildInfoRow(t.text('status'), order.getStatusText()),
                        _buildInfoRow(t.text('payment'), order.getPaymentStatusText()),
                        // 印刷状態
                        _buildInfoRow(
                          '伝票印刷',
                          order.isPrinted
                              ? '印刷済み (${dateFormatter.format(order.printedAt!)})'
                              : '未印刷',
                        ),
                        if (order.orderedBy != null) ...[
                          const Divider(),
                          if (order.orderedBy!.isStaffOrder)
                            _buildInfoRow(
                              t.text('proxyOrder'),
                              order.orderedBy!.staffName ?? t.text('noData'),
                            ),
                          _buildInfoRow(
                            order.orderedBy!.isStaffOrder ? t.text('customerName') : t.text('customerName'),
                            order.orderedBy!.userName ??
                            order.orderedBy!.userPhone ??
                            order.orderedBy!.userEmail ??
                            t.text('noData'),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 再印刷ボタン
                    _buildReprintButton(context),

                    const SizedBox(height: 16),

                    // オーナー専用: 注文削除ボタン
                    Consumer(
                      builder: (context, ref, child) {
                        final isOwner = ref.watch(isOwnerProvider);
                        if (!isOwner) return const SizedBox.shrink();
                        return _buildDeleteOrderButton(context, ref);
                      },
                    ),

                    const SizedBox(height: 16),

                    // 商品リスト
                    _buildInfoCard(
                      context,
                      title: t.text('items'),
                      children: [
                        ...order.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Column(
                            children: [
                              if (index > 0) const Divider(),
                              _buildOrderItem(context, item, t),
                            ],
                          );
                        }).toList(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 金額
                    _buildInfoCard(
                      context,
                      title: t.text('checkout'),
                      children: [
                        _buildInfoRow(t.text('subtotal'), '¥${order.subtotal.toInt()}'),
                        _buildInfoRow(t.text('tax'), '¥${order.tax.toInt()}'),
                        const Divider(),
                        _buildInfoRow(
                          t.text('total'),
                          '¥${order.total.toInt()}',
                          isTotal: true,
                        ),
                      ],
                    ),

                    if (order.notes != null) ...[
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        context,
                        title: t.text('notes'),
                        children: [
                          Text(order.notes!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // アクションボタン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: _buildActionButtons(context, ref, updateOrderStatus, t),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// 再印刷ボタン
  Widget _buildReprintButton(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'キッチン伝票',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _reprintKitchenTicket(context),
                icon: const Icon(Icons.print),
                label: Text(order.isPrinted ? '再印刷' : '印刷'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (order.isPrinted) ...[
              const SizedBox(height: 8),
              Text(
                '※ 既に印刷済みです。伝票を紛失した場合のみ再印刷してください。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// オーナー専用: 注文削除ボタン
  Widget _buildDeleteOrderButton(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'オーナー専用',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteOrderDialog(context, ref),
                icon: const Icon(Icons.delete_forever),
                label: const Text('この注文を完全に削除'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '※ 削除した注文は復元できません。売上データにも反映されなくなります。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 注文削除確認ダイアログ
  Future<void> _showDeleteOrderDialog(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    final staffUser = ref.read(staffUserProvider).value;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('注文を完全に削除'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.tableNumber}番テーブル',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text('注文番号: ${order.orderNumber}'),
                  Text('合計金額: ¥${order.total.toInt()}'),
                  Text('商品数: ${order.items.length}点'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ この操作は取り消せません',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '削除された注文は：\n• 売上レポートから除外されます\n• 履歴から完全に消去されます\n• 復元することはできません',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '削除理由 *',
                hintText: '例: 重複注文、テスト注文など',
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
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('削除理由を入力してください'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('完全に削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // 削除ログを記録してから削除
        final deleteLog = {
          'orderId': order.id,
          'orderNumber': order.orderNumber,
          'tableNumber': order.tableNumber,
          'total': order.total,
          'itemCount': order.items.length,
          'deletedBy': staffUser?.id ?? 'unknown',
          'deletedByName': staffUser?.name ?? 'オーナー',
          'deleteReason': reasonController.text.trim(),
          'deletedAt': FieldValue.serverTimestamp(),
          'originalOrderData': {
            'items': order.items.map((item) => {
              'productName': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'subtotal': item.subtotal,
            }).toList(),
            'subtotal': order.subtotal,
            'tax': order.tax,
            'orderedAt': order.orderedAt,
            'status': order.status.name,
          },
        };

        // 削除ログをFirestoreに保存
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(order.shopId)
            .collection('deletedOrders')
            .add(deleteLog);

        // 注文を削除
        await FirebaseFirestore.instance.collection('orders').doc(order.id).delete();

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('注文を削除しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('削除エラー: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// キッチン伝票を再印刷
  Future<void> _reprintKitchenTicket(BuildContext context) async {
    final printerService = PrinterService();

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('印刷確認'),
        content: Text(
          order.isPrinted
              ? 'キッチン伝票を再印刷しますか？\n\n※ 伝票を紛失した場合以外は再印刷しないでください。'
              : 'キッチン伝票を印刷しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('印刷'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 印刷実行
    try {
      final result = await printerService.printKitchenTicket(order);

      if (result) {
        // 印刷成功時にprintedAtを更新（初回印刷の場合のみ）
        if (!order.isPrinted) {
          await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
            'printedAt': FieldValue.serverTimestamp(),
          });
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('印刷しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('印刷に失敗しました。プリンター設定を確認してください。'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('印刷エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item, AppTranslations t) {
    // 割引情報があるかチェック（注文時に保存されている場合）
    final hasDiscount = item.discountInfo != null;
    final originalPrice = hasDiscount
        ? (item.discountInfo!['originalPrice'] as num?)?.toDouble()
        : null;
    final discountLabel = hasDiscount
        ? item.discountInfo!['discountLabel'] as String?
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // 割引タグ表示
                  if (hasDiscount && discountLabel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            discountLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '¥${originalPrice.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const Text(' → '),
                          Text(
                            '¥${item.unitPrice.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'x${item.quantity}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '¥${item.subtotal.toInt()}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (item.selectedOptions.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...item.selectedOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                '+ ${option.choiceName} (+¥${option.price.toInt()})',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            );
          }),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '${t.text('notes')}: ${item.notes}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Function(String, OrderStatus) updateOrderStatus,
    AppTranslations t,
  ) {
    // WEB版と同じシンプルな2段階フロー
    // 注文受付(pending/confirmed/preparing) → 提供完了 → 提供済み(served)
    final buttons = <Widget>[];

    switch (order.status) {
      // 注文受付状態（pending, confirmed, preparing, ready）
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        buttons.addAll([
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCancelDialog(context, ref, t),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: Text(t.text('cancel')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _updateStatus(
                context,
                ref,
                updateOrderStatus,
                OrderStatus.served,
                t.text('confirmCookingComplete'),
                t,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text(t.text('cookingComplete')),
            ),
          ),
        ]);
        break;

      // 提供済み（再会計・再印刷用）
      case OrderStatus.served:
        buttons.addAll([
          // 注文受付に戻す
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateStatus(
                context,
                ref,
                updateOrderStatus,
                OrderStatus.pending,
                t.text('confirmRevertToPending'),
                t,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
              child: Text(t.text('revertToPending')),
            ),
          ),
          const SizedBox(width: 8),
          // レシート再印刷
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _reprintReceipt(context, ref, t),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('再印刷'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // レジ画面へ（再会計）
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // レジ画面へ遷移
                context.go('/register');
              },
              child: Text(t.text('checkout')),
            ),
          ),
        ]);
        break;

      case OrderStatus.completed:
      case OrderStatus.cancelled:
        buttons.add(
          Expanded(
            child: Center(
              child: Text(
                order.status == OrderStatus.cancelled
                    ? t.text('cancelled')
                    : t.text('completed'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        );
        break;
    }

    return Row(children: buttons);
  }

  /// キャンセルダイアログを表示（スタッフ情報と理由入力）
  /// 全スタッフがキャンセル可能（理由入力は必須、履歴は残る）
  Future<void> _showCancelDialog(
    BuildContext context,
    WidgetRef ref,
    AppTranslations t,
  ) async {
    final reasonController = TextEditingController();
    final staffUser = ref.read(staffUserProvider).value;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('注文キャンセル'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.tableNumber}番テーブルの注文をキャンセルしますか？',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '合計金額: ¥${order.total.toInt()}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'キャンセル理由 *',
                hintText: '例: お客様都合、在庫切れ、誤注文など',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '※ オーナーがキャンセル内容を確認します',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('戻る'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('キャンセル理由を入力してください'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, {'reason': reason});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('キャンセル実行'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      try {
        final updateOrderStatus = ref.read(updateOrderStatusProvider);
        await updateOrderStatus(
          order.id,
          OrderStatus.cancelled,
          staffId: staffUser?.id,
          staffName: staffUser?.name ?? 'スタッフ',
          reason: result['reason'],
        );
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('注文をキャンセルしました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    Function(String, OrderStatus) updateOrderStatus,
    OrderStatus newStatus,
    String confirmMessage,
    AppTranslations t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.text('confirm')),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.text('ok')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await updateOrderStatus(order.id, newStatus);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.text('orderUpdated'))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.text('errorOccurred')}: $e')),
          );
        }
      }
    }
  }

  /// レシート再印刷
  Future<void> _reprintReceipt(
    BuildContext context,
    WidgetRef ref,
    AppTranslations t,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レシート印刷中...')),
      );

      final printerService = UnifiedPrinterService();
      final success = await printerService.printPaymentReceipt(
        order: order,
        grandTotal: order.total,
        paymentMethod: 'cash', // 元の支払い方法は不明なのでデフォルト
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'レシートを印刷しました' : 'レシート印刷に失敗しました'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('印刷エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
