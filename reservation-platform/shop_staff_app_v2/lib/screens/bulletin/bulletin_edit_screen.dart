import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/bulletin_post.dart';
import '../../providers/auth_provider.dart';
import '../../services/bulletin_service.dart';

class BulletinEditScreen extends ConsumerStatefulWidget {
  final String postId;

  const BulletinEditScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<BulletinEditScreen> createState() => _BulletinEditScreenState();
}

class _BulletinEditScreenState extends ConsumerState<BulletinEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final BulletinService _bulletinService = BulletinService();

  bool _isPinned = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  BulletinPost? _originalPost;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final staffUser = ref.read(staffUserProvider).value;
    if (staffUser == null) return;

    // Streamから一度だけ取得
    final postsStream = _bulletinService.getPosts(staffUser.shopId);
    final posts = await postsStream.first;
    final post = posts.where((p) => p.id == widget.postId).firstOrNull;

    if (post != null) {
      setState(() {
        _originalPost = post;
        _titleController.text = post.title;
        _contentController.text = post.content;
        _isPinned = post.isPinned;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffUserAsync = ref.watch(staffUserProvider);

    return staffUserAsync.when(
      data: (staffUser) {
        if (staffUser == null) {
          return const Scaffold(
            body: Center(child: Text('ログインしてください')),
          );
        }

        if (_isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_originalPost == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('投稿が見つかりません')),
            body: const Center(child: Text('この投稿は削除されたか、存在しません')),
          );
        }

        // 編集権限チェック
        final canEdit = _originalPost!.authorId == staffUser.id;
        final isAdmin = staffUser.role == 'owner' || staffUser.role == 'manager';

        if (!canEdit) {
          return Scaffold(
            appBar: AppBar(title: const Text('編集権限がありません')),
            body: const Center(child: Text('この投稿を編集する権限がありません')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('投稿を編集'),
            actions: [
              IconButton(
                onPressed: _isSubmitting ? null : _submitEdit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                tooltip: '保存',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリ表示（編集不可）
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'カテゴリ: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_originalPost!.getCategoryLabel()),
                        const SizedBox(width: 8),
                        const Text(
                          '(編集不可)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '投稿を編集すると「編集済み」マークが表示されます。\n既に投稿を読んだユーザーには通知されません。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) {
      return;
    }

    final newTitle = _titleController.text.trim();
    final newContent = _contentController.text.trim();

    // 変更があるかチェック
    if (newTitle == _originalPost!.title &&
        newContent == _originalPost!.content &&
        _isPinned == _originalPost!.isPinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('変更がありません'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _bulletinService.updatePost(
        postId: widget.postId,
        title: newTitle != _originalPost!.title ? newTitle : null,
        content: newContent != _originalPost!.content ? newContent : null,
        isPinned: _isPinned != _originalPost!.isPinned ? _isPinned : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿を更新しました'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新に失敗しました: $e'),
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
