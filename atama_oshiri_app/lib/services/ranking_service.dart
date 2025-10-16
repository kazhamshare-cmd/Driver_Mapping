import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';

/// ランキングデータモデル
class RankingEntry {
  final String userId;
  final String nickname;
  final int score;
  final int wordCount;
  final DateTime timestamp;
  final int rank;

  RankingEntry({
    required this.userId,
    required this.nickname,
    required this.score,
    required this.wordCount,
    required this.timestamp,
    this.rank = 0,
  });

  factory RankingEntry.fromFirestore(DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    return RankingEntry(
      userId: data['userId'] ?? '',
      nickname: data['nickname'] ?? 'プレイヤー',
      score: data['score'] ?? 0,
      wordCount: data['wordCount'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rank: rank,
    );
  }
}

/// グローバルランキングサービス
class RankingService {
  static final RankingService instance = RankingService._internal();
  factory RankingService() => instance;
  RankingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  /// スコアを送信
  Future<void> submitScore({
    required int score,
    required int wordCount,
  }) async {
    final userId = _auth.userId;
    if (userId == null) {
      print('❌ ユーザーがログインしていません');
      return;
    }

    try {
      // ユーザープロフィールを取得
      final profile = await _auth.getUserProfile();
      final nickname = profile?['nickname'] ?? 'プレイヤー';

      // スコアを記録
      await _firestore.collection('scores').add({
        'userId': userId,
        'nickname': nickname,
        'score': score,
        'wordCount': wordCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ スコアを送信: $score点 ($wordCount個)');
    } catch (e) {
      print('❌ スコア送信エラー: $e');
    }
  }

  /// 全体ランキングを取得
  Future<List<RankingEntry>> getGlobalRanking({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('scores')
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((entry) => RankingEntry.fromFirestore(entry.value, entry.key + 1))
          .toList();
    } catch (e) {
      print('❌ ランキング取得エラー: $e');
      return [];
    }
  }

  /// 日別ランキングを取得
  Future<List<RankingEntry>> getDailyRanking({int limit = 100}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('scores')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('timestamp', descending: false)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((entry) => RankingEntry.fromFirestore(entry.value, entry.key + 1))
          .toList();
    } catch (e) {
      print('❌ 日別ランキング取得エラー: $e');
      return [];
    }
  }

  /// 週別ランキングを取得
  Future<List<RankingEntry>> getWeeklyRanking({int limit = 100}) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final snapshot = await _firestore
          .collection('scores')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
          .orderBy('timestamp', descending: false)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .asMap()
          .entries
          .map((entry) => RankingEntry.fromFirestore(entry.value, entry.key + 1))
          .toList();
    } catch (e) {
      print('❌ 週別ランキング取得エラー: $e');
      return [];
    }
  }

  /// 自分のランクを取得
  Future<int?> getMyRank() async {
    final userId = _auth.userId;
    if (userId == null) return null;

    try {
      // 自分のベストスコアを取得
      final myScoresSnapshot = await _firestore
          .collection('scores')
          .where('userId', isEqualTo: userId)
          .orderBy('score', descending: true)
          .limit(1)
          .get();

      if (myScoresSnapshot.docs.isEmpty) return null;

      final myBestScore = myScoresSnapshot.docs.first.data()['score'] as int;

      // 自分より上のスコア数を数える
      final higherScoresSnapshot = await _firestore
          .collection('scores')
          .where('score', isGreaterThan: myBestScore)
          .get();

      return higherScoresSnapshot.docs.length + 1;
    } catch (e) {
      print('❌ 自分のランク取得エラー: $e');
      return null;
    }
  }

  /// リアルタイムランキングストリーム
  Stream<List<RankingEntry>> getRankingStream({int limit = 100}) {
    return _firestore
        .collection('scores')
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .asMap()
          .entries
          .map((entry) => RankingEntry.fromFirestore(entry.value, entry.key + 1))
          .toList();
    });
  }
}
