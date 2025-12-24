import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/translation_service.dart';

class ProductCategoriesScreen extends ConsumerWidget {
  const ProductCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffUserAsync = ref.watch(staffUserProvider);

    return staffUserAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('エラー: $error')),
      ),
      data: (staffUser) {
        if (staffUser == null) {
          return const Scaffold(
            body: Center(child: Text('ログインしてください')),
          );
        }

        final categoriesAsync = ref.watch(productCategoriesProvider(staffUser.shopId));

        return Scaffold(
          appBar: AppBar(
            title: const Text('カテゴリー管理'),
          ),
          body: categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('エラー: $error')),
            data: (categories) {
              if (categories.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'カテゴリーがありません',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: categories.length,
                onReorder: (oldIndex, newIndex) async {
                  try {
                    final reorder = ref.read(reorderCategoriesProvider);
                    await reorder(categories, oldIndex, newIndex);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('並び替えエラー: $e')),
                      );
                    }
                  }
                },
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _CategoryCard(
                    key: ValueKey(category.id),
                    category: category,
                    shopId: staffUser.shopId,
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              _showCategoryDialog(context, ref, staffUser.shopId);
            },
            icon: const Icon(Icons.add),
            label: const Text('カテゴリー追加'),
          ),
        );
      },
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, String shopId, [ProductCategory? category]) {
    showDialog(
      context: context,
      builder: (context) => _CategoryDialog(
        shopId: shopId,
        category: category,
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final ProductCategory category;
  final String shopId;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: category.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(category.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: category.imageUrl == null
                  ? Icon(Icons.category, color: Colors.grey[400])
                  : null,
            ),
          ],
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: category.description != null
            ? Text(
                category.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _CategoryDialog(
                    shopId: shopId,
                    category: category,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(context, ref, category),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, ProductCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('カテゴリー「${category.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final deleteCategory = ref.read(deleteProductCategoryProvider);
        await deleteCategory(category.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('カテゴリーを削除しました')),
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
}

class _CategoryDialog extends ConsumerStatefulWidget {
  final String shopId;
  final ProductCategory? category;

  const _CategoryDialog({
    required this.shopId,
    this.category,
  });

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameThController;
  late TextEditingController _nameZhTwController;
  late TextEditingController _nameKoController;
  late TextEditingController _descriptionController;
  String? _imageUrl;
  File? _imageFile;
  bool _isUploading = false;
  bool _isTranslating = false;
  final TranslationService _translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameController = TextEditingController(text: c?.name ?? '');
    _nameEnController = TextEditingController(text: c?.nameEn ?? '');
    _nameThController = TextEditingController(text: c?.nameTh ?? '');
    _nameZhTwController = TextEditingController(text: c?.nameZhTw ?? '');
    _nameKoController = TextEditingController(text: c?.nameKo ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _imageUrl = c?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameThController.dispose();
    _nameZhTwController.dispose();
    _nameKoController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    setState(() {
      _isUploading = true;
    });

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('categories')
          .child(widget.shopId)
          .child(fileName);

      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _translateToAllLanguages() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カテゴリー名を入力してから翻訳してください')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final results = await _translationService.translateSingleText(
        text: name,
        sourceLanguage: 'ja',
        targetLanguages: ['en', 'th', 'zh-TW', 'ko'],
      );

      setState(() {
        if (results['en'] != null) _nameEnController.text = results['en']!;
        if (results['th'] != null) _nameThController.text = results['th']!;
        if (results['zh-TW'] != null) _nameZhTwController.text = results['zh-TW']!;
        if (results['ko'] != null) _nameKoController.text = results['ko']!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('翻訳が完了しました'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('翻訳エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final uploadedImageUrl = await _uploadImage();

      final category = ProductCategory(
        id: widget.category?.id ?? '',
        shopId: widget.shopId,
        name: _nameController.text,
        nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
        nameTh: _nameThController.text.isEmpty ? null : _nameThController.text,
        nameZhTw: _nameZhTwController.text.isEmpty ? null : _nameZhTwController.text,
        nameKo: _nameKoController.text.isEmpty ? null : _nameKoController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        imageUrl: uploadedImageUrl,
        displayStatus: 'available',
        sortOrder: widget.category?.sortOrder ?? 0,
        isActive: true,
        createdAt: widget.category?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saveCategory = ref.read(saveProductCategoryProvider);
      await saveCategory(category);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.category == null ? 'カテゴリーを追加しました' : 'カテゴリーを更新しました'),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.category == null ? 'カテゴリー追加' : 'カテゴリー編集',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 画像
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : (_imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: _imageFile == null && _imageUrl == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                              const SizedBox(height: 4),
                              Text('画像', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'カテゴリー名 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'カテゴリー名を入力してください';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 16),

              ExpansionTile(
                title: const Text('多言語設定'),
                children: [
                  // AI翻訳ボタン
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: _isTranslating ? null : _translateToAllLanguages,
                      icon: _isTranslating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate),
                      label: Text(_isTranslating ? '翻訳中...' : 'AIで自動翻訳'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _nameEnController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリー名（英語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameThController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリー名（タイ語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameZhTwController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリー名（繁体字中国語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameKoController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリー名（韓国語）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _saveCategory,
                    child: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.category == null ? '追加' : '更新'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
