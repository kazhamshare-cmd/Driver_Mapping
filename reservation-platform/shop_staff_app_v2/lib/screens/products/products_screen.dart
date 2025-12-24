import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/csv_import_service.dart';
import 'product_edit_screen.dart';
import 'product_categories_screen.dart';
import 'product_options_screen.dart';
// Note: canManageProductsProvider is not used - canManage is computed directly from staffUser

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _selectedCategoryId;
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);
    final t = ref.watch(translationProvider);
    final langCode = ref.watch(localeProvider).languageCode;

    return staffUserAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('${t.text('errorOccurred')}: $error')),
      ),
      data: (staffUser) {
        if (staffUser == null) {
          return Scaffold(
            body: Center(child: Text(t.text('pleaseLogin'))),
          );
        }

        // staffUserから直接権限を計算（タイミング問題を回避）
        final canManage = staffUser.role == 'owner' || staffUser.role == 'manager';

        final categoriesAsync = ref.watch(productCategoriesProvider(staffUser.shopId));
        final productsAsync = _selectedCategoryId == null
            ? ref.watch(productsProvider(staffUser.shopId))
            : ref.watch(productsByCategoryProvider((shopId: staffUser.shopId, categoryId: _selectedCategoryId!)));

        // デバッグ: 権限確認
        debugPrint('ProductsScreen - User role: ${staffUser.role}, canManage: $canManage');

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
            title: Text(t.text('productManagement')),
            actions: [
              if (canManage) ...[
                // 並び替えモードトグル
                IconButton(
                  icon: Icon(_isReorderMode ? Icons.check : Icons.swap_vert),
                  tooltip: _isReorderMode ? t.text('done') : t.text('reorder'),
                  onPressed: () {
                    setState(() {
                      _isReorderMode = !_isReorderMode;
                    });
                    if (!_isReorderMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.text('reorderComplete')),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
                // CSVインポート/エクスポート
                PopupMenuButton<String>(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'CSV一括操作',
                  onSelected: (value) async {
                    if (value == 'import') {
                      await _importCsv(context, staffUser.shopId, t);
                    } else if (value == 'template') {
                      await _downloadTemplate(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.upload_file, size: 20),
                          SizedBox(width: 12),
                          Text('CSVから一括登録'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'template',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 20),
                          SizedBox(width: 12),
                          Text('CSVテンプレートをダウンロード'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.category),
                  tooltip: t.text('categoryManagement'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductCategoriesScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: t.text('optionManagement'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductOptionsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              // カテゴリーフィルター
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('${t.text('errorOccurred')}: $error'),
                ),
                data: (categories) {
                  if (categories.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.text('pleaseCreateCategoryFirst'),
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                          if (canManage)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProductCategoriesScreen(),
                                  ),
                                );
                              },
                              child: Text(t.text('createCategory')),
                            ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(t.text('all')),
                            selected: _selectedCategoryId == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = null;
                              });
                            },
                          ),
                        ),
                        ...categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.getLocalizedName(langCode)),
                              selected: _selectedCategoryId == category.id,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = selected ? category.id : null;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // 商品リスト
              Expanded(
                child: productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text('${t.text('errorOccurred')}: $error'),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              t.text('noProducts'),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (!canManage) ...[
                              const SizedBox(height: 8),
                              Text(
                                t.text('onlyManagerCanAddProducts'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    // 並び替えモードの場合はReorderableListViewを使用
                    if (_isReorderMode) {
                      return ReorderableListView.builder(
                        itemCount: products.length,
                        onReorder: (oldIndex, newIndex) async {
                          try {
                            final reorder = ref.read(reorderProductsProvider);
                            await reorder(products, oldIndex, newIndex);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${t.text('errorOccurred')}: $e')),
                              );
                            }
                          }
                        },
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildReorderableProductCard(
                            key: ValueKey(product.id),
                            context: context,
                            product: product,
                            t: t,
                            langCode: langCode,
                          );
                        },
                      );
                    }

                    return ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductCard(context, product, canManage, t, langCode);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductEditScreen(
                          shopId: staffUser.shopId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(t.text('addProduct')),
                )
              : null,
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, bool canManage, AppTranslations t, String langCode) {
    final toggleSoldOut = ref.read(toggleProductSoldOutProvider);
    final localizedDescription = product.getLocalizedDescription(langCode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: canManage
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductEditScreen(
                      product: product,
                      shopId: product.shopId,
                    ),
                  ),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 商品画像
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: product.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imageUrl == null
                    ? Icon(Icons.image, size: 40, color: Colors.grey[400])
                    : null,
              ),

              const SizedBox(width: 12),

              // 商品情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.getLocalizedName(langCode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${product.price.toInt()}',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (localizedDescription != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        localizedDescription,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 売り切れトグル
              Column(
                children: [
                  Switch(
                    value: !product.isSoldOut,
                    onChanged: (value) async {
                      try {
                        await toggleSoldOut(product.id, !value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? t.text('changedToOnSale') : t.text('changedToSoldOut'),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${t.text('errorOccurred')}: $e')),
                          );
                        }
                      }
                    },
                  ),
                  Text(
                    product.isSoldOut ? t.text('soldOut') : t.text('onSale'),
                    style: TextStyle(
                      fontSize: 12,
                      color: product.isSoldOut ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 並び替えモード用の商品カード
  Widget _buildReorderableProductCard({
    required Key key,
    required BuildContext context,
    required Product product,
    required AppTranslations t,
    required String langCode,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            image: product.imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(product.imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: product.imageUrl == null
              ? Icon(Icons.image, size: 24, color: Colors.grey[400])
              : null,
        ),
        title: Text(
          product.getLocalizedName(langCode),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('¥${product.price.toInt()}'),
        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
      ),
    );
  }

  /// CSVからインポート
  Future<void> _importCsv(BuildContext context, String shopId, AppTranslations t) async {
    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSVインポート'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CSVファイルから商品を一括登録します。'),
            SizedBox(height: 12),
            Text(
              '注意:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• 既存の商品は上書きされません'),
            Text('• 必須項目: 商品名'),
            Text('• 推奨項目: 価格、カテゴリ'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ファイルを選択'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // CSVインポート実行
    final service = CsvImportService();
    final result = await service.importProducts(shopId);

    if (!context.mounted) return;

    // 結果を表示
    if (result.success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('インポート完了'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${result.importedCount}件の商品をインポートしました'),
              if (result.errorCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${result.errorCount}件のエラーがありました',
                  style: const TextStyle(color: Colors.orange),
                ),
                const SizedBox(height: 4),
                ...result.errors.take(5).map((e) => Text(
                      e,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )),
                if (result.errors.length > 5)
                  Text(
                    '他${result.errors.length - 5}件のエラー',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// CSVテンプレートをダウンロード
  Future<void> _downloadTemplate(BuildContext context) async {
    try {
      final service = CsvImportService();
      final csvContent = service.generateProductCsvTemplate();

      // ファイルに保存
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/product_template.csv');
      await file.writeAsString(csvContent);

      // 共有
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '商品CSVテンプレート',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
