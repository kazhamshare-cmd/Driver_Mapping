import 'package:games_services/games_services.dart';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart' as room_models;

class GameCenterService {
  static final GameCenterService _instance = GameCenterService._internal();
  factory GameCenterService() => _instance;
  GameCenterService._internal();

  static GameCenterService get instance => _instance;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  /// サービス初期化
  Future<void> initialize() async {
    try {
      // 自動サインインを試行
      await signIn();
      if (kDebugMode) {
        print('GameCenter: 初期化完了');
      }
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: 初期化エラー - $e');
      }
    }
  }

  /// GameCenterにサインイン
  Future<bool> signIn() async {
    try {
      await GamesServices.signIn();
      _isSignedIn = true;
      if (kDebugMode) {
        print('GameCenter: サインイン成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: サインイン失敗 - $e');
      }
      return false;
    }
  }

  /// GameCenterからサインアウト
  Future<void> signOut() async {
    try {
      // games_services 4.1.1ではサインアウト機能が削除されている
      _isSignedIn = false;
      if (kDebugMode) {
        print('GameCenter: サインアウト成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: サインアウト失敗 - $e');
      }
    }
  }

  /// スコアをリーダーボードに送信
  Future<bool> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId,
          iOSLeaderboardID: leaderboardId,
          value: score,
        ),
      );
      if (kDebugMode) {
        print('GameCenter: スコア送信成功 - $score');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: スコア送信失敗 - $e');
      }
      return false;
    }
  }

  /// アチーブメントを解除
  Future<bool> unlockAchievement({
    required String achievementId,
    double percent = 100.0,
  }) async {
    try {
      await GamesServices.unlock(
        achievement: Achievement(
          androidID: achievementId,
          iOSID: achievementId,
          percentComplete: percent,
        ),
      );
      if (kDebugMode) {
        print('GameCenter: アチーブメント解除成功 - $achievementId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: アチーブメント解除失敗 - $e');
      }
      return false;
    }
  }

  /// リーダーボードを表示
  Future<void> showLeaderboard({String? leaderboardId}) async {
    try {
      await GamesServices.showLeaderboards(
        androidLeaderboardID: leaderboardId,
        iOSLeaderboardID: leaderboardId,
      );
      if (kDebugMode) {
        print('GameCenter: リーダーボード表示成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: リーダーボード表示失敗 - $e');
      }
    }
  }

  /// アチーブメントを表示
  Future<void> showAchievements() async {
    try {
      await GamesServices.showAchievements();
      if (kDebugMode) {
        print('GameCenter: アチーブメント表示成功');
      }
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: アチーブメント表示失敗 - $e');
      }
    }
  }

  /// プレイヤー情報を取得
  Future<room_models.Player?> getPlayerInfo() async {
    try {
      final playerId = await GamesServices.getPlayerID();
      if (kDebugMode) {
        print('GameCenter: プレイヤー情報取得成功 - $playerId');
      }
      // Playerオブジェクトを作成（仮実装）
      return room_models.Player(
        id: playerId ?? 'unknown',
        name: 'Player',
        isHost: false,
        joinedAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('GameCenter: プレイヤー情報取得失敗 - $e');
      }
      return null;
    }
  }
}