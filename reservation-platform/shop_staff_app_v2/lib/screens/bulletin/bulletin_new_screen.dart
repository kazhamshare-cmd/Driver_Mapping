import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/bulletin_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/bulletin_service.dart';

class BulletinNewScreen extends ConsumerStatefulWidget {
  const BulletinNewScreen({super.key});

  @override
  ConsumerState<BulletinNewScreen> createState() => _BulletinNewScreenState();
}

class _BulletinNewScreenState extends ConsumerState<BulletinNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final BulletinService _bulletinService = BulletinService();

  PostCategory _selectedCategory = PostCategory.other;
  bool _isPinned = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);

    final t = ref.watch(translationProvider);

    return staffUserAsync.when(
      data: (staffUser) {
        if (staffUser == null) {
          return Scaffold(
            body: Center(child: Text(t.text('userInfoNotFound'))),
          );
        }

        final isAdmin = staffUser.role == 'owner' || staffUser.role == 'manager';

        return Scaffold(
          appBar: AppBar(
            title: Text(t.text('newPost')),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリ選択
                  const Text(
                    'カテゴリ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PostCategory>(
                    segments: [
                      if (isAdmin)
                        const ButtonSegment(
                          value: PostCategory.announcement,
                          label: Text('お知らせ'),
                          icon: Icon(Icons.campaign),
                        ),
                      const ButtonSegment(
                        value: PostCategory.handover,
                        label: Text('申し送り'),
                        icon: Icon(Icons.assignment),
                      ),
                      const ButtonSegment(
                        value: PostCategory.other,
                        label: Text('その他'),
                        icon: Icon(Icons.chat),
                      ),
                    ],
                    selected: {_selectedCategory},
                    onSelectionChanged: (Set<PostCategory> newSelection) {
                      setState(() {
                        _selectedCategory = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // ピン留め（管理者のみ）
                  if (isAdmin) ...[
                    SwitchListTile(
                      title: const Text('ピン留め'),
                      subtitle: const Text('重要な投稿を上部に固定表示します'),
                      value: _isPinned,
                      onChanged: (value) {
                        setState(() {
                          _isPinned = value;
                        });
                      },
                      secondary: const Icon(Icons.push_pin),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // タイトル
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル *',
                      border: OutlineInputBorder(),
                      hintText: '投稿のタイトルを入力',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'タイトルを入力してください';
                      }
                      if (value.trim().length > 100) {
                        return 'タイトルは100文字以内で入力してください';
                      }
                      return null;
                    },
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),

                  // 本文
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '本文 *',
                      border: OutlineInputBorder(),
                      hintText: '詳細な内容を入力',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 10,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '本文を入力してください';
                      }
                      if (value.trim().length > 2000) {
                        return '本文は2000文字以内で入力してください';
                      }
                      return null;
                    },
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 24),

                  // 注意事項
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '投稿は店舗の全スタッフに表示されます。\n個人情報や機密情報の投稿にはご注意ください。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 投稿ボタン
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : () => _submitPost(staffUser),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSubmitting ? t.text('posting') : t.text('submitPost')),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('エラー: $error')),
      ),
    );
  }

  Future<void> _submitPost(staffUser) async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _bulletinService.createPost(
        shopId: staffUser.shopId,
        authorId: staffUser.id,
        authorName: staffUser.name,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        isPinned: _isPinned,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿しました'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
