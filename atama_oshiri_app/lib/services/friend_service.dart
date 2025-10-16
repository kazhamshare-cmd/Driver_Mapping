import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';

/// フレンドデータ
class Friend {
  final String userId;
  final String nickname;
  final int bestScore;
  final int totalGames;
  final DateTime? lastPlayedAt;

  Friend({
    required this.userId,
    required this.nickname,
    required this.bestScore,
    required this.totalGames,
    this.lastPlayedAt,
  });

  factory Friend.fromFirestore(Map<String, dynamic> data) {
    return Friend(
      userId: data['userId'] ?? '',
      nickname: data['nickname'] ?? 'プレイヤー',
      bestScore: data['bestScore'] ?? 0,
      totalGames: data['totalGames'] ?? 0,
      lastPlayedAt: (data['lastPlayedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// フレンドシステムサービス
class FriendService {
  static final FriendService instance = FriendService._internal();
  factory FriendService() => instance;
  FriendService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  /// 自分のフレンドコードを取得
  String? getMyFriendCode() {
    return _auth.userId;
  }

  /// フレンドリクエストを送信
  Future<bool> sendFriendRequest(String friendCode) async {
    final myUserId = _auth.userId;
    if (myUserId == null) {
      print('❌ ユーザーがログインしていません');
      return false;
    }

    if (friendCode == myUserId) {
      print('❌ 自分自身をフレンド登録できません');
      return false;
    }

    try {
      // 相手のユーザーが存在するか確認
      final friendDoc = await _firestore.collection('users').doc(friendCode).get();
      if (!friendDoc.exists) {
        print('❌ ユーザーが見つかりません');
        return false;
      }

      // 既にフレンドか確認
      final existingFriend = await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('friends')
          .doc(friendCode)
          .get();

      if (existingFriend.exists) {
        print('⚠️ 既にフレンドです');
        return false;
      }

      // フレンドリクエストを送信（相手のpendingRequestsに追加）
      await _firestore
          .collection('users')
          .doc(friendCode)
          .collection('pendingRequests')
          .doc(myUserId)
          .set({
        'fromUserId': myUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ フレンドリクエストを送信しました');
      return true;
    } catch (e) {
      print('❌ フレンドリクエスト送信エラー: $e');
      return false;
    }
  }

  /// フレンドリクエストを承認
  Future<bool> acceptFriendRequest(String fromUserId) async {
    final myUserId = _auth.userId;
    if (myUserId == null) return false;

    try {
      // 両方のユーザーのフレンドリストに追加
      final myProfile = await _auth.getUserProfile();
      final friendProfile = await _auth.getUserProfile(fromUserId);

      // 自分のフレンドリストに追加
      await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('friends')
          .doc(fromUserId)
          .set({
        'userId': fromUserId,
        'nickname': friendProfile?['nickname'] ?? 'プレイヤー',
        'addedAt': FieldValue.serverTimestamp(),
      });

      // 相手のフレンドリストに追加
      await _firestore
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .doc(myUserId)
          .set({
        'userId': myUserId,
        'nickname': myProfile?['nickname'] ?? 'プレイヤー',
        'addedAt': FieldValue.serverTimestamp(),
      });

      // リクエストを削除
      await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('pendingRequests')
          .doc(fromUserId)
          .delete();

      print('✅ フレンドリクエストを承認しました');
      return true;
    } catch (e) {
      print('❌ フレンドリクエスト承認エラー: $e');
      return false;
    }
  }

  /// フレンドリクエストを拒否
  Future<void> rejectFriendRequest(String fromUserId) async {
    final myUserId = _auth.userId;
    if (myUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('pendingRequests')
          .doc(fromUserId)
          .delete();

      print('✅ フレンドリクエストを拒否しました');
    } catch (e) {
      print('❌ フレンドリクエスト拒否エラー: $e');
    }
  }

  /// フレンドリストを取得
  Future<List<Friend>> getFriendList() async {
    final myUserId = _auth.userId;
    if (myUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('friends')
          .get();

      final friends = <Friend>[];

      for (final doc in snapshot.docs) {
        final friendId = doc.data()['userId'] as String;
        final friendProfile = await _auth.getUserProfile(friendId);

        if (friendProfile != null) {
          friends.add(Friend.fromFirestore(friendProfile));
        }
      }

      // ベストスコア順にソート
      friends.sort((a, b) => b.bestScore.compareTo(a.bestScore));

      return friends;
    } catch (e) {
      print('❌ フレンドリスト取得エラー: $e');
      return [];
    }
  }

  /// 保留中のフレンドリクエストを取得
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final myUserId = _auth.userId;
    if (myUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('pendingRequests')
          .get();

      final requests = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final fromUserId = doc.data()['fromUserId'] as String;
        final profile = await _auth.getUserProfile(fromUserId);

        if (profile != null) {
          requests.add({
            'userId': fromUserId,
            'nickname': profile['nickname'] ?? 'プレイヤー',
            'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate(),
          });
        }
      }

      return requests;
    } catch (e) {
      print('❌ 保留中リクエスト取得エラー: $e');
      return [];
    }
  }

  /// フレンドを削除
  Future<void> removeFriend(String friendId) async {
    final myUserId = _auth.userId;
    if (myUserId == null) return;

    try {
      // 両方のフレンドリストから削除
      await _firestore
          .collection('users')
          .doc(myUserId)
          .collection('friends')
          .doc(friendId)
          .delete();

      await _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(myUserId)
          .delete();

      print('✅ フレンドを削除しました');
    } catch (e) {
      print('❌ フレンド削除エラー: $e');
    }
  }

  /// フレンドランキングを取得
  Future<List<Friend>> getFriendRanking() async {
    final friends = await getFriendList();
    // 既にベストスコア順にソート済み
    return friends;
  }
}
