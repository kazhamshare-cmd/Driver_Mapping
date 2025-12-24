import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/order.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';

class OrderCard extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  ConsumerState<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<OrderCard> {
  bool _isProcessing = false;

  /// 言語に応じて商品名を取得
  String _getLocalizedProductName(OrderItem item, String langCode) {
    switch (langCode) {
      case 'en':
        return item.productNameEn ?? item.productName;
      case 'th':
        return item.productNameTh ?? item.productName;
      default:
        return item.productName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatter = DateFormat('HH:mm');
    final elapsedTime = DateTime.now().difference(widget.order.orderedAt);
    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode;
    final t = ref.watch(translationProvider);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ヘッダー行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // テーブル番号と注文番号
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${t.text('table')} ${widget.order.tableNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.order.orderNumber,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 経過時間
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getElapsedTimeColor(elapsedTime),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatElapsedTime(elapsedTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 注文時刻と注文者情報
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    timeFormatter.format(widget.order.orderedAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 代理注文の場合はスタッフ名を表示
                  if (widget.order.orderedBy?.isStaffOrder == true) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.purple.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '代理: ${widget.order.orderedBy?.staffName ?? '不明'}',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // 商品リスト（最初の2件のみ表示 - タブレット対応でコンパクトに）
              ...widget.order.items.take(2).map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getItemStatusColor(item.status),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getLocalizedProductName(item, langCode),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // 残りの商品数を表示
              if (widget.order.items.length > 2) ...[
                const SizedBox(height: 2),
                Text(
                  '他 ${widget.order.items.length - 2} 品',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 6),
              const Divider(height: 1),
              const SizedBox(height: 4),

              // 合計金額
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.text('total'),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '¥${widget.order.total.toInt().toString()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // アクションボタン
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final updateOrderStatus = ref.read(updateOrderStatusProvider);
    final t = ref.watch(translationProvider);

    switch (widget.order.status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.ready:
        // 新規注文/確認済み/調理中/提供準備完了: キャンセル + 調理完了（直接servedへ）
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _updateStatus(updateOrderStatus, OrderStatus.cancelled, t.text('cancelled')),
                icon: const Icon(Icons.cancel, size: 18),
                label: Text(t.text('cancel')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _updateStatus(updateOrderStatus, OrderStatus.served, t.text('markAsServed')),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle, size: 18),
                label: Text(t.text('cookingComplete')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ],
        );

      case OrderStatus.served:
        // 提供済み: 会計処理リンク（実際の会計はレジ画面で）
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${t.text('served')} - ${t.text('checkout')}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        );

      case OrderStatus.completed:
      case OrderStatus.cancelled:
        // 完了/キャンセル済み
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              widget.order.status == OrderStatus.cancelled ? t.text('cancelled') : t.text('completed'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        );
    }
  }

  Future<void> _updateStatus(
    Function(String, OrderStatus, {String? staffId, String? staffName, String? reason}) updateOrderStatus,
    OrderStatus newStatus,
    String actionName,
  ) async {
    // キャンセルの場合は理由入力ダイアログを表示
    if (newStatus == OrderStatus.cancelled) {
      await _showCancelDialog(updateOrderStatus);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await updateOrderStatus(widget.order.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionNameしました'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
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
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showCancelDialog(
    Function(String, OrderStatus, {String? staffId, String? staffName, String? reason}) updateOrderStatus,
  ) async {
    final reasonController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('注文キャンセル'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'テーブル ${widget.order.tableNumber} - ¥${widget.order.total.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('キャンセル理由を選択または入力してください：'),
              const SizedBox(height: 12),
              // よく使う理由の選択肢
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildReasonChip('お客様都合', selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip('品切れ', selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip('オーダーミス', selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip('重複注文', selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'その他の理由',
                  hintText: '詳細を入力',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  setDialogState(() => selectedReason = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('戻る'),
            ),
            ElevatedButton(
              onPressed: reasonController.text.isEmpty
                  ? null
                  : () => Navigator.pop(context, {'reason': reasonController.text}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('キャンセル実行'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isProcessing = true);

    try {
      final staffUser = ref.read(staffUserProvider).value;

      await updateOrderStatus(
        widget.order.id,
        OrderStatus.cancelled,
        staffId: staffUser?.id,
        staffName: staffUser?.name,
        reason: result['reason'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('注文をキャンセルしました（理由: ${result['reason']}）'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
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
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildReasonChip(String label, String? selectedReason, Function(String) onSelected) {
    final isSelected = selectedReason == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(label),
      selectedColor: Colors.red.shade100,
      checkmarkColor: Colors.red,
    );
  }

  Color _getElapsedTimeColor(Duration elapsed) {
    if (elapsed.inMinutes < 10) {
      return Colors.green;
    } else if (elapsed.inMinutes < 20) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _formatElapsedTime(Duration elapsed) {
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}分';
    } else {
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes % 60;
      return '${hours}時間${minutes}分';
    }
  }

  Color _getItemStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'served':
        return Colors.grey[400]!;
      default:
        return Colors.grey;
    }
  }
}
