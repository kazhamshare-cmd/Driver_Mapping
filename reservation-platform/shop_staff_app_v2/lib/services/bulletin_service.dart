import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bulletin_post.dart';

class BulletinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 掲示板投稿を取得（店舗ID指定、ピン留め優先）
  Stream<List<BulletinPost>> getPosts(String shopId, {PostCategory? category}) {
    Query query = _firestore
        .collection('bulletinPosts')
        .where('shopId', isEqualTo: shopId);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BulletinPost.fromFirestore(doc)).toList());
  }

  // ピン留め投稿のみ取得
  Stream<List<BulletinPost>> getPinnedPosts(String shopId) {
    return _firestore
        .collection('bulletinPosts')
        .where('shopId', isEqualTo: shopId)
        .where('isPinned', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BulletinPost.fromFirestore(doc)).toList());
  }

  // 未読投稿を取得
  Stream<List<BulletinPost>> getUnreadPosts(String shopId, String userId) {
    return _firestore
        .collection('bulletinPosts')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BulletinPost.fromFirestore(doc))
            .where((post) => !post.isReadBy(userId))
            .toList());
  }

  // 未読件数を取得
  Stream<int> getUnreadCount(String shopId, String userId) {
    return getUnreadPosts(shopId, userId).map((posts) => posts.length);
  }

  // 投稿を作成
  Future<String> createPost({
    required String shopId,
    required String authorId,
    required String authorName,
    required PostCategory category,
    required String title,
    required String content,
    bool isPinned = false,
  }) async {
    final post = BulletinPost(
      id: '', // Firestoreが自動生成
      shopId: shopId,
      authorId: authorId,
      authorName: authorName,
      category: category,
      title: title,
      content: content,
      isPinned: isPinned,
      readBy: [authorId], // 作成者は既読扱い
      commentCount: 0,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('bulletinPosts').add(post.toMap());
    return docRef.id;
  }

  // 投稿を更新
  Future<void> updatePost({
    required String postId,
    String? title,
    String? content,
    bool? isPinned,
  }) async {
    final Map<String, dynamic> updates = {};

    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (isPinned != null) updates['isPinned'] = isPinned;

    if (updates.isNotEmpty) {
      updates['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _firestore.collection('bulletinPosts').doc(postId).update(updates);
    }
  }

  // 投稿を削除
  Future<void> deletePost(String postId) async {
    // 関連するコメントも削除
    final comments = await _firestore
        .collection('bulletinComments')
        .where('postId', isEqualTo: postId)
        .get();

    final batch = _firestore.batch();

    for (var doc in comments.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('bulletinPosts').doc(postId));

    await batch.commit();
  }

  // 投稿を既読にする
  Future<void> markAsRead(String postId, String userId) async {
    final postRef = _firestore.collection('bulletinPosts').doc(postId);
    await postRef.update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  // コメントを取得
  Stream<List<BulletinComment>> getComments(String postId) {
    return _firestore
        .collection('bulletinComments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BulletinComment.fromFirestore(doc))
            .toList());
  }

  // コメントを追加
  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    final comment = BulletinComment(
      id: '',
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      content: content,
      createdAt: DateTime.now(),
    );

    // コメントを追加
    await _firestore.collection('bulletinComments').add(comment.toMap());

    // 投稿のコメント数を更新
    final postRef = _firestore.collection('bulletinPosts').doc(postId);
    await postRef.update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // コメントを削除
  Future<void> deleteComment(String commentId, String postId) async {
    await _firestore.collection('bulletinComments').doc(commentId).delete();

    // 投稿のコメント数を更新
    final postRef = _firestore.collection('bulletinPosts').doc(postId);
    await postRef.update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  // ピン留めをトグル
  Future<void> togglePin(String postId, bool currentPinStatus) async {
    await _firestore.collection('bulletinPosts').doc(postId).update({
      'isPinned': !currentPinStatus,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // 店舗のスタッフ一覧を取得
  Future<List<Map<String, dynamic>>> getShopStaff(String shopId) async {
    final snapshot = await _firestore
        .collection('employees')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'.trim().isEmpty
            ? (data['name'] ?? '名前なし')
            : '${data['lastName'] ?? ''} ${data['firstName'] ?? ''}'.trim(),
        'role': data['role'] ?? 'staff',
      };
    }).toList();
  }

  // 投稿の既読状況を取得（スタッフ名付き）
  Future<Map<String, List<Map<String, dynamic>>>> getReadStatus(
      String postId, String shopId) async {
    // 投稿を取得
    final postDoc =
        await _firestore.collection('bulletinPosts').doc(postId).get();
    if (!postDoc.exists) {
      return {'read': [], 'unread': []};
    }

    final readBy = List<String>.from(postDoc.data()?['readBy'] ?? []);

    // スタッフ一覧を取得
    final allStaff = await getShopStaff(shopId);

    // 既読・未読に分類
    final readStaff = <Map<String, dynamic>>[];
    final unreadStaff = <Map<String, dynamic>>[];

    for (final staff in allStaff) {
      if (readBy.contains(staff['id'])) {
        readStaff.add(staff);
      } else {
        unreadStaff.add(staff);
      }
    }

    return {
      'read': readStaff,
      'unread': unreadStaff,
    };
  }
}
