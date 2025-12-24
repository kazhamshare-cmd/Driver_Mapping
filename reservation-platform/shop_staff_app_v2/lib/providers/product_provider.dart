import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import 'auth_provider.dart';

// カテゴリーリストのプロバイダー
final productCategoriesProvider = StreamProvider.family<List<ProductCategory>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('productCategories')
      .where('shopId', isEqualTo: shopId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => ProductCategory.fromFirestore(doc))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      });
});

// 商品リストのプロバイダー
final productsProvider = StreamProvider.family<List<Product>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('shopId', isEqualTo: shopId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      });
});

// カテゴリー別商品リストのプロバイダー
final productsByCategoryProvider = StreamProvider.family<List<Product>, ({String shopId, String categoryId})>((ref, params) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('shopId', isEqualTo: params.shopId)
      .where('categoryId', isEqualTo: params.categoryId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList();
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      });
});

// オプションリストのプロバイダー
final productOptionsProvider = StreamProvider.family<List<ProductOption>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('productOptions')
      .where('shopId', isEqualTo: shopId)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ProductOption.fromFirestore(doc))
          .toList());
});

// 商品の売り切れ状態を更新
final toggleProductSoldOutProvider = Provider((ref) {
  return (String productId, bool isSoldOut) async {
    final newStatus = isSoldOut ? 'soldout' : 'available';
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({
      'displayStatus': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  };
});

// カテゴリーを追加/更新
final saveProductCategoryProvider = Provider((ref) {
  return (ProductCategory category) async {
    final data = category.toFirestore();
    if (category.id.isEmpty) {
      // 新規追加
      await FirebaseFirestore.instance
          .collection('productCategories')
          .add(data);
    } else {
      // 更新
      await FirebaseFirestore.instance
          .collection('productCategories')
          .doc(category.id)
          .update(data);
    }
  };
});

// カテゴリーを削除
final deleteProductCategoryProvider = Provider((ref) {
  return (String categoryId) async {
    // 論理削除
    await FirebaseFirestore.instance
        .collection('productCategories')
        .doc(categoryId)
        .update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  };
});

// カテゴリーの並び替え
final reorderCategoriesProvider = Provider((ref) {
  return (List<ProductCategory> categories, int oldIndex, int newIndex) async {
    // newIndexの調整（ReorderableListViewの仕様）
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final batch = FirebaseFirestore.instance.batch();

    // 新しい順序でsortOrderを更新
    final reorderedList = List<ProductCategory>.from(categories);
    final item = reorderedList.removeAt(oldIndex);
    reorderedList.insert(newIndex, item);

    for (int i = 0; i < reorderedList.length; i++) {
      final category = reorderedList[i];
      batch.update(
        FirebaseFirestore.instance.collection('productCategories').doc(category.id),
        {'sortOrder': i, 'updatedAt': FieldValue.serverTimestamp()},
      );
    }

    await batch.commit();
  };
});

// 商品の並び替え
final reorderProductsProvider = Provider((ref) {
  return (List<Product> products, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final batch = FirebaseFirestore.instance.batch();

    final reorderedList = List<Product>.from(products);
    final item = reorderedList.removeAt(oldIndex);
    reorderedList.insert(newIndex, item);

    for (int i = 0; i < reorderedList.length; i++) {
      final product = reorderedList[i];
      batch.update(
        FirebaseFirestore.instance.collection('products').doc(product.id),
        {'sortOrder': i, 'updatedAt': FieldValue.serverTimestamp()},
      );
    }

    await batch.commit();
  };
});

// 商品を追加/更新
final saveProductProvider = Provider((ref) {
  return (Product product) async {
    final data = product.toFirestore();
    if (product.id.isEmpty) {
      // 新規追加
      await FirebaseFirestore.instance
          .collection('products')
          .add(data);
    } else {
      // 更新
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update(data);
    }
  };
});

// 商品を削除
final deleteProductProvider = Provider((ref) {
  return (String productId) async {
    // 論理削除
    await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  };
});

// オプションを追加/更新
final saveProductOptionProvider = Provider((ref) {
  return (ProductOption option) async {
    final data = option.toFirestore();
    if (option.id.isEmpty) {
      // 新規追加
      await FirebaseFirestore.instance
          .collection('productOptions')
          .add(data);
    } else {
      // 更新
      await FirebaseFirestore.instance
          .collection('productOptions')
          .doc(option.id)
          .update(data);
    }
  };
});

// オプションを削除
final deleteProductOptionProvider = Provider((ref) {
  return (String optionId) async {
    // 論理削除
    await FirebaseFirestore.instance
        .collection('productOptions')
        .doc(optionId)
        .update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  };
});

// 権限チェック: オーナーまたはマネージャーかどうか
final canManageProductsProvider = Provider<bool>((ref) {
  final staffUserAsync = ref.watch(staffUserProvider);
  return staffUserAsync.when(
    data: (user) => user != null && (user.role == 'owner' || user.role == 'manager'),
    loading: () => false,
    error: (_, __) => false,
  );
});
