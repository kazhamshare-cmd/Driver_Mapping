/// GameCenter用の定数定義
class GameCenterConstants {
  // リーダーボードセットID
  static const String leaderboardSetId = 'com.atamaoshiri.leaderboard_set';
  
  // リーダーボードID
  static const String highScoreLeaderboard = 'com.atama_oshiri.high_score';
  static const String weeklyScoreLeaderboard = 'com.atamaoshiri.weekly_score';
  static const String perfectGameLeaderboard = 'com.atamaoshiri.perfect_games';
  
  // アチーブメントID
  static const String firstGame = 'com.atamaoshiri.first_game';
  static const String score100 = 'com.atamaoshiri.score_100';
  static const String score500 = 'com.atamaoshiri.score_500';
  static const String score1000 = 'com.atamaoshiri.score_1000';
  static const String score5000 = 'com.atamaoshiri.score_5000';
  static const String perfectGame = 'com.atamaoshiri.perfect_game';
  static const String perfectGame10 = 'com.atamaoshiri.perfect_game_10';
  static const String perfectGame50 = 'com.atamaoshiri.perfect_game_50';
  static const String wordMaster = 'com.atamaoshiri.word_master';
  static const String speedDemon = 'com.atamaoshiri.speed_demon';
  
  // アチーブメント名（日本語）
  static const Map<String, String> achievementNames = {
    firstGame: '初回プレイ',
    score100: 'スコア100達成',
    score500: 'スコア500達成',
    score1000: 'スコア1000達成',
    score5000: 'スコア5000達成',
    perfectGame: 'パーフェクトゲーム',
    perfectGame10: 'パーフェクト10回達成',
    perfectGame50: 'パーフェクト50回達成',
    wordMaster: '単語マスター',
    speedDemon: 'スピードデーモン',
  };
  
  // アチーブメント説明
  static const Map<String, String> achievementDescriptions = {
    firstGame: '初めてゲームをプレイしました',
    score100: 'スコア100を達成しました',
    score500: 'スコア500を達成しました',
    score1000: 'スコア1000を達成しました',
    score5000: 'スコア5000を達成しました',
    perfectGame: '1回のゲームで全て正解しました',
    perfectGame10: 'パーフェクトゲームを10回達成しました',
    perfectGame50: 'パーフェクトゲームを50回達成しました',
    wordMaster: '100種類の単語で正解しました',
    speedDemon: '5秒以内に10回正解しました',
  };
}
