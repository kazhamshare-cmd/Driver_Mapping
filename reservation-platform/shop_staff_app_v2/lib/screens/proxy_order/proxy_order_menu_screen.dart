import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/localized_text_helper.dart';

/// 代理注文用メニュー画面
class ProxyOrderMenuScreen extends ConsumerStatefulWidget {
  final String tableId;

  const ProxyOrderMenuScreen({
    super.key,
    required this.tableId,
  });

  @override
  ConsumerState<ProxyOrderMenuScreen> createState() => _ProxyOrderMenuScreenState();
}

class _ProxyOrderMenuScreenState extends ConsumerState<ProxyOrderMenuScreen> {
  // カート内商品: {商品ID: 数量}
  final Map<String, int> _cart = {};
  // 商品情報キャッシュ: {商品ID: 商品データ}
  final Map<String, Map<String, dynamic>> _productDataCache = {};
  
  bool _isSubmitting = false;
  String? _selectedCategoryId;

  // 合計金額計算（割引価格を適用）
  int get _totalAmount {
    int total = 0;
    _cart.forEach((productId, quantity) {
      final product = _productDataCache[productId];
      if (product != null) {
        final effectivePrice = _getEffectivePrice(product);
        total += effectivePrice * quantity;
      }
    });
    return total;
  }

  // 実効価格を取得（割引適用後）
  int _getEffectivePrice(Map<String, dynamic> product) {
    final originalPrice = (product['price'] as num?)?.toInt() ?? 0;
    final discountSettings = product['discountSettings'] as Map<String, dynamic>?;

    if (discountSettings == null || discountSettings['hasDiscount'] != true) {
      return originalPrice;
    }

    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    if (discountType == 'percent') {
      return (originalPrice * (1 - discountValue / 100)).round();
    } else {
      return (originalPrice - discountValue).clamp(0, originalPrice).toInt();
    }
  }

  // 割引が有効かどうか
  bool _hasActiveDiscount(Map<String, dynamic> product) {
    final discountSettings = product['discountSettings'] as Map<String, dynamic>?;
    return discountSettings != null && discountSettings['hasDiscount'] == true;
  }

  // 割引ラベルを取得
  String _getDiscountLabel(Map<String, dynamic> product) {
    final discountSettings = product['discountSettings'] as Map<String, dynamic>?;
    if (discountSettings == null || discountSettings['hasDiscount'] != true) {
      return '';
    }

    final discountType = discountSettings['discountType'] as String? ?? 'amount';
    final discountValue = (discountSettings['discountValue'] as num?)?.toDouble() ?? 0;

    if (discountType == 'percent') {
      return '${discountValue.toInt()}%OFF';
    } else {
      return '¥${discountValue.toInt()}OFF';
    }
  }

  // タグリストを取得
  List<Map<String, dynamic>> _getProductTags(Map<String, dynamic> product) {
    final tags = product['tags'] as Map<String, dynamic>?;
    if (tags == null) return [];

    final tagList = <Map<String, dynamic>>[];
    if (tags['isNew'] == true) tagList.add({'label': '新商品', 'color': const Color(0xFFFF6B6B)});
    if (tags['isRecommended'] == true) tagList.add({'label': 'おすすめ', 'color': const Color(0xFF4ECDC4)});
    if (tags['isPopular'] == true) tagList.add({'label': '大人気', 'color': const Color(0xFFFFE66D)});
    if (tags['isLimitedTime'] == true) tagList.add({'label': '期間限定', 'color': const Color(0xFFFF8E53)});
    if (tags['isLimitedQty'] == true) tagList.add({'label': '数量限定', 'color': const Color(0xFFA855F7)});
    if (tags['isOrganic'] == true) tagList.add({'label': 'オーガニック', 'color': const Color(0xFF22C55E)});
    if (tags['isSpicy'] == true) tagList.add({'label': '辛い', 'color': const Color(0xFFEF4444)});
    if (tags['isVegetarian'] == true) tagList.add({'label': 'ベジタリアン', 'color': const Color(0xFF10B981)});
    return tagList;
  }

