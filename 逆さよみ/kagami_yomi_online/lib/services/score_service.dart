import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScoreRecord {
  final int score;
  final DateTime date;

  ScoreRecord({
    required this.score,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'date': date.toIso8601String(),
      };

  factory ScoreRecord.fromJson(Map<String, dynamic> json) => ScoreRecord(
        score: json['score'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

class ScoreService {
  static final ScoreService _instance = ScoreService._internal();
  factory ScoreService() => _instance;
  ScoreService._internal();

  static const String _highScoreRelaxKey = 'high_score_relax';
  static const String _highScoreTimedKey = 'high_score_timed';
  static const String _rankingTimedKey = 'ranking_timed'; // タイムアタックのランキング

  // リラックスモードのハイスコア取得
  Future<int> getHighScoreRelax() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreRelaxKey) ?? 0;
  }

  // タイムアタックモードのハイスコア取得
  Future<int> getHighScoreTimed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreTimedKey) ?? 0;
  }

  // タイムアタックモードのランキング取得（ベスト3）
  Future<List<ScoreRecord>> getTimedRanking() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_rankingTimedKey);

    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) => ScoreRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // リラックスモードのハイスコア保存
  Future<bool> setHighScoreRelax(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = await getHighScoreRelax();

    if (score > currentHigh) {
      await prefs.setInt(_highScoreRelaxKey, score);
      return true; // 新記録
    }
    return false; // 既存の記録より低い
  }

  // タイムアタックモードのハイスコア保存（ランキングも更新）
  Future<bool> setHighScoreTimed(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHigh = await getHighScoreTimed();

    // ランキングを更新
    await _updateTimedRanking(score);

    if (score > currentHigh) {
      await prefs.setInt(_highScoreTimedKey, score);
      return true; // 新記録
    }
    return false; // 既存の記録より低い
  }

  // タイムアタックのランキングを更新（ベスト3まで保存）
  Future<void> _updateTimedRanking(int newScore) async {
    final prefs = await SharedPreferences.getInstance();
    final currentRanking = await getTimedRanking();

    // 新しいスコアを追加
    final newRecord = ScoreRecord(
      score: newScore,
      date: DateTime.now(),
    );
    currentRanking.add(newRecord);

    // スコアの高い順にソート
    currentRanking.sort((a, b) => b.score.compareTo(a.score));

    // ベスト3のみ保持
    final top3 = currentRanking.take(3).toList();

    // JSON形式で保存
    final jsonList = top3.map((record) => record.toJson()).toList();
    await prefs.setString(_rankingTimedKey, json.encode(jsonList));
  }

  // スコアリセット
  Future<void> resetScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_highScoreRelaxKey);
    await prefs.remove(_highScoreTimedKey);
    await prefs.remove(_rankingTimedKey);
  }
}
