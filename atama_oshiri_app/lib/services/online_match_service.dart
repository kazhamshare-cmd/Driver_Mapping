import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_auth_service.dart';
import '../models/game_models.dart';

/// マッチ状態
enum MatchStatus {
  waiting,      // マッチング待ち
  ready,        // 準備完了
  playing,      // プレイ中
  finished,     // 終了
  cancelled,    // キャンセル
}

/// ターン状態
enum TurnStatus {
  player1Turn,  // プレイヤー1のターン
  player2Turn,  // プレイヤー2のターン
}

/// オンラインマッチデータ
class OnlineMatch {
  final String matchId;
  final String player1Id;
  final String player2Id;
  final String player1Nickname;
  final String player2Nickname;
  final MatchStatus status;
  final TurnStatus turnStatus;
  final Challenge currentChallenge;
  final List<String> usedWords;
  final int player1Score;
  final int player2Score;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  OnlineMatch({
    required this.matchId,
    required this.player1Id,
    required this.player2Id,
    required this.player1Nickname,
    required this.player2Nickname,
    required this.status,
    required this.turnStatus,
    required this.currentChallenge,
    required this.usedWords,
    required this.player1Score,
    required this.player2Score,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  factory OnlineMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OnlineMatch(
      matchId: doc.id,
      player1Id: data['player1Id'] ?? '',
      player2Id: data['player2Id'] ?? '',
      player1Nickname: data['player1Nickname'] ?? 'プレイヤー1',
      player2Nickname: data['player2Nickname'] ?? 'プレイヤー2',
      status: MatchStatus.values[data['status'] ?? 0],
      turnStatus: TurnStatus.values[data['turnStatus'] ?? 0],
      currentChallenge: Challenge(
        head: data['currentChallenge']['head'] ?? 'あ',
        tail: data['currentChallenge']['tail'] ?? 'ん',
      ),
      usedWords: List<String>.from(data['usedWords'] ?? []),
      player1Score: data['player1Score'] ?? 0,
      player2Score: data['player2Score'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// オンライン対戦サービス
class OnlineMatchService {
  static final OnlineMatchService instance = OnlineMatchService._internal();
  factory OnlineMatchService() => instance;
  OnlineMatchService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  StreamSubscription? _matchSubscription;
  String? _currentMatchId;

  /// マッチングを開始（ランダムマッチング）
  Future<String?> startMatchmaking() async {
    final userId = _auth.userId;
    if (userId == null) {
      print('❌ ユーザーがログインしていません');
      return null;
    }

    try {
      print('🔍 マッチング開始...');

      // 既存の待機中マッチを検索
      final waitingMatches = await _firestore
          .collection('matches')
          .where('status', isEqualTo: MatchStatus.waiting.index)
          .where('player2Id', isEqualTo: '')
          .limit(1)
          .get();

      if (waitingMatches.docs.isNotEmpty) {
        // 既存のマッチに参加
        final matchDoc = waitingMatches.docs.first;
        final profile = await _auth.getUserProfile();

        await matchDoc.reference.update({
          'player2Id': userId,
          'player2Nickname': profile?['nickname'] ?? 'プレイヤー2',
          'status': MatchStatus.ready.index,
          'startedAt': FieldValue.serverTimestamp(),
        });

        print('✅ マッチング成功: ${matchDoc.id}');
        _currentMatchId = matchDoc.id;
        return matchDoc.id;
      } else {
        // 新しいマッチを作成
        final profile = await _auth.getUserProfile();
        final docRef = await _firestore.collection('matches').add({
          'player1Id': userId,
          'player1Nickname': profile?['nickname'] ?? 'プレイヤー1',
          'player2Id': '',
          'player2Nickname': '',
          'status': MatchStatus.waiting.index,
          'turnStatus': TurnStatus.player1Turn.index,
          'currentChallenge': {
            'head': 'あ',
            'tail': 'ん',
          },
          'usedWords': [],
          'player1Score': 0,
          'player2Score': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ マッチ作成: ${docRef.id}');
        _currentMatchId = docRef.id;
        return docRef.id;
      }
    } catch (e) {
      print('❌ マッチング エラー: $e');
      return null;
    }
  }

  /// フレンドコードでマッチ作成
  Future<String?> createFriendMatch() async {
    final userId = _auth.userId;
    if (userId == null) return null;

    try {
      final profile = await _auth.getUserProfile();
      final docRef = await _firestore.collection('matches').add({
        'player1Id': userId,
        'player1Nickname': profile?['nickname'] ?? 'プレイヤー1',
        'player2Id': '',
        'player2Nickname': '',
        'status': MatchStatus.waiting.index,
        'turnStatus': TurnStatus.player1Turn.index,
        'currentChallenge': {
          'head': 'あ',
          'tail': 'ん',
        },
        'usedWords': [],
        'player1Score': 0,
        'player2Score': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isFriendMatch': true,
      });

      _currentMatchId = docRef.id;
      return docRef.id;
    } catch (e) {
      print('❌ フレンドマッチ作成エラー: $e');
      return null;
    }
  }

  /// フレンドコードでマッチに参加
  Future<bool> joinFriendMatch(String matchId) async {
    final userId = _auth.userId;
    if (userId == null) return false;

    try {
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();

      if (!matchDoc.exists) {
        print('❌ マッチが見つかりません');
        return false;
      }

      final data = matchDoc.data()!;
      if (data['player2Id'] != '') {
        print('❌ マッチは既に満員です');
        return false;
      }

      final profile = await _auth.getUserProfile();
      await matchDoc.reference.update({
        'player2Id': userId,
        'player2Nickname': profile?['nickname'] ?? 'プレイヤー2',
        'status': MatchStatus.ready.index,
        'startedAt': FieldValue.serverTimestamp(),
      });

      _currentMatchId = matchId;
      return true;
    } catch (e) {
      print('❌ マッチ参加エラー: $e');
      return false;
    }
  }

  /// 回答を送信
  Future<bool> submitAnswer({
    required String matchId,
    required String word,
    required int points,
  }) async {
    final userId = _auth.userId;
    if (userId == null) return false;

    try {
      final matchDoc = await _firestore.collection('matches').doc(matchId).get();
      final data = matchDoc.data()!;

      final isPlayer1 = data['player1Id'] == userId;
      final currentTurn = TurnStatus.values[data['turnStatus']];

      // ターン確認
      if ((isPlayer1 && currentTurn != TurnStatus.player1Turn) ||
          (!isPlayer1 && currentTurn != TurnStatus.player2Turn)) {
        print('❌ あなたのターンではありません');
        return false;
      }

      // スコア更新
      final scoreField = isPlayer1 ? 'player1Score' : 'player2Score';
      final usedWords = List<String>.from(data['usedWords'] ?? []);
      usedWords.add(word);

      // ターン交代
      final nextTurn = isPlayer1 ? TurnStatus.player2Turn : TurnStatus.player1Turn;

      await matchDoc.reference.update({
        scoreField: FieldValue.increment(points),
        'usedWords': usedWords,
        'turnStatus': nextTurn.index,
        'lastAnswerAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('❌ 回答送信エラー: $e');
      return false;
    }
  }

  /// マッチをリアルタイムで監視
  Stream<OnlineMatch> watchMatch(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((doc) => OnlineMatch.fromFirestore(doc));
  }

  /// マッチをキャンセル
  Future<void> cancelMatch(String matchId) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': MatchStatus.cancelled.index,
        'finishedAt': FieldValue.serverTimestamp(),
      });
      _currentMatchId = null;
    } catch (e) {
      print('❌ マッチキャンセルエラー: $e');
    }
  }

  /// マッチを終了
  Future<void> finishMatch(String matchId) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'status': MatchStatus.finished.index,
        'finishedAt': FieldValue.serverTimestamp(),
      });
      _currentMatchId = null;
    } catch (e) {
      print('❌ マッチ終了エラー: $e');
    }
  }

  /// クリーンアップ
  void dispose() {
    _matchSubscription?.cancel();
  }
}
