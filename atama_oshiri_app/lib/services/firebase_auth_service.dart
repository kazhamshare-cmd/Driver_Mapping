import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase認証サービス
/// 匿名認証、ユーザープロフィール管理を行う
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get userId => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;

  /// 認証状態の変更ストリーム
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 初期化（匿名ログイン）
  Future<void> initialize() async {
    try {
      print('🔐 Firebase認証サービスを初期化中...');

      // 既にログインしているかチェック
      if (_auth.currentUser != null) {
        print('✅ 既存ユーザーでログイン済み: ${_auth.currentUser!.uid}');
        await _ensureUserProfile();
        return;
      }

      // 匿名ログイン
      final userCredential = await _auth.signInAnonymously();
      print('✅ 匿名ログイン成功: ${userCredential.user!.uid}');

      // ユーザープロフィール作成
      await _ensureUserProfile();
    } catch (e) {
      print('❌ Firebase認証エラー: $e');
      rethrow;
    }
  }

  /// ユーザープロフィールの確認・作成
  Future<void> _ensureUserProfile() async {
    if (userId == null) return;

    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // 新規ユーザーのプロフィール作成
        await docRef.set({
          'userId': userId,
          'nickname': 'プレイヤー${userId!.substring(0, 6)}',
          'createdAt': FieldValue.serverTimestamp(),
          'totalGames': 0,
          'totalWins': 0,
          'bestScore': 0,
          'totalScore': 0,
        });
        print('✅ ユーザープロフィール作成完了');
      } else {
        print('✅ 既存ユーザープロフィール確認完了');
      }
    } catch (e) {
      print('❌ ユーザープロフィール作成エラー: $e');
    }
  }

  /// ニックネームの更新
  Future<void> updateNickname(String nickname) async {
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ ニックネーム更新: $nickname');
    } catch (e) {
      print('❌ ニックネーム更新エラー: $e');
      rethrow;
    }
  }

  /// ユーザープロフィールの取得
  Future<Map<String, dynamic>?> getUserProfile([String? targetUserId]) async {
    final uid = targetUserId ?? userId;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('❌ ユーザープロフィール取得エラー: $e');
      return null;
    }
  }

  /// ゲーム結果を記録
  Future<void> recordGameResult({
    required int score,
    required int wordCount,
    required bool isWin,
  }) async {
    if (userId == null) return;

    try {
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();
      final data = doc.data() ?? {};

      final currentBestScore = data['bestScore'] ?? 0;
      final newBestScore = score > currentBestScore ? score : currentBestScore;

      await docRef.update({
        'totalGames': FieldValue.increment(1),
        'totalWins': isWin ? FieldValue.increment(1) : data['totalWins'] ?? 0,
        'bestScore': newBestScore,
        'totalScore': FieldValue.increment(score),
        'lastPlayedAt': FieldValue.serverTimestamp(),
      });

      print('✅ ゲーム結果を記録: スコア=$score, 勝利=$isWin');
    } catch (e) {
      print('❌ ゲーム結果記録エラー: $e');
    }
  }

  /// サインアウト
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ サインアウト完了');
    } catch (e) {
      print('❌ サインアウトエラー: $e');
      rethrow;
    }
  }
}
