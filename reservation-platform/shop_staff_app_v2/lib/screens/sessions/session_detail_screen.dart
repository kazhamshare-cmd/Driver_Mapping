import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/session.dart';
import '../../models/product.dart';
import '../../providers/session_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';

/// セッション詳細画面
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({
    required this.sessionId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: Center(child: Text('エラー: $error')),
      ),
      data: (session) {
        if (session == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('セッションが見つかりません')),
            body: const Center(child: Text('セッションが見つかりません')),
          );
        }

        return _SessionDetailContent(session: session);
      },
    );
  }
}

class _SessionDetailContent extends ConsumerStatefulWidget {
  final Session session;

  const _SessionDetailContent({required this.session});

  @override
  ConsumerState<_SessionDetailContent> createState() =>
      _SessionDetailContentState();
}

class _SessionDetailContentState extends ConsumerState<_SessionDetailContent> {
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final duration = DateTime.now().difference(session.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.tableName ?? 'セッション詳細'),
        actions: [
          if (session.isInProgress)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _showCancelDialog(context),
              tooltip: 'キャンセル',
            ),
        ],
      ),
      body: Column(
        children: [
          // セッション情報ヘッダー
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    // お客様情報
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.customerName ?? 'お客様',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('${session.actualCount}名'),
                              if (session.reservedCount != null &&
                                  session.reservedCount != session.actualCount)
                                Text(
                                  ' (予約: ${session.reservedCount}名)',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 経過時間
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hours > 0 ? '$hours:${minutes.toString().padLeft(2, '0')}' : '$minutes分',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: duration.inMinutes > 120
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                        ),
                        Text(
                          '経過時間',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (session.primaryStaffName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '担当: ${session.primaryStaffName}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 注文アイテム一覧
          Expanded(
            child: session.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '注文がありません',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: session.items.length,
                    itemBuilder: (context, index) {
                      final item = session.items[index];
                      return _OrderItemCard(item: item);
                    },
                  ),
          ),

          // 合計金額と操作ボタン
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // 金額サマリー
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('小計'),
                      Text('¥${session.itemsSubtotal.toStringAsFixed(0)}'),
                    ],
                  ),
                  if (session.calculatedNominationTotal > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('指名料'),
                        Text(
                            '¥${session.calculatedNominationTotal.toStringAsFixed(0)}'),
                      ],
                    ),
                  ],
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '合計',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '¥${session.calculatedTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 操作ボタン
                  if (session.isInProgress)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAddItemDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('注文追加'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showCheckoutDialog(context),
                            icon: const Icon(Icons.payment),
                            label: const Text('会計'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            session.isCompleted
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: session.isCompleted
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            session.isCompleted ? '会計済み' : 'キャンセル済み',
                            style: TextStyle(
                              color: session.isCompleted
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddItemSheet(
        sessionId: widget.session.id,
        primaryStaffId: widget.session.primaryStaffId,
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会計確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${widget.session.calculatedTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text('会計を完了しますか？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeCheckout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('会計完了'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeCheckout() async {
    try {
      final completeSession = ref.read(completeSessionProvider);
      await completeSession(
        sessionId: widget.session.id,
        totalAmount: widget.session.calculatedTotal,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会計が完了しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('セッションをキャンセル'),
        content: const Text('このセッションをキャンセルしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('いいえ'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSession() async {
    try {
      final cancelSession = ref.read(cancelSessionProvider);
      await cancelSession(widget.session.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('セッションをキャンセルしました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}

class _OrderItemCard extends StatelessWidget {
  final SessionItem item;

  const _OrderItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${item.unitPrice.toStringAsFixed(0)} × ${item.quantity}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  if (item.nominationFee != null && item.nominationFee! > 0)
                    Text(
                      '指名料: ¥${item.nominationFee!.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '¥${item.totalWithNomination.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 注文追加シート
class _AddItemSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String? primaryStaffId;

  const _AddItemSheet({
    required this.sessionId,
    this.primaryStaffId,
  });

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final staffUser = ref.watch(staffUserProvider).value;
    if (staffUser == null) {
      return const Center(child: Text('ログインが必要です'));
    }

    final categoriesAsync = ref.watch(productCategoriesProvider(staffUser.shopId));
    final productsAsync = _selectedCategoryId == null
        ? ref.watch(productsProvider(staffUser.shopId))
        : ref.watch(productsByCategoryProvider(
            (shopId: staffUser.shopId, categoryId: _selectedCategoryId!)));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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

            // タイトル
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    '注文追加',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // カテゴリフィルター
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('エラー: $e'),
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('すべて'),
                          selected: _selectedCategoryId == null,
                          onSelected: (selected) {
                            setState(() => _selectedCategoryId = null);
                          },
                        ),
                      ),
                      ...categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat.name),
                              selected: _selectedCategoryId == cat.id,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = selected ? cat.id : null;
                                });
                              },
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),

            const Divider(),

            // 商品リスト
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('エラー: $e')),
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(child: Text('商品がありません'));
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductListItem(
                        product: product,
                        onAdd: () => _addItem(product),
                      );
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

  Future<void> _addItem(Product product) async {
    try {
      final item = SessionItem(
        id: const Uuid().v4(),
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
        quantity: 1,
        subtotal: product.price,
        performerStaffId: widget.primaryStaffId,
        nominationFee: product.isService ? product.nominationFee : null,
        createdAt: DateTime.now(),
      );

      final addItem = ref.read(addSessionItemProvider);
      await addItem(widget.sessionId, item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name}を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }
}

class _ProductListItem extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const _ProductListItem({
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: product.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  product.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.image, color: Colors.grey[400]),
              ),
        title: Text(product.name),
        subtitle: Text(
          '¥${product.price.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue),
          onPressed: product.isSoldOut ? null : onAdd,
        ),
        enabled: !product.isSoldOut,
      ),
    );
  }
}
