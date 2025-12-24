import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/bulletin_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/bulletin_service.dart';

class BulletinBoardScreen extends ConsumerStatefulWidget {
  const BulletinBoardScreen({super.key});

  @override
  ConsumerState<BulletinBoardScreen> createState() => _BulletinBoardScreenState();
}

class _BulletinBoardScreenState extends ConsumerState<BulletinBoardScreen> {
  final BulletinService _bulletinService = BulletinService();
  PostCategory? _selectedCategory;

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

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go('/');
              },
            ),
            title: Text(t.text('bulletinBoard')),
            actions: [
              PopupMenuButton<PostCategory?>(
                icon: const Icon(Icons.filter_list),
                onSelected: (category) {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: null,
                    child: Text(t.text('all')),
                  ),
                  PopupMenuItem(
                    value: PostCategory.announcement,
                    child: Text(_getCategoryLabel(PostCategory.announcement, t)),
                  ),
                  PopupMenuItem(
                    value: PostCategory.handover,
                    child: Text(_getCategoryLabel(PostCategory.handover, t)),
                  ),
                  PopupMenuItem(
                    value: PostCategory.other,
                    child: Text(_getCategoryLabel(PostCategory.other, t)),
                  ),
                ],
              ),
            ],
          ),
          body: _buildPostsList(staffUser.shopId, staffUser.id, staffUser.role, t),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              context.push('/bulletin/new').then((_) {
                // 投稿作成後に戻ってきたら何もしない（Streamが自動更新）
              });
            },
            child: const Icon(Icons.add),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('${t.text('error')}: $error')),
      ),
    );
  }

  Widget _buildPostsList(String shopId, String userId, String userRole, AppTranslations t) {
    return StreamBuilder<List<BulletinPost>>(
      stream: _bulletinService.getPosts(shopId, category: _selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${t.text('error')}: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.message, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  t.text('noPosts'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, userId, userRole, t);
          },
        );
      },
    );
  }

  Widget _buildPostCard(BulletinPost post, String userId, String userRole, AppTranslations t) {
    final isUnread = !post.isReadBy(userId);
    final categoryColor = _getCategoryColor(post.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: isUnread ? 4 : 1,
      color: isUnread ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () {
          // 既読にする
          if (isUnread) {
            _bulletinService.markAsRead(post.id, userId);
          }
          context.push('/bulletin/${post.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行
              Row(
                children: [
                  // カテゴリバッジ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: categoryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      post.getCategoryLabel(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ピン留めアイコン
                  if (post.isPinned)
                    const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                  const Spacer(),
                  // 未読バッジ
                  if (isUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '未読',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // タイトル
              Text(
                post.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 本文プレビュー
              Text(
                post.content,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // フッター行
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    post.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(post.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  // コメント数
                  if (post.commentCount > 0) ...[
                    Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  String _getCategoryLabel(PostCategory category, AppTranslations t) {
    switch (category) {
      case PostCategory.announcement:
        return t.text('categoryAnnouncement');
      case PostCategory.handover:
        return t.text('categoryHandover');
      case PostCategory.other:
        return t.text('categoryOther');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return '昨日 ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return DateFormat('M/d').format(dateTime);
    }
  }
}