  // タグを表示するウィジェット
  Widget _buildTagsRow(List<Map<String, dynamic>> tags) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: tags.map((tag) {
        final color = tag['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 0.5),
          ),
          child: Text(
            tag['label'] as String,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 価格表示ウィジェット（割引対応）
  Widget _buildPriceDisplay(Map<String, dynamic> product, {bool isSoldOut = false}) {
    final originalPrice = (product['price'] as num?)?.toInt() ?? 0;
    final effectivePrice = _getEffectivePrice(product);
    final hasDiscount = _hasActiveDiscount(product);

    if (!hasDiscount || isSoldOut) {
      return Text(
        '¥$originalPrice',
        style: TextStyle(
          fontSize: 14,
          color: isSoldOut ? Colors.grey.shade400 : Colors.grey,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '¥$originalPrice',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '¥$effectivePrice',
          style: TextStyle(
            fontSize: 14,
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            _getDiscountLabel(product),
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 商品画像を構築
  Widget _buildProductImage(String? imageUrl, {double size = 56}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.5),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    // 画像がない場合のプレースホルダー
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final t = ref.watch(translationProvider);
    final locale = ref.watch(localeProvider);
    final langCode = locale.languageCode;

    return staffUserAsync.when(
      data: (staffUser) {
        if (staffUser == null) return Scaffold(body: Center(child: Text(t.text('userInfoNotFound'))));

        // 出勤中でなければ利用不可
        if (!staffUser.isWorking) {
          return Scaffold(
            appBar: AppBar(
              title: Text(t.text('proxyOrder')),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/home'),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    t.text('clockInRequired'),
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/clock-in'),
                    icon: const Icon(Icons.login),
                    label: Text(t.text('clockInButton')),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go('/');
              },
            ),
            title: Text(t.text('selectMenu')),
            actions: [
              if (_cart.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      '¥${_totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // タブレット判定
              Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isTablet = screenWidth > 600;
                  final categoryHeight = isTablet ? 60.0 : 50.0;

              // カテゴリタブ (Firestoreから取得)
              return SizedBox(
                height: categoryHeight,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('productCategories')
                      .where('shopId', isEqualTo: staffUser.shopId)
                      .orderBy('sortOrder')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final categories = snapshot.data!.docs;
                    
                    if (_selectedCategoryId == null && categories.isNotEmpty) {
                      // 初期選択
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedCategoryId = categories.first.id;
                        });
                      });
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index].data() as Map<String, dynamic>;
                        final catId = categories[index].id;
                        final isSelected = catId == _selectedCategoryId;
                        final categoryName = LocalizedTextHelper.getCategoryName(cat, langCode);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: ChoiceChip(
                            label: Text(categoryName.isNotEmpty ? categoryName : t.text('category')),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategoryId = catId);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              );
                },
              ),

              // 商品リスト
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isTablet = screenWidth > 600;

                    return _selectedCategoryId == null
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .where('shopId', isEqualTo: staffUser.shopId)
                            .where('categoryId', isEqualTo: _selectedCategoryId)
                            .where('isActive', isEqualTo: true)
                            .orderBy('sortOrder')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Center(child: Text('${t.text('error')}: ${snapshot.error}'));
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                          final products = snapshot.data!.docs;

                          if (products.isEmpty) {
                            return Center(child: Text(t.text('noProductsAvailable')));
                          }

                          // タブレットの場合はGridView
                          if (isTablet) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: screenWidth > 900 ? 3 : 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 2.2,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index].data() as Map<String, dynamic>;
                                final productId = products[index].id;
                                _productDataCache[productId] = product;
                                final quantity = _cart[productId] ?? 0;
                                final productName = LocalizedTextHelper.getProductName(product, langCode);
                                final imageUrl = product['imageUrl'] as String?;
                                // 売り切れ判定
                                final displayStatus = product['displayStatus'] as String?;
                                final isSoldOut = displayStatus == 'soldout';
                                // タグ取得
                                final tags = _getProductTags(product);

                                return Card(
                                  color: isSoldOut ? Colors.grey.shade200 : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            Opacity(
                                              opacity: isSoldOut ? 0.5 : 1.0,
                                              child: _buildProductImage(imageUrl, size: 64),
                                            ),
                                            if (isSoldOut)
                                              Positioned.fill(
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.shade700,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      t.text('soldOut'),
                                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // タグ表示
                                              if (tags.isNotEmpty && !isSoldOut) ...[
                                                _buildTagsRow(tags),
                                                const SizedBox(height: 4),
                                              ],
                                              Text(
                                                productName.isNotEmpty ? productName : t.text('productName'),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: isSoldOut ? Colors.grey : null,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              _buildPriceDisplay(product, isSoldOut: isSoldOut),
                                            ],
                                          ),
                                        ),
                                        if (isSoldOut)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(t.text('soldOut'), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                          )
                                        else
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 28),
                                                onPressed: quantity > 0
                                                    ? () => setState(() {
                                                          if (quantity == 1) {
                                                            _cart.remove(productId);
                                                          } else {
                                                            _cart[productId] = quantity - 1;
                                                          }
                                                        })
                                                    : null,
                                              ),
                                              Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.orange, size: 28),
                                                onPressed: () => setState(() {
                                                  _cart[productId] = quantity + 1;
                                                }),
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

                          // スマートフォンの場合はListView
                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index].data() as Map<String, dynamic>;
                              final productId = products[index].id;

                              // キャッシュに保存（計算用）
                              _productDataCache[productId] = product;

                              final quantity = _cart[productId] ?? 0;
                              final productName = LocalizedTextHelper.getProductName(product, langCode);
                              final imageUrl = product['imageUrl'] as String?;
                              // 売り切れ判定
                              final displayStatus = product['displayStatus'] as String?;
                              final isSoldOut = displayStatus == 'soldout';
                              // タグ取得
                              final tags = _getProductTags(product);

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: isSoldOut ? Colors.grey.shade200 : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          Opacity(
                                            opacity: isSoldOut ? 0.5 : 1.0,
                                            child: _buildProductImage(imageUrl),
                                          ),
                                          if (isSoldOut)
                                            Positioned.fill(
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade700,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    t.text('soldOut'),
                                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // タグ表示
                                            if (tags.isNotEmpty && !isSoldOut) ...[
                                              _buildTagsRow(tags),
                                              const SizedBox(height: 4),
                                            ],
                                            Text(
                                              productName.isNotEmpty ? productName : t.text('productName'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSoldOut ? Colors.grey : null,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildPriceDisplay(product, isSoldOut: isSoldOut),
                                          ],
                                        ),
                                      ),
                                      isSoldOut
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(t.text('soldOut'), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline),
                                                  onPressed: quantity > 0
                                                      ? () => setState(() {
                                                            if (quantity == 1) {
                                                              _cart.remove(productId);
                                                            } else {
                                                              _cart[productId] = quantity - 1;
                                                            }
                                                          })
                                                      : null,
                                                ),
                                                Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
                                                  onPressed: () => setState(() {
                                                    _cart[productId] = quantity + 1;
                                                  }),
                                                ),
                                              ],
                                            ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: _cart.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: _isSubmitting ? null : () => _submitOrder(staffUser.shopId),
                  label: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Text('${t.text('placeOrder')} (${_cart.length})'),
                  icon: const Icon(Icons.check),
                )
              : null,
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('${t.text('error')}: $e'))),
    );
  }

  Future<void> _submitOrder(String shopId) async {
    setState(() => _isSubmitting = true);

    // スタッフ情報を取得
    final staffUser = ref.read(staffUserProvider).value;

    try {
      // テーブル情報の取得
      final tableDoc = await FirebaseFirestore.instance.collection('tables').doc(widget.tableId).get();
      final tableData = tableDoc.data();
      final tableNumber = tableData?['tableNumber'] ?? '不明';

      // 注文アイテムの構築（割引価格を適用）
      final List<Map<String, dynamic>> orderItems = [];

      _cart.forEach((productId, quantity) {
        final product = _productDataCache[productId];
        if (product != null) {
          final originalPrice = (product['price'] as num?)?.toInt() ?? 0;
          final effectivePrice = _getEffectivePrice(product);
          final hasDiscount = _hasActiveDiscount(product);

          orderItems.add({
            'productId': productId,
            'categoryId': product['categoryId'],  // カテゴリID（キッチン担当別フィルター用）
            'productName': product['name'],
            'productNameEn': product['nameEn'], // Null安全対応
            'productNameTh': product['nameTh'], // タイ語対応
            'quantity': quantity,
            'unitPrice': effectivePrice, // 割引後の単価
            'originalPrice': originalPrice, // 元の価格（参照用）
            'price': effectivePrice,
            'subtotal': effectivePrice * quantity,
            'selectedOptions': [], // 今回は簡易版のためオプションなし
            'status': 'pending',
            'notes': '',
            // 割引情報を保存（参照用）
            if (hasDiscount) 'discountInfo': {
              'originalPrice': originalPrice,
              'discountType': product['discountSettings']?['discountType'],
              'discountValue': product['discountSettings']?['discountValue'],
              'discountLabel': _getDiscountLabel(product),
            },
          });
        }
      });

      // 注文データの作成（スタッフ情報を含む）
      final now = Timestamp.now();
      final orderData = {
        'shopId': shopId,
        'tableId': widget.tableId,
        'tableNumber': tableNumber,
        'items': orderItems,
        'total': _totalAmount,
        'subtotal': _totalAmount,
        'tax': 0, // 簡易計算
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'orderedBy': {
          'isStaffOrder': true,
          'userId': staffUser?.id ?? 'staff',
          'staffId': staffUser?.id,
          'staffName': staffUser?.name ?? '不明なスタッフ',
        },
        'createdAt': now,
        'updatedAt': now,
        'orderedAt': now, // ★重要：これがないとスタッフアプリで通知が鳴りません
      };

      final orderRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
      final newOrderId = orderRef.id;

      // テーブルのステータスを「使用中」に更新
      debugPrint('代理注文: テーブルID=${widget.tableId}を使用中に更新します');
      await FirebaseFirestore.instance.collection('tables').doc(widget.tableId).update({
        'status': 'occupied',
        'sessionStartedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      debugPrint('代理注文: テーブルステータス更新完了');

      if (mounted) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.text('orderPlaced')), backgroundColor: Colors.green),
        );
        // 注文管理画面に戻る（新規注文IDを渡して通知を鳴らす）
        context.go('/orders?newOrderId=$newOrderId');
      }
    } catch (e) {
      if (mounted) {
        final t = ref.read(translationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.text('orderFailed')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}