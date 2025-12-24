import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../providers/order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/printer_service.dart';
import 'widgets/order_card.dart';
import 'widgets/order_detail_sheet.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  final String? newOrderId;  // 代理注文から渡される新規注文ID

  const OrdersScreen({super.key, this.newOrderId});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String? _selectedTableFilter;
  Set<String> _selectedCategoryIds = {};  // 複数カテゴリ選択

  final _printerService = PrinterService();

  final Set<String> _processedOrderIds = {};

  static const String _categoryFilterKey = 'order_category_filter';

  @override
  void initState() {
    super.initState();
    // WEB版と同じ2タブ構成（注文受付 / 提供済み）
    _tabController = TabController(length: 3, vsync: this);
    _loadCategoryFilter();
    // アプリのライフサイクル監視を開始
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻った時、未印刷の注文をチェック
      debugPrint('📱 アプリがフォアグラウンドに復帰 - 未印刷注文をチェックします');
      _checkAndPrintUnprintedOrders();
    }
  }

  /// 未印刷の注文をチェックして印刷
  Future<void> _checkAndPrintUnprintedOrders() async {
    final ordersAsync = ref.read(activeOrdersProvider);
    ordersAsync.whenData((orders) async {
      // pending状態かつ未印刷の注文を抽出
      final unprintedOrders = orders.where((order) =>
        order.status == OrderStatus.pending &&
        !order.isPrinted &&
        order.paymentStatus != PaymentStatus.paid
      ).toList();

      if (unprintedOrders.isEmpty) {
        debugPrint('📱 未印刷の注文はありません');
        return;
      }

      debugPrint('🖨️ 未印刷の注文が ${unprintedOrders.length} 件あります。印刷を開始します...');

      for (final order in unprintedOrders) {
        try {
          final result = await _printerService.printKitchenTicket(order);
          if (result) {
            await _markOrderAsPrinted(order.id);
            debugPrint('✅ 注文 ${order.id} を印刷しました');
          }
        } catch (e) {
          debugPrint('❌ 印刷エラー: $e');
        }
      }

      if (mounted && unprintedOrders.isNotEmpty) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${unprintedOrders.length}${t.text('unprintedOrdersPrinted')}'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// SharedPreferencesからカテゴリフィルターを読み込み
  Future<void> _loadCategoryFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList(_categoryFilterKey);
    if (savedCategories != null && savedCategories.isNotEmpty) {
      setState(() {
        _selectedCategoryIds = savedCategories.toSet();
      });
    }
  }

  /// カテゴリフィルターをSharedPreferencesに保存
  Future<void> _saveCategoryFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoryFilterKey, _selectedCategoryIds.toList());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// 注文が選択カテゴリに該当するかチェック
  bool _orderMatchesCategoryFilter(OrderModel order) {
    if (_selectedCategoryIds.isEmpty) return true;
    return order.items.any((item) =>
        item.categoryId != null && _selectedCategoryIds.contains(item.categoryId));
  }

  /// 新規注文を検出して通知＆印刷
  Future<void> _checkForNewOrders(List<OrderModel> orders) async {
    debugPrint('🔍 _checkForNewOrders 開始: 全${orders.length}件');

    // ステータスが pending (新規) のものを確認
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).toList();
    debugPrint('🔍 pending状態の注文: ${pendingOrders.length}件');

    // その中で、まだ処理していない(IDがセットにない)かつ未印刷のものを抽出
    // ※ 印刷済みの注文がステータス変更で再度pendingになっても新規扱いしない
    final newPendingOrders = pendingOrders
        .where((order) => !_processedOrderIds.contains(order.id) && !order.isPrinted)
        .toList();

    debugPrint('🔍 新規判定された注文: ${newPendingOrders.length}件');

    // カテゴリフィルターが設定されている場合、該当カテゴリの注文のみ通知
    final ordersToNotify = _selectedCategoryIds.isEmpty
        ? newPendingOrders
        : newPendingOrders.where(_orderMatchesCategoryFilter).toList();

    debugPrint('🔍 通知対象の注文: ${ordersToNotify.length}件（カテゴリフィルター: ${_selectedCategoryIds.isEmpty ? "なし" : _selectedCategoryIds.join(", ")}）');

    if (ordersToNotify.isNotEmpty) {
      // 通知音はmain.dartのグローバル検知で鳴らすため、ここでは鳴らさない

      // 自動印刷（伝票） - 未印刷のもののみ
      for (final order in ordersToNotify) {
        // 印刷済みチェック（Firestoreのフラグを確認）
        if (order.isPrinted) {
          debugPrint('🖨️ 注文ID ${order.id} は既に印刷済みのためスキップ');
          continue;
        }

        // 会計済みチェック（会計済みの注文はキッチン伝票を印刷しない）
        if (order.status == OrderStatus.completed || order.paymentStatus == PaymentStatus.paid) {
          debugPrint('🖨️ 注文ID ${order.id} は会計済みのためスキップ (status: ${order.status}, payment: ${order.paymentStatus})');
          continue;
        }

        try {
          debugPrint('🖨️ 印刷を試みます: 注文ID ${order.id}');
          final result = await _printerService.printKitchenTicket(order);
          debugPrint('🖨️ 印刷結果: $result');

          // 印刷成功時にFirestoreのprintedAtを更新
          if (result) {
            await _markOrderAsPrinted(order.id);
          }
        } catch (e) {
          debugPrint('❌ 自動印刷エラー: $e');
        }
      }

      if (mounted) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ordersToNotify.length}${t.text('newOrdersReceived')}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      debugPrint('🔍 通知対象の新規注文はありませんでした');
    }

    // 全てのpending注文を処理済みとしてマーク（フィルター関係なく、印刷済み含む）
    for (final order in pendingOrders) {
      _processedOrderIds.add(order.id);
    }
  }

  /// 注文を印刷済みとしてマーク
  Future<void> _markOrderAsPrinted(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'printedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 印刷済みフラグを更新: $orderId');
    } catch (e) {
      debugPrint('❌ 印刷済みフラグ更新エラー: $e');
    }
  }

  /// 注文にカテゴリフィルターを適用
  List<OrderModel> _applyFilters(List<OrderModel> orders) {
    var filtered = orders;

    // テーブルフィルター
    if (_selectedTableFilter != null) {
      filtered = filtered.where((order) => order.tableNumber == _selectedTableFilter).toList();
    }

    // カテゴリフィルター（選択されている場合のみ）
    if (_selectedCategoryIds.isNotEmpty) {
      filtered = filtered.where((order) {
        // 注文内の商品のうち、選択カテゴリに該当するものがあるかチェック
        return order.items.any((item) =>
            item.categoryId != null && _selectedCategoryIds.contains(item.categoryId));
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(activeOrdersProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final t = ref.watch(translationProvider);
    final locale = ref.watch(localeProvider);

    // カテゴリ情報を取得
    final staffUser = ref.watch(staffUserProvider).value;
    final shopId = staffUser?.shopId ?? '';
    final categoriesAsync = ref.watch(productCategoriesProvider(shopId));

    // 注文リストの変更を監視
    ref.listen<AsyncValue<List<OrderModel>>>(activeOrdersProvider, (previous, next) {
      next.whenData((newOrders) {
        debugPrint('📥 データ更新検知: ${newOrders.length}件');

        // 初回ロード時の処理
        if (previous == null || previous.isLoading || previous.hasError) {
            debugPrint('📥 初回ロードのため、既存の注文を既読にします');
            debugPrint('📥 newOrderId（通知対象）: ${widget.newOrderId}');
            for (var order in newOrders) {
              // 代理注文から渡された新規注文IDは既読にしない（通知を鳴らすため）
              if (widget.newOrderId != null && order.id == widget.newOrderId) {
                debugPrint('📥 新規注文ID ${order.id} は既読にしません（通知対象）');
                continue;
              }
              // pending状態または印刷済みの注文は処理済みとしてマーク
              if (order.status == OrderStatus.pending || order.isPrinted) {
                _processedOrderIds.add(order.id);
              }
            }
            // 初回ロード後に新規注文をチェック（newOrderIdがある場合は通知を鳴らす）
            if (widget.newOrderId != null) {
              debugPrint('📥 新規注文IDがあるため、通知チェックを実行します');
              _checkForNewOrders(newOrders);
            }
            return;
        }

        // データ更新時（新規注文追加時）にチェック実行
        _checkForNewOrders(newOrders);
      });
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(t.text('orderManagement')),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  // ★ 手動テスト機能 ★
                  final currentOrders = ordersAsync.value;
                  if (currentOrders != null && currentOrders.isNotEmpty) {
                    final latestOrder = currentOrders.first;
                    debugPrint('🔧 手動テスト: 最新の注文(${latestOrder.id})を強制処理します');
                    _processedOrderIds.remove(latestOrder.id);
                    _checkForNewOrders(currentOrders);
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.text('noOrdersToTest'))),
                    );
                  }
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
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
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.text('pending')),  // 注文受付
            Tab(text: t.text('served')),   // 提供済み
            Tab(text: t.text('todayPaid')),   // 本日会計済み
          ],
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          // フィルターを適用
          final filteredOrders = _applyFilters(orders);

          // 当日の開始時刻（午前0時）
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);

          // WEB版と同じ: pending/confirmed/preparing/ready は「注文受付」、served は「提供済み」
          final activeOrders = filteredOrders.where((o) =>
              o.status == OrderStatus.pending ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.ready).toList();

          // 提供済みは当日分のみ表示（再会計・再印刷用）
          final servedOrders = filteredOrders.where((o) =>
              o.status == OrderStatus.served &&
              o.orderedAt.isAfter(todayStart)).toList()
            ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt)); // 新しい順

          // 本日会計済み（completed または paid）
          final todayPaidOrders = filteredOrders.where((o) =>
              (o.status == OrderStatus.completed || o.paymentStatus == PaymentStatus.paid) &&
              o.orderedAt.isAfter(todayStart)).toList()
            ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt)); // 新しい順

          final allTableNumbers = orders.map((o) => o.tableNumber).toSet().toList()..sort();
          final categories = categoriesAsync.value ?? [];

          return Column(
            children: [
              // テーブルフィルター
              _buildTableFilter(allTableNumbers),
              // カテゴリフィルター（キッチン担当別）
              if (categories.isNotEmpty)
                _buildCategoryFilter(categories, locale.languageCode, t),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 注文受付タブ（pending/confirmed/preparing/ready）
                    _buildOrderList(context, activeOrders, OrderStatus.pending),
                    // 提供済みタブ
                    _buildOrderList(context, servedOrders, OrderStatus.served),
                    // 本日会計済みタブ
                    _buildOrderList(context, todayPaidOrders, OrderStatus.completed),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${t.text('errorOccurred')}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(activeOrdersProvider),
                child: Text(t.text('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableFilter(List<String> tableNumbers) {
    if (tableNumbers.isEmpty) return const SizedBox.shrink();
    final t = ref.watch(translationProvider);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(t.text('all')),
              selected: _selectedTableFilter == null,
              onSelected: (selected) {
                setState(() => _selectedTableFilter = null);
              },
            ),
          ),
          ...tableNumbers.map((tableNumber) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${t.text('table')} $tableNumber'),
                  selected: _selectedTableFilter == tableNumber,
                  onSelected: (selected) {
                    setState(() => _selectedTableFilter = selected ? tableNumber : null);
                  },
                ),
              )),
        ],
      ),
    );
  }

  /// カテゴリフィルター（複数選択可能）
  Widget _buildCategoryFilter(List<ProductCategory> categories, String langCode, AppTranslations t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  t.text('targetCategory'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedCategoryIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryIds.clear();
                      });
                      _saveCategoryFilter();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(t.text('clearFilter')),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: categories.map((category) {
                final isSelected = _selectedCategoryIds.contains(category.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category.getLocalizedName(langCode)),
                    selected: isSelected,
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategoryIds.add(category.id);
                        } else {
                          _selectedCategoryIds.remove(category.id);
                        }
                      });
                      _saveCategoryFilter();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<OrderModel> orders, OrderStatus currentStatus) {
    final t = ref.watch(translationProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: isTablet ? 80 : 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(t.text('noOrders'), style: TextStyle(fontSize: isTablet ? 18 : 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    // タブレットの場合は2列のGridView
    if (isTablet) {
      return RefreshIndicator(
        onRefresh: () async => ref.invalidate(activeOrdersProvider),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: screenWidth > 900 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: screenWidth > 900 ? 0.85 : 0.75,
          ),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return OrderCard(
              order: order,
              onTap: () => _showOrderDetail(context, order),
            );
          },
        ),
      );
    }

    // スマートフォンの場合はListView
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(activeOrdersProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCard(
            order: order,
            onTap: () => _showOrderDetail(context, order),
          );
        },
      ),
    );
  }

  void _showOrderDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderDetailSheet(order: order),
    );
  }
}