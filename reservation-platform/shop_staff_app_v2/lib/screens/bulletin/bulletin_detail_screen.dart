import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/bulletin_post.dart';
import '../../providers/auth_provider.dart';
import '../../services/bulletin_service.dart';

class BulletinDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const BulletinDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<BulletinDetailScreen> createState() => _BulletinDetailScreenState();
}

class _BulletinDetailScreenState extends ConsumerState<BulletinDetailScreen> {
  final BulletinService _bulletinService = BulletinService();
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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

        return StreamBuilder<List<BulletinPost>>(
          stream: _bulletinService.getPosts(staffUser.shopId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('エラー: ${snapshot.error}')),
              );
            }

            final posts = snapshot.data ?? [];
            final post = posts.where((p) => p.id == widget.postId).firstOrNull;

            if (post == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('投稿が見つかりません')),
                body: const Center(child: Text('この投稿は削除されたか、存在しません')),
              );
            }

            // 既読にする
            if (!post.isReadBy(staffUser.id)) {
              _bulletinService.markAsRead(post.id, staffUser.id);
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('投稿詳細'),
                actions: [
                  // 自分の投稿またはオーナー/マネージャーの場合は編集・削除可能
                  if (post.authorId == staffUser.id ||
                      staffUser.role == 'owner' ||
                      staffUser.role == 'manager')
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        if (staffUser.role == 'owner' || staffUser.role == 'manager')
                          PopupMenuItem(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(
                                  post.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(post.isPinned ? 'ピン留め解除' : 'ピン留め'),
                              ],
                            ),
                          ),
                        if (post.authorId == staffUser.id)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('編集'),
                              ],
                            ),
                          ),
                        if (post.authorId == staffUser.id ||
                            staffUser.role == 'owner' ||
                            staffUser.role == 'manager')
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('削除', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) async {
                        if (value == 'pin') {
                          await _bulletinService.togglePin(post.id, post.isPinned);
                        } else if (value == 'edit') {
                          if (context.mounted) {
                            context.push('/bulletin/${post.id}/edit');
                          }
                        } else if (value == 'delete') {
                          _confirmDelete(context, post);
                        }
                      },
                    ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPostContent(post, staffUser.shopId, staffUser.role),
                          const Divider(height: 1, thickness: 1),
                          _buildCommentSection(post, staffUser.id),
                        ],
                      ),
                    ),
                  ),
                  _buildCommentInput(staffUser.id, staffUser.name),
                ],
              ),
            );
          },
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

  Widget _buildPostContent(BulletinPost post, String shopId, String userRole) {
    final categoryColor = _getCategoryColor(post.category);
    final canViewReadStatus = userRole == 'owner' || userRole == 'manager';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリとピン留め
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: categoryColor.withOpacity(0.3)),
                ),
                child: Text(
                  post.getCategoryLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: categoryColor,
                  ),
                ),
              ),
              if (post.isPinned) ...[
                const SizedBox(width: 8),
                const Icon(Icons.push_pin, size: 20, color: Colors.orange),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // タイトル
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 作成者と日時
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                post.authorName,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('yyyy/M/d HH:mm').format(post.createdAt),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          if (post.updatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '編集済み: ${DateFormat('yyyy/M/d HH:mm').format(post.updatedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 本文
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
          // 既読状況ボタン（オーナー・マネージャーのみ）
          if (canViewReadStatus) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showReadStatusDialog(context, post.id, shopId, post.readBy.length),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      '既読: ${post.readBy.length}人',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReadStatusDialog(
      BuildContext context, String postId, String shopId, int readCount) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _bulletinService.getReadStatus(postId, shopId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('エラー: ${snapshot.error}'));
                }

                final readStaff = snapshot.data?['read'] ?? [];
                final unreadStaff = snapshot.data?['unread'] ?? [];
                final totalCount = readStaff.length + unreadStaff.length;

                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ハンドル
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // タイトルと進捗
                      Row(
                        children: [
                          const Text(
                            '既読状況',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: readStaff.length == totalCount
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${readStaff.length}/$totalCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: readStaff.length == totalCount
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 進捗バー
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalCount > 0 ? readStaff.length / totalCount : 0,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            readStaff.length == totalCount
                                ? Colors.green
                                : Colors.blue,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 未読セクション
                      if (unreadStaff.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.visibility_off,
                                size: 18,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '未読 (${unreadStaff.length}人)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...unreadStaff.map((staff) => _buildStaffTile(
                              staff,
                              isRead: false,
                            )),
                        const SizedBox(height: 24),
                      ],
                      // 既読セクション
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.visibility,
                              size: 18,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '既読 (${readStaff.length}人)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (readStaff.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text(
                              'まだ誰も読んでいません',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...readStaff.map((staff) => _buildStaffTile(
                              staff,
                              isRead: true,
                            )),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff, {required bool isRead}) {
    final roleLabel = _getRoleLabel(staff['role'] as String? ?? 'staff');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isRead ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isRead ? Colors.green.shade200 : Colors.red.shade200,
            child: Text(
              (staff['name'] as String? ?? '?').substring(0, 1),
              style: TextStyle(
                color: isRead ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff['name'] as String? ?? '不明',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isRead ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isRead ? Colors.green : Colors.red.shade300,
            size: 22,
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'オーナー';
      case 'manager':
        return 'マネージャー';
      case 'staff':
        return 'スタッフ';
      default:
        return role;
    }
  }

  Widget _buildCommentSection(BulletinPost post, String userId) {
    return StreamBuilder<List<BulletinComment>>(
      stream: _bulletinService.getComments(post.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('コメントの読み込みエラー: ${snapshot.error}'),
          );
        }

        final comments = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'コメント (${comments.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (comments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'まだコメントがありません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...comments.map((comment) => _buildCommentCard(comment, userId)),
          ],
        );
      },
    );
  }

  Widget _buildCommentCard(BulletinComment comment, String userId) {
    final isMyComment = comment.authorId == userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMyComment ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: isMyComment ? Colors.blue : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                comment.authorName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isMyComment ? Colors.blue : Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(comment.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.content,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(String userId, String userName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'コメントを入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(userId, userName),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isSubmitting ? null : () => _submitComment(userId, userName),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment(String userId, String userName) async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _bulletinService.addComment(
        postId: widget.postId,
        authorId: userId,
        authorName: userName,
        content: content,
      );

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('コメントを投稿しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('コメントの投稿に失敗しました: $e'),
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

  Future<void> _confirmDelete(BuildContext context, BulletinPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を削除'),
        content: const Text('この投稿を削除してもよろしいですか？\nコメントも全て削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _bulletinService.deletePost(post.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('投稿を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getCategoryColor(PostCategory category) {
    switch (category) {
      case PostCategory.announcement:
        return Colors.red;
      case PostCategory.handover:
        return Colors.blue;
      case PostCategory.other:
        return Colors.green;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'たった今';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分前';
    } else if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return '昨日 ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('M/d HH:mm').format(dateTime);
    }
  }
}
