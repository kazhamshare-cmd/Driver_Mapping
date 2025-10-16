import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// 回答選択肢データベースサービス
class WordDatabaseService {
  static WordDatabaseService? _instance;
  static WordDatabaseService get instance => _instance ??= WordDatabaseService._();
  
  WordDatabaseService._();
  
  static const String _wordsKey = 'word_database';
  static const String _lastUpdateKey = 'word_database_last_update';
  
  Map<String, List<String>> _wordDatabase = {};
  DateTime? _lastUpdate;
  
  /// データベース初期化
  Future<void> initialize() async {
    try {
      // ローカルストレージから読み込み
      await _loadFromLocal();
      
      // データが古い場合は更新
      if (_shouldUpdate()) {
        await _loadFromAssets();
        await _saveToLocal();
      }
    } catch (e) {
      print('単語データベース初期化エラー: $e');
      // フォールバック: アセットから読み込み
      await _loadFromAssets();
    }
  }
  
  /// ローカルストレージから読み込み
  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wordsJson = prefs.getString(_wordsKey);
      final lastUpdateStr = prefs.getString(_lastUpdateKey);
      
      if (wordsJson != null) {
        final Map<String, dynamic> wordsMap = jsonDecode(wordsJson);
        _wordDatabase = wordsMap.map((key, value) => 
          MapEntry(key, List<String>.from(value)));
      }
      
      if (lastUpdateStr != null) {
        _lastUpdate = DateTime.parse(lastUpdateStr);
      }
    } catch (e) {
      print('ローカルストレージ読み込みエラー: $e');
    }
  }
  
  /// ローカルストレージに保存
  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_wordsKey, jsonEncode(_wordDatabase));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('ローカルストレージ保存エラー: $e');
    }
  }
  
  /// アセットから読み込み
  Future<void> _loadFromAssets() async {
    try {
      final wordsJson = await rootBundle.loadString('assets/data/words.json');
      final Map<String, dynamic> wordsMap = jsonDecode(wordsJson);
      _wordDatabase = wordsMap.map((key, value) => 
        MapEntry(key, List<String>.from(value)));
    } catch (e) {
      print('アセット読み込みエラー: $e');
      // フォールバック: デフォルトデータ
      _loadDefaultWords();
    }
  }
  
  /// デフォルト単語データの読み込み
  void _loadDefaultWords() {
    _wordDatabase = {
      'あ': ['あいす', 'あかちゃん', 'あきら', 'あさがお'],
      'い': ['いしやき', 'いちご', 'いぬの'],
      'う': ['うるさい'],
      'え': ['えんぴつ', 'えほん', 'えがお', 'えいが'],
      'お': ['おかあさん', 'おにいさん', 'おとうさん', 'おかし'],
      'か': ['かきごおり', 'かみのけ', 'かばん', 'かぜひき'],
      'き': ['きのう', 'きょう', 'きのこ', 'きいろ', 'きつね'],
      'く': ['くもの', 'くつした', 'くまの', 'くちびる', 'くるま'],
      'け': ['けんきゅう', 'けがの', 'けしき', 'けいと', 'けいさつ'],
      'こ': ['こども', 'こんにちは', 'こんばんは', 'こおり', 'こねこ'],
      'さ': ['さくら', 'さかな', 'さくらんぼ', 'さるの'],
      'し': ['しろい', 'しんぶん', 'しゃしん', 'しゅうまつ', 'しゅくだい'],
      'す': ['すしや', 'すずめ', 'すいか', 'すいえい', 'すいとう'],
      'せ': ['せんせい', 'せかい', 'せんたく', 'せいかつ'],
      'そ': ['そらの', 'そとの', 'そばや', 'そうじ', 'そうべつ'],
      'た': ['たまご', 'たべもの', 'たのしい', 'たてもの', 'たからもの'],
      'ち': ['ちいさい', 'ちから', 'ちかてつ'],
      'つ': ['つきの', 'つくえの', 'つりざお', 'つまの', 'つくしの'],
      'て': ['てがみ', 'てんき', 'てんらんかい', 'てんぷら', 'てんさい'],
      'と': ['とけい', 'とりの', 'としの', 'としょかん'],
      'な': ['なつの', 'なかの', 'なまえ', 'なかま', 'なつやすみ'],
      'に': ['にほん', 'にんぎょう', 'にゅうがく', 'にゅういん'],
      'ぬ': ['ぬいぐるみ', 'ぬりえ', 'ぬまの', 'ぬすみ'],
      'ね': ['ねこの', 'ねんがじょう', 'ねつの', 'ねむい', 'ねがお'],
      'の': ['のうりん', 'のうぎょう', 'のうみん'],
      'は': ['はなの', 'はるの', 'はしの', 'はなび', 'はたらく'],
      'ひ': ['ひこうき', 'ひまわり', 'ひるの', 'ひこうき', 'ひがし'],
      'ふ': ['ふねの', 'ふくの', 'ふゆの', 'ふとん', 'ふくざつ'],
      'へ': ['へやの', 'へいわ', 'へんの', 'へいき', 'へいわ'],
      'ほ': ['ほんの', 'ほしの', 'ほんとう', 'ほんや', 'ほんしつ'],
      'ま': ['まどの', 'まちの', 'まんが', 'まつり', 'まんねんひつ'],
      'み': ['みずの', 'みどりの', 'みちの', 'みなみ', 'みなさん'],
      'む': ['むしの', 'むらの', 'むかし', 'むすこ', 'むすめ'],
      'め': ['めがね', 'めんの', 'めいし', 'めがね', 'めんきょ'],
      'も': ['ももの', 'もりの', 'もんの', 'もんく', 'もんし'],
      'や': ['やまの', 'やさい', 'やねの', 'やくそく', 'やまびこ'],
      'ゆ': ['ゆきの', 'ゆめの', 'ゆうがた', 'ゆうびん', 'ゆうじん'],
      'よ': ['よるの', 'よてい', 'よろしく', 'よしの', 'よろこび'],
      'ら': ['らくがき', 'らくの', 'らくせん', 'らくがき', 'らくがき'],
      'り': ['りんご', 'りょこう', 'りょうり', 'りょうし', 'りょうり'],
      'る': ['るすの', 'るいの', 'るいけい', 'るいけい', 'るいけい'],
      'れ': ['れきし', 'れんしゅう', 'れんあい', 'れんしゅう', 'れんあい'],
      'ろ': ['ろくの', 'ろくがつ', 'ろくがつ', 'ろくがつ', 'ろくがつ'],
      'わ': ['わかの', 'わかもの', 'わかもの', 'わかもの', 'わかもの'],
      'を': [],
    };
  }
  
  /// 更新が必要かチェック
  bool _shouldUpdate() {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!).inDays > 7; // 7日ごとに更新
  }
  
  /// 頭文字に基づく単語取得
  List<String> getWordsForHead(String head) {
    return _wordDatabase[head] ?? [];
  }
  
  /// 特定の単語が存在するかチェック
  bool containsWord(String word) {
    if (word.isEmpty) return false;
    final head = word.substring(0, 1);
    return _wordDatabase[head]?.contains(word) ?? false;
  }
  
  /// データベースサイズ取得
  int get databaseSize => _wordDatabase.values.fold(0, (sum, words) => sum + words.length);
  
  /// データベースクリア
  Future<void> clearDatabase() async {
    _wordDatabase.clear();
    _lastUpdate = null;
    await _saveToLocal();
  }
}
