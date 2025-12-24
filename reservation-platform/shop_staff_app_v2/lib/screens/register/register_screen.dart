import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/table.dart';
import '../../models/order.dart';
import '../../models/shop.dart' show Shop, PaymentMethodSetting;
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/unified_printer_service.dart';
import 'register_payment_dialog.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UnifiedPrinterService _printerService = UnifiedPrinterService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// ドロワー操作ログを保存
  Future<void> _logDrawerOperation(String operationType, String shopId, String? staffId, String? staffName) async {
    try {
      await FirebaseFirestore.instance.collection('drawerLogs').add({
        'shopId': shopId,
        'operationType': operationType, // 'exchange', 'check', 'close'
        'staffId': staffId,
        'staffName': staffName ?? '不明',
        'operatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ドロワーログ保存エラー: $e');
    }
  }

  /// ドロワー操作を実行
  Future<void> _executeDrawerOperation(BuildContext context, String operationType, String label, String shopId, String? staffId, String? staffName) async {
    final t = ref.read(translationProvider);

    try {
      final success = await _printerService.openCashDrawer();
      if (success) {
        await _logDrawerOperation(operationType, shopId, staffId, staffName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label: ${t.text('drawerOpened')}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.text('drawerOpenFailed')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final shopAsync = ref.watch(shopProvider);
    final firebaseService = ref.watch(firebaseServiceProvider);
    final t = ref.watch(translationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(t.text('register')),
        actions: [
          // 両替ボタン
          staffUserAsync.when(
            data: (staffUser) => IconButton(
              onPressed: staffUser != null
                  ? () => _executeDrawerOperation(context, 'exchange', t.text('exchange'), staffUser.shopId, staffUser.id, staffUser.name)
                  : null,
              icon: const Icon(Icons.currency_exchange),
              tooltip: t.text('exchange'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // レジ金確認ボタン
          staffUserAsync.when(
            data: (staffUser) => IconButton(
              onPressed: staffUser != null
                  ? () => _executeDrawerOperation(context, 'check', t.text('registerCheck'), staffUser.shopId, staffUser.id, staffUser.name)
                  : null,
              icon: const Icon(Icons.fact_check),
              tooltip: t.text('registerCheck'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // レジ締めボタン
          staffUserAsync.when(
            data: (staffUser) => IconButton(
              onPressed: staffUser != null
                  ? () => _executeDrawerOperation(context, 'close', t.text('registerClose'), staffUser.shopId, staffUser.id, staffUser.name)
                  : null,
              icon: const Icon(Icons.point_of_sale),
              tooltip: t.text('registerClose'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.text('unpaid')),  // 未会計
            Tab(text: t.text('directCheckout')),  // 直接会計
            Tab(text: t.text('completedToday')),  // 本日会計済み
          ],
        ),
      ),
      body: staffUserAsync.when(
        data: (staffUser) {
          if (staffUser == null) {
            return Center(child: Text(t.text('userInfoNotFound')));
          }

          return shopAsync.when(
            data: (shop) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // タブ1: 未会計
                  _UnpaidTab(
                    shopId: staffUser.shopId,
                    shop: shop,
                    firebaseService: firebaseService,
                    staffId: staffUser.id,
                    staffName: staffUser.name,
                  ),
                  // タブ2: 直接会計（メニューから選んで即会計）
                  _DirectCheckoutTab(
                    shopId: staffUser.shopId,
                    shop: shop,
                    firebaseService: firebaseService,
                    staffId: staffUser.id,
                    staffName: staffUser.name,
                  ),
                  // タブ3: 本日会計済み
                  _CompletedTodayTab(
                    shopId: staffUser.shopId,
                    shop: shop,
                    firebaseService: firebaseService,
                    staffId: staffUser.id,
                    staffName: staffUser.name,
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('${t.text('error')}: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${t.text('error')}: $error')),
      ),
    );
  }
}

/// 未会計タブ
class _UnpaidTab extends ConsumerWidget {
  final String shopId;
  final Shop? shop;
  final FirebaseService firebaseService;
  final String? staffId;
  final String? staffName;

  const _UnpaidTab({
    required this.shopId,
    this.shop,
    required this.firebaseService,
    this.staffId,
    this.staffName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);

    return StreamBuilder<List<TableModel>>(
      stream: firebaseService.watchTables(shopId),
      builder: (context, tableSnapshot) {
        if (!tableSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<OrderModel>>(
          stream: firebaseService.watchOrdersByStatus(
            shopId,
            [OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.ready, OrderStatus.served],
          ),
          builder: (context, orderSnapshot) {
            if (!orderSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final tables = tableSnapshot.data!;
            final allActiveOrders = orderSnapshot.data!;

            final activeTableIds = allActiveOrders.map((o) => o.tableId).toSet();
            final activeTableNumbers = allActiveOrders.map((o) => o.tableNumber).toSet();

            final targetTables = tables.where((t) {
              final isOccupied = t.status == TableStatus.occupied;
              final hasOrders = activeTableIds.contains(t.id) || activeTableNumbers.contains(t.tableNumber.toString());
              return isOccupied || hasOrders;
            }).toList();

            if (targetTables.isEmpty) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isTablet = screenWidth > 600;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available, size: isTablet ? 80 : 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(t.text('noTablesWaitingForCheckout'), style: TextStyle(fontSize: isTablet ? 18 : 16, color: Colors.grey)),
                  ],
                ),
              );
            }

            final screenWidth = MediaQuery.of(context).size.width;
            final isTablet = screenWidth > 600;
            final shopAddress = shop != null
                ? '${shop!.prefecture}${shop!.city}${shop!.address}${shop!.building ?? ''}'
                : null;

            if (isTablet) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: screenWidth > 900 ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: screenWidth > 900 ? 2.2 : 2.0,
                ),
                itemCount: targetTables.length,
                itemBuilder: (context, index) {
                  final table = targetTables[index];
                  final tableOrders = allActiveOrders
                      .where((o) => o.tableId == table.id || o.tableNumber == table.tableNumber.toString())
                      .toList();

                  return _TableCard(
                    table: table,
                    tableOrders: tableOrders,
                    shopName: shop?.shopName,
                    firebaseService: firebaseService,
                    isTablet: true,
                    shopAddress: shopAddress,
                    shopPhone: shop?.phoneNumber,
                    receiptSettings: shop?.receiptSettings,
                    paymentMethods: shop?.paymentMethods ?? [],
                    staffId: staffId,
                    staffName: staffName,
                  );
                },
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: targetTables.length,
              itemBuilder: (context, index) {
                final table = targetTables[index];
                final tableOrders = allActiveOrders
                    .where((o) => o.tableId == table.id || o.tableNumber == table.tableNumber.toString())
                    .toList();

                return _TableCard(
                  table: table,
                  tableOrders: tableOrders,
                  shopName: shop?.shopName,
                  firebaseService: firebaseService,
                  shopAddress: shopAddress,
                  shopPhone: shop?.phoneNumber,
                  receiptSettings: shop?.receiptSettings,
                  paymentMethods: shop?.paymentMethods ?? [],
                  staffId: staffId,
                  staffName: staffName,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 直接会計タブ（メニューから選んで即座に会計）
class _DirectCheckoutTab extends ConsumerStatefulWidget {
  final String shopId;
  final Shop? shop;
  final FirebaseService firebaseService;
  final String? staffId;
  final String? staffName;

  const _DirectCheckoutTab({
    required this.shopId,
    this.shop,
    required this.firebaseService,
    this.staffId,
    this.staffName,
  });

  @override
  ConsumerState<_DirectCheckoutTab> createState() => _DirectCheckoutTabState();
}

class _DirectCheckoutTabState extends ConsumerState<_DirectCheckoutTab> {
  // 選択されたメニュー項目 {productId: {product: ProductData, quantity: int}}
  final Map<String, Map<String, dynamic>> _selectedItems = {};
  String? _selectedCategoryId;

  double get _totalAmount {
    double total = 0;
    for (var item in _selectedItems.values) {
      final effectivePrice = _getEffectivePrice(item['product'] as Map<String, dynamic>);
      final quantity = item['quantity'] as int? ?? 0;
      total += effectivePrice * quantity;
    }
    return total;
  }

  // 割引価格計算（商品データから）
  double _getEffectivePrice(Map<String, dynamic> productData) {
    final originalPrice = (productData['price'] as num?)?.toDouble() ?? 0;
    final discountSettings = productData['discountSettings'] as Map<String, dynamic>?;

    if (discountSettings == null || discountSettings['hasDiscount'] != true) {
      return originalPrice;
    }

    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    if (discountType == 'percent') {
      return (originalPrice * (1 - discountValue / 100));
    } else {
      return (originalPrice - discountValue).clamp(0, originalPrice);
    }
  }

  // 割引情報の取得
  Map<String, dynamic>? _getDiscountInfo(Map<String, dynamic> productData) {
    final discountSettings = productData['discountSettings'] as Map<String, dynamic>?;
    if (discountSettings == null || discountSettings['hasDiscount'] != true) {
      return null;
    }
    final originalPrice = (productData['price'] as num?)?.toDouble() ?? 0;
    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    String discountLabel;
    if (discountType == 'percent') {
      discountLabel = '${discountValue.toInt()}%OFF';
    } else {
      discountLabel = '¥${discountValue.toInt()}OFF';
    }

    return {
      'originalPrice': originalPrice,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountLabel': discountLabel,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('menuCategories')
          .where('shopId', isEqualTo: widget.shopId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .snapshots(),
      builder: (context, categorySnapshot) {
        // カテゴリがなくても続行（直接商品を取得）
        final categories = categorySnapshot.data?.docs ?? [];

        // まずproductsコレクションを確認
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('shopId', isEqualTo: widget.shopId)
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, productSnapshot) {
            // productsが空の場合、menusコレクションからも取得を試みる
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('menus')
                  .where('shopId', isEqualTo: widget.shopId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, menuSnapshot) {
                if (!productSnapshot.hasData && !menuSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // productsとmenusを統合（productsを優先、なければmenusを使用）
                final productDocs = productSnapshot.data?.docs ?? [];
                final menuDocs = menuSnapshot.data?.docs ?? [];

                // menusをproducts形式に変換して統合
                final List<QueryDocumentSnapshot> allProducts;
                if (productDocs.isNotEmpty) {
                  allProducts = productDocs;
                } else {
                  allProducts = menuDocs;
                }

            // カテゴリでフィルタリング
            final filteredProducts = _selectedCategoryId == null
                ? allProducts
                : allProducts.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['categoryId'] == _selectedCategoryId;
                  }).toList();

            return Column(
              children: [
                // カテゴリ選択チップ
                if (categories.isNotEmpty)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(t.text('all')),
                            selected: _selectedCategoryId == null,
                            onSelected: (_) => setState(() => _selectedCategoryId = null),
                          ),
                        ),
                        ...categories.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(data['name'] ?? ''),
                              selected: _selectedCategoryId == doc.id,
                              onSelected: (_) => setState(() => _selectedCategoryId = doc.id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // 商品グリッド
                Expanded(
                  child: filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(t.text('noProducts'), style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final doc = filteredProducts[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final productId = doc.id;
                            final quantity = _selectedItems[productId]?['quantity'] ?? 0;

                            return _ProductCard(
                              productId: productId,
                              productData: data,
                              quantity: quantity,
                              onAdd: () => _addItem(productId, data),
                              onRemove: () => _removeItem(productId),
                            );
                          },
                        ),
                ),

                // 合計金額と会計ボタン
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        // 選択アイテム数と合計
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${t.text('items')}: ${_selectedItems.values.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0))}${t.text('itemUnit')}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                '¥${_totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // クリアボタン
                        if (_selectedItems.isNotEmpty)
                          TextButton(
                            onPressed: _clearSelection,
                            child: Text(t.text('clear')),
                          ),
                        const SizedBox(width: 8),
                        // 会計ボタン
                        FilledButton.icon(
                          onPressed: _selectedItems.isEmpty ? null : _proceedToPayment,
                          icon: const Icon(Icons.payment),
                          label: Text(t.text('proceedToPayment')),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          },
        );
      },
    );
  }

  void _addItem(String productId, Map<String, dynamic> productData) {
    setState(() {
      if (_selectedItems.containsKey(productId)) {
        _selectedItems[productId]!['quantity'] = (_selectedItems[productId]!['quantity'] as int) + 1;
      } else {
        _selectedItems[productId] = {
          'product': productData,
          'quantity': 1,
        };
      }
    });
  }

  void _removeItem(String productId) {
    setState(() {
      if (_selectedItems.containsKey(productId)) {
        final currentQty = _selectedItems[productId]!['quantity'] as int;
        if (currentQty > 1) {
          _selectedItems[productId]!['quantity'] = currentQty - 1;
        } else {
          _selectedItems.remove(productId);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
    });
  }

  Future<void> _proceedToPayment() async {
    if (_selectedItems.isEmpty) return;

    final t = ref.read(translationProvider);

    // 注文アイテムを構築
    List<OrderItem> orderItems = [];
    double subtotal = 0;

    for (var entry in _selectedItems.entries) {
      final productId = entry.key;
      final productData = entry.value['product'] as Map<String, dynamic>;
      final quantity = entry.value['quantity'] as int;
      final effectivePrice = _getEffectivePrice(productData);
      final itemSubtotal = effectivePrice * quantity;
      final discountInfo = _getDiscountInfo(productData);

      orderItems.add(OrderItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_$productId',
        productId: productId,
        productName: productData['name'] ?? '',
        quantity: quantity,
        unitPrice: effectivePrice,
        subtotal: itemSubtotal,
        selectedOptions: [],
        discountInfo: discountInfo,
      ));

      subtotal += itemSubtotal;
    }

    final tax = (subtotal * 0.1).floorToDouble();
    final total = subtotal + tax;

    // ダミーの注文を作成（直接会計用）
    final directOrder = OrderModel(
      id: 'direct_${DateTime.now().millisecondsSinceEpoch}',
      shopId: widget.shopId,
      tableId: 'direct',
      tableNumber: t.text('directSale'),
      orderNumber: 'D-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      items: orderItems,
      subtotal: subtotal,
      tax: tax,
      total: total,
      status: OrderStatus.served,
      paymentStatus: PaymentStatus.unpaid,
      orderedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final shopAddress = widget.shop != null
        ? '${widget.shop!.prefecture ?? ''}${widget.shop!.city ?? ''}${widget.shop!.address ?? ''}${widget.shop!.building ?? ''}'
        : null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RegisterPaymentDialog(
        order: directOrder,
        shopName: widget.shop?.shopName,
        firebaseService: widget.firebaseService,
        shopAddress: shopAddress,
        shopPhone: widget.shop?.phoneNumber,
        receiptSettings: widget.shop?.receiptSettings,
        paymentMethods: widget.shop?.paymentMethods ?? [],
        staffId: widget.staffId,
        staffName: widget.staffName,
        isDirectCheckout: true, // 直接会計フラグ
      ),
    );

    if (result == true) {
      // 会計完了後、選択をクリア
      _clearSelection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('checkoutComplete')),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

/// 商品カード
class _ProductCard extends ConsumerWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.productId,
    required this.productData,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  /// 割引が有効かどうか
  bool get _hasDiscount {
    final discountSettings = productData['discountSettings'] as Map<String, dynamic>?;
    return discountSettings != null && discountSettings['hasDiscount'] == true;
  }

  /// 割引後の価格を取得
  double get _effectivePrice {
    final originalPrice = (productData['price'] as num?)?.toDouble() ?? 0;
    if (!_hasDiscount) return originalPrice;

    final discountSettings = productData['discountSettings'] as Map<String, dynamic>;
    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    if (discountType == 'percent') {
      return (originalPrice * (1 - discountValue / 100));
    } else {
      return (originalPrice - discountValue).clamp(0, originalPrice);
    }
  }

  /// 割引ラベルを取得
  String get _discountLabel {
    if (!_hasDiscount) return '';
    final discountSettings = productData['discountSettings'] as Map<String, dynamic>;
    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    if (discountType == 'percent') {
      return '${discountValue.toStringAsFixed(0)}%OFF';
    } else {
      return '¥${discountValue.toStringAsFixed(0)}引';
    }
  }

  /// タグリストを取得
  List<String> _getTags(AppTranslations t) {
    final tags = productData['tags'] as Map<String, dynamic>?;
    if (tags == null) return [];

    final List<String> result = [];
    if (tags['isNew'] == true) result.add(t.text('tagNew'));
    if (tags['isRecommended'] == true) result.add(t.text('tagRecommended'));
    if (tags['isPopular'] == true) result.add(t.text('tagPopular'));
    if (tags['isLimitedTime'] == true) result.add(t.text('tagLimited'));
    if (tags['isLimitedQuantity'] == true) result.add(t.text('tagLimited'));
    if (tags['isOrganic'] == true) result.add(t.text('tagVegetarian'));
    if (tags['isSpicy'] == true) result.add(t.text('tagSpicy'));
    if (tags['isVegetarian'] == true) result.add(t.text('tagVegetarian'));
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    final name = productData['name'] ?? '';
    final originalPrice = (productData['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = productData['imageUrl'] as String?;
    final hasDiscount = _hasDiscount;
    final effectivePrice = _effectivePrice;
    final tags = _getTags(t);

    return Card(
      elevation: quantity > 0 ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: quantity > 0
            ? BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 商品画像
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400]),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.restaurant, size: 40, color: Colors.grey[400]),
                          ),
                  ),
                ),
                // 商品名と価格
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // タグ表示
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: tags.take(2).map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: _getTagColor(tag),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )).toList(),
                          ),
                        if (tags.isNotEmpty) const SizedBox(height: 2),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: tags.isNotEmpty ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // 価格表示（割引対応）
                        if (hasDiscount) ...[
                          Row(
                            children: [
                              Text(
                                '¥${originalPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _discountLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '¥${effectivePrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ] else
                          Text(
                            '¥${originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 数量バッジ
            if (quantity > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onRemove,
                        child: const Icon(Icons.remove, color: Colors.white, size: 16),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onAdd,
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case '新商品':
        return Colors.green;
      case 'おすすめ':
        return Colors.blue;
      case '人気':
        return Colors.orange;
      case '期間限定':
        return Colors.purple;
      case '数量限定':
        return Colors.red;
      case 'オーガニック':
        return Colors.teal;
      case '辛い':
        return Colors.deepOrange;
      case 'ベジ':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }
}

/// 本日会計済みタブ
class _CompletedTodayTab extends ConsumerWidget {
  final String shopId;
  final Shop? shop;
  final FirebaseService firebaseService;
  final String? staffId;
  final String? staffName;

  const _CompletedTodayTab({
    required this.shopId,
    this.shop,
    required this.firebaseService,
    this.staffId,
    this.staffName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);

    // 本日の開始時刻（0:00）
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(t.text('noCompletedOrdersToday'), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs.map((doc) {
          return OrderModel.fromFirestore(doc);
        }).toList();

        final shopAddress = shop != null
            ? '${shop!.prefecture}${shop!.city}${shop!.address}${shop!.building ?? ''}'
            : null;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _CompletedOrderCard(
              order: order,
              shop: shop,
              shopAddress: shopAddress,
              firebaseService: firebaseService,
              staffId: staffId,
              staffName: staffName,
            );
          },
        );
      },
    );
  }
}

/// 会計済み注文カード
class _CompletedOrderCard extends ConsumerWidget {
  final OrderModel order;
  final Shop? shop;
  final String? shopAddress;
  final FirebaseService firebaseService;
  final String? staffId;
  final String? staffName;

  const _CompletedOrderCard({
    required this.order,
    this.shop,
    this.shopAddress,
    required this.firebaseService,
    this.staffId,
    this.staffName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    final dateFormatter = DateFormat('HH:mm');
    final printerService = UnifiedPrinterService();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(Icons.check_circle, color: Colors.green.shade700),
        ),
        title: Row(
          children: [
            Text(
              '${t.text('table')} ${order.tableNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                order.paymentMethod ?? t.text('unknown'),
                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${dateFormatter.format(order.completedAt ?? order.updatedAt)} - ¥${order.total.toInt()}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 注文内容
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.productName} x${item.quantity}'),
                      Text('¥${item.subtotal.toInt()}'),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.text('total'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('¥${order.total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                // アクションボタン
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reprintReceipt(context, printerService, t),
                        icon: const Icon(Icons.print, size: 18),
                        label: Text(t.text('reprintReceipt')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _changePaymentMethod(context, ref, t),
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: Text(t.text('changePayment')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _redoCheckout(context, ref, t),
                    icon: const Icon(Icons.refresh),
                    label: Text(t.text('redoCheckout')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// レシート再印刷
  Future<void> _reprintReceipt(BuildContext context, UnifiedPrinterService printerService, AppTranslations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.text('reprintReceipt')),
        content: Text(t.text('confirmReprintReceipt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.text('print')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await printerService.printPaymentReceipt(
        order: order,
        shopName: shop?.shopName,
        shopAddress: shopAddress,
        shopPhone: shop?.phoneNumber,
        receiptSettings: shop?.receiptSettings,
        grandTotal: order.total,
        paymentMethod: order.paymentMethod ?? 'Unknown',
        receivedAmount: order.receivedAmount,
        changeAmount: order.changeAmount,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? t.text('printSuccess') : t.text('printFailed')),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.text('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 支払い方法変更
  Future<void> _changePaymentMethod(BuildContext context, WidgetRef ref, AppTranslations t) async {
    final paymentMethods = shop?.paymentMethods ?? [];

    if (paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('noPaymentMethodsConfigured')), backgroundColor: Colors.orange),
      );
      return;
    }

    String? selectedMethod = order.paymentMethod;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(t.text('changePaymentMethod')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${t.text('currentPaymentMethod')}: ${order.paymentMethod ?? t.text('unknown')}'),
              const SizedBox(height: 16),
              ...paymentMethods.where((pm) => pm.isActive).map((pm) => RadioListTile<String>(
                title: Text(pm.name),
                value: pm.name,
                groupValue: selectedMethod,
                onChanged: (value) => setDialogState(() => selectedMethod = value),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(t.text('cancel')),
            ),
            ElevatedButton(
              onPressed: selectedMethod != null && selectedMethod != order.paymentMethod
                  ? () => Navigator.pop(ctx, selectedMethod)
                  : null,
              child: Text(t.text('change')),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'paymentMethod': result,
        'paymentMethodChangedAt': FieldValue.serverTimestamp(),
        'paymentMethodChangedBy': staffId,
        'paymentMethodChangedByName': staffName,
        'previousPaymentMethod': order.paymentMethod,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.text('paymentMethodChanged')}: $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.text('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 会計やり直し
  Future<void> _redoCheckout(BuildContext context, WidgetRef ref, AppTranslations t) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.text('redoCheckout')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.text('confirmRedoCheckout')),
            const SizedBox(height: 8),
            Text(
              '${t.text('table')} ${order.tableNumber} - ¥${order.total.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: t.text('reason'),
                hintText: t.text('enterRedoReason'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              t.text('redoCheckoutWarning'),
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.text('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(t.text('enterReason')), backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(t.text('redoCheckout')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // 会計やり直し履歴を保存
      await FirebaseFirestore.instance.collection('checkoutRedos').add({
        'orderId': order.id,
        'shopId': order.shopId,
        'tableNumber': order.tableNumber,
        'originalTotal': order.total,
        'originalPaymentMethod': order.paymentMethod,
        'originalCompletedAt': order.completedAt != null ? Timestamp.fromDate(order.completedAt!) : null,
        'reason': reasonController.text.trim(),
        'redoneAt': FieldValue.serverTimestamp(),
        'redoneBy': staffId,
        'redoneByName': staffName ?? 'スタッフ',
      });

      // 注文ステータスを served に戻す
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'status': 'served',
        'paymentStatus': 'unpaid',
        'paymentMethod': FieldValue.delete(),
        'receivedAmount': FieldValue.delete(),
        'changeAmount': FieldValue.delete(),
        'completedAt': FieldValue.delete(),
        'checkoutRedoReason': reasonController.text.trim(),
        'checkoutRedoAt': FieldValue.serverTimestamp(),
        'checkoutRedoBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.text('checkoutRedone')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.text('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _TableCard extends ConsumerStatefulWidget {
  final TableModel table;
  final List<OrderModel> tableOrders; // 親から受け取る
  final String? shopName;
  final FirebaseService firebaseService;
  final bool isTablet;
  // レシート印刷用の店舗情報
  final String? shopAddress;
  final String? shopPhone;
  final Map<String, dynamic>? receiptSettings;
  // 支払い方法マスタ
  final List<PaymentMethodSetting> paymentMethods;
  // 担当スタッフ情報
  final String? staffId;
  final String? staffName;

  const _TableCard({
    required this.table,
    required this.tableOrders,
    this.shopName,
    required this.firebaseService,
    this.isTablet = false,
    this.shopAddress,
    this.shopPhone,
    this.receiptSettings,
    this.paymentMethods = const [],
    this.staffId,
    this.staffName,
  });

  @override
  ConsumerState<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends ConsumerState<_TableCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationProvider);
    final isTablet = widget.isTablet;
    final titleFontSize = isTablet ? 20.0 : 18.0;
    final subtitleFontSize = isTablet ? 16.0 : 14.0;
    final avatarRadius = isTablet ? 28.0 : 20.0;

    // 注文がない場合は表示しない（または空席表示）
    if (widget.tableOrders.isEmpty && widget.table.status != TableStatus.occupied) {
      return const SizedBox.shrink();
    }

    final totalAmount = widget.tableOrders.fold<double>(0, (sum, order) => sum + order.totalAmount);

    return Card(
      margin: EdgeInsets.only(bottom: isTablet ? 0 : 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            contentPadding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16, vertical: isTablet ? 12 : 8),
            leading: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.table_restaurant, color: Colors.orange, size: isTablet ? 28 : 24),
            ),
            title: Text(
              '${t.text('table')} ${widget.table.tableNumber}',
              style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${t.text('orderCount')}: ${widget.tableOrders.length}\n${t.text('total')}: ¥${totalAmount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, height: 1.5, fontSize: subtitleFontSize),
            ),
            trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: isTablet ? 28 : 24),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            // 注文詳細リスト
            Container(
              color: Colors.grey.shade50,
              child: Column(
                children: widget.tableOrders.map((order) => _OrderSummary(
                  order: order,
                  onCancelItem: (itemIndex) => _cancelOrderItem(order, itemIndex),
                )).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openPaymentDialog(context),
                  icon: const Icon(Icons.payment),
                  label: Text(t.text('proceedToPayment')),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  AppTranslations get _t => ref.read(translationProvider);

  /// 個別商品のキャンセル処理（理由入力と履歴保存付き）
  Future<void> _cancelOrderItem(OrderModel order, int itemIndex) async {
    final item = order.items[itemIndex];

    // キャンセル理由ダイアログを表示
    final reasonController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_t.text('cancelItem')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '「${item.productName}」(¥${item.subtotal.toInt()}) ${_t.text('cancelItemConfirm')}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(_t.text('selectCancelReason')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildReasonChip(_t.text('customerRequest'), selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip(_t.text('outOfStock'), selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip(_t.text('orderMistake'), selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                  _buildReasonChip(_t.text('orderChange'), selectedReason, (reason) {
                    setDialogState(() => selectedReason = reason);
                    reasonController.text = reason;
                  }),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: _t.text('otherReason'),
                  hintText: _t.text('enterDetails'),
                  border: const OutlineInputBorder(),
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
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(_t.text('keepIt')),
            ),
            ElevatedButton(
              onPressed: reasonController.text.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, {'reason': reasonController.text}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(_t.text('executeCancel')),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    // スタッフ情報を取得
    final staffUser = ref.read(staffUserProvider).value;

    try {
      // アイテムキャンセル履歴を保存（監査用）
      await FirebaseFirestore.instance.collection('itemCancellations').add({
        'orderId': order.id,
        'shopId': order.shopId,
        'tableId': order.tableId,
        'tableNumber': order.tableNumber,
        'productId': item.productId,
        'productName': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'subtotal': item.subtotal,
        'selectedOptions': item.selectedOptions.map((opt) => opt.toFirestore()).toList(),
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': staffUser?.id,
        'cancelledByName': staffUser?.name ?? '不明',
        'reason': result['reason'] ?? '理由未入力',
      });

      // 新しいアイテムリストを作成（対象を除外）
      final newItems = [...order.items];
      newItems.removeAt(itemIndex);

      if (newItems.isEmpty) {
        // 商品が0になったら注文自体をキャンセル（履歴も保存）
        await FirebaseFirestore.instance.collection('orderCancellations').add({
          'orderId': order.id,
          'shopId': order.shopId,
          'tableId': order.tableId,
          'tableNumber': order.tableNumber,
          'items': order.items.map((i) => i.toFirestore()).toList(),
          'subtotal': order.subtotal,
          'tax': order.tax,
          'total': order.total,
          'originalOrderedAt': Timestamp.fromDate(order.orderedAt),
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': staffUser?.id,
          'cancelledByName': staffUser?.name ?? '不明',
          'reason': '全商品キャンセル（${result['reason']}）',
        });

        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': staffUser?.id,
          'cancelReason': '全商品キャンセル（${result['reason']}）',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 再計算
        double newSubtotal = 0;
        for (var i in newItems) newSubtotal += i.subtotal;
        double newTax = (newSubtotal * 0.1).floorToDouble();
        double newTotal = newSubtotal + newTax;

        // 更新
        await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
          'items': newItems.map((i) => i.toFirestore()).toList(),
          'subtotal': newSubtotal,
          'tax': newTax,
          'total': newTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${item.productName}」${_t.text('itemCancelled')}${result['reason']}）'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Cancel Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t.text('errorOccurred')}: $e'), backgroundColor: Colors.red),
        );
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

  Future<void> _openPaymentDialog(BuildContext context) async {
    if (widget.tableOrders.isEmpty) return;

    // 合算用ダミーオーダー作成（全注文のアイテムを合算）
    double totalSubtotal = 0;
    double totalTax = 0;
    List<OrderItem> allItems = [];

    for (var o in widget.tableOrders) {
      totalSubtotal += o.subtotal;
      totalTax += o.tax;
      allItems.addAll(o.items);
    }

    final summaryOrder = OrderModel(
      id: widget.tableOrders.first.id,
      shopId: widget.tableOrders.first.shopId,
      tableId: widget.tableOrders.first.tableId,
      tableNumber: widget.tableOrders.first.tableNumber,
      orderNumber: 'Merged-${widget.tableOrders.length}',
      items: allItems, // 全注文のアイテムを含める
      subtotal: totalSubtotal,
      tax: totalTax,
      total: totalSubtotal + totalTax,
      status: OrderStatus.served,
      paymentStatus: PaymentStatus.unpaid,
      orderedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RegisterPaymentDialog(
        order: summaryOrder,
        shopName: widget.shopName,
        firebaseService: widget.firebaseService,
        shopAddress: widget.shopAddress,
        shopPhone: widget.shopPhone,
        receiptSettings: widget.receiptSettings,
        paymentMethods: widget.paymentMethods,
        staffId: widget.staffId,
        staffName: widget.staffName,
      ),
    );

    if (result == true) {
      for (var order in widget.tableOrders) {
        await widget.firebaseService.updateOrderStatus(order.id, OrderStatus.completed);
      }
      // テーブルを空席に戻す
      await widget.firebaseService.updateTableStatus(widget.table.id, TableStatus.available);
    }
  }
}

/// 注文内容の簡易表示ウィジェット（削除ボタン付き）
class _OrderSummary extends ConsumerWidget {
  final OrderModel order;
  final Function(int) onCancelItem;

  const _OrderSummary({
    required this.order,
    required this.onCancelItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t.text('order')} #${order.orderNumber ?? order.id.substring(0, 4)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${order.orderedAt.hour.toString().padLeft(2, '0')}:${order.orderedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...order.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(left: 0, top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 削除ボタン (ゴミ箱アイコン)
                  InkWell(
                    onTap: () => onCancelItem(index),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0, top: 2.0),
                      child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.productName} x${item.quantity}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (item.selectedOptions.isNotEmpty)
                          ...item.selectedOptions.map((opt) => Text(
                                ' - ${opt.optionName}: ${opt.choiceName}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              )).toList(),
                      ],
                    ),
                  ),
                  Text(
                    '¥${item.subtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${t.text('subtotal')}: ¥${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}