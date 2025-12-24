import 'package:cloud_firestore/cloud_firestore.dart';

enum PostCategory {
  announcement, // お知らせ（管理者のみ）
  handover,     // 申し送り
  other,        // その他・雑談
}

class BulletinPost {
  final String id;
  final String shopId;
  final String authorId;
  final String authorName;
  final PostCategory category;
  final String title;
  final String content;
  final bool isPinned; // ピン留め
  final List<String> readBy; // 既読したユーザーID
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BulletinPost({
    required this.id,
    required this.shopId,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.title,
    required this.content,
    this.isPinned = false,
    required this.readBy,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory BulletinPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BulletinPost(
      id: doc.id,
      shopId: data['shopId'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String? ?? '不明',
      category: _parseCategory(data['category'] as String?),
      title: data['title'] as String,
      content: data['content'] as String,
      isPinned: data['isPinned'] as bool? ?? false,
      readBy: List<String>.from(data['readBy'] as List<dynamic>? ?? []),
      commentCount: data['commentCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static PostCategory _parseCategory(String? category) {
    switch (category) {
      case 'announcement':
        return PostCategory.announcement;
      case 'handover':
        return PostCategory.handover;
      case 'other':
        return PostCategory.other;
      default:
        return PostCategory.other;
    }
  }

  String getCategoryLabel() {
    switch (category) {
      case PostCategory.announcement:
        return 'お知らせ';
      case PostCategory.handover:
        return '申し送り';
      case PostCategory.other:
        return 'その他';
    }
  }

  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'authorId': authorId,
      'authorName': authorName,
      'category': category.name,
      'title': title,
      'content': content,
      'isPinned': isPinned,
      'readBy': readBy,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

class BulletinComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  BulletinComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory BulletinComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BulletinComment(
      id: doc.id,
      postId: data['postId'] as String,
      authorId: data['authorId'] as String,
      authorName: data['authorName'] as String? ?? '不明',
      content: data['content'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
