// import 'package:games_services/games_services.dart';
import 'package:flutter/foundation.dart';
import '../models/room_models.dart' as room_models;

class GameCenterService {
  static final GameCenterService _instance = GameCenterService._internal();
  factory GameCenterService() => _instance;
  GameCenterService._internal();

  static GameCenterService get instance => _instance;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  /// サービス初期化（無効化）
  Future<void> initialize() async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているため初期化をスキップ');
    }
  }

  /// GameCenterにサインイン（無効化）
  Future<bool> signIn() async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためサインインをスキップ');
    }
    return false;
  }

  /// GameCenterからサインアウト（無効化）
  Future<void> signOut() async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためサインアウトをスキップ');
    }
  }

  /// スコアをリーダーボードに送信（無効化）
  Future<bool> submitScore({
    required String leaderboardId,
    required int score,
  }) async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためスコア送信をスキップ - $leaderboardId: $score');
    }
    return false;
  }

  /// アチーブメントを解除（無効化）
  Future<bool> unlockAchievement({
    required String achievementId,
    double percent = 100.0,
  }) async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためアチーブメント解除をスキップ - $achievementId');
    }
    return false;
  }

  /// リーダーボードを表示（無効化）
  Future<void> showLeaderboard({String? leaderboardId}) async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためリーダーボード表示をスキップ');
    }
  }

  /// アチーブメントを表示（無効化）
  Future<void> showAchievements() async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためアチーブメント表示をスキップ');
    }
  }

  /// プレイヤー情報を取得（無効化）
  Future<room_models.Player?> getPlayerInfo() async {
    if (kDebugMode) {
      print('GameCenter: 無効化されているためプレイヤー情報取得をスキップ');
    }
    return null;
  }
}