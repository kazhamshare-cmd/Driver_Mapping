import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 一括単語ダウンロードサービス
class BulkWordService {
  static BulkWordService? _instance;
  static BulkWordService get instance => _instance ??= BulkWordService._();
  
  BulkWordService._();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _wordsCollection = 'words';
  static const String _cacheKey = 'bulk_words_cache';
  static const String _lastDownloadKey = 'last_bulk_download';
  
  Map<String, List<String>> _wordDatabase = {};
  DateTime? _lastDownload;
  
  /// 全単語データベース初期化
  Future<void> initialize() async {
    try {
      // ローカルキャッシュから読み込み
      await _loadFromCache();
      
      // データが古い場合は更新
      if (_shouldUpdate()) {
        print('🔄 単語データベースを更新中...');
        await _downloadAllWords();
        await _saveToCache();
        print('✅ 単語データベース更新完了: ${_wordDatabase.length}件');
      } else {
        print('📦 キャッシュから単語データベースを読み込み: ${_wordDatabase.length}件');
      }
    } catch (e) {
      print('❌ 単語データベース初期化エラー: $e');
      // フォールバック: デフォルトデータ
      _loadDefaultWords();
    }
  }
  
  /// 全単語をダウンロード
  Future<void> _downloadAllWords() async {
    try {
      print('🌐 Firebaseから全単語をダウンロード中...');
      
      // バッチ処理で全単語を取得
      final batchSize = 1000;
      int offset = 0;
      bool hasMore = true;
      
      while (hasMore) {
        final query = await _firestore
            .collection(_wordsCollection)
            .limit(batchSize)
            .offset(offset)
            .get();
        
        if (query.docs.isEmpty) {
          hasMore = false;
          break;
        }
        
        // 単語を頭文字ごとに分類
        for (final doc in query.docs) {
          final data = doc.data();
          final word = data['word'] as String?;
          final head = data['head'] as String?;
          
          if (word != null && head != null) {
            _wordDatabase.putIfAbsent(head, () => []);
            _wordDatabase[head]!.add(word);
          }
        }
        
        offset += batchSize;
        print('📥 ダウンロード進捗: ${offset}件完了');
      }
      
      _lastDownload = DateTime.now();
      print('✅ 全単語ダウンロード完了: ${_wordDatabase.length}件の頭文字');
    } catch (e) {
      print('❌ 全単語ダウンロードエラー: $e');
      throw e;
    }
  }
  
  /// 頭文字に基づく単語取得
  List<String> getWordsForHead(String head) {
    return _wordDatabase[head] ?? [];
  }
  
  /// 頭文字と尻文字に基づく単語取得
  List<String> getWordsForHeadAndTail(String head, String tail) {
    final words = _wordDatabase[head] ?? [];
    return words.where((word) => word.endsWith(tail)).toList();
  }
  
  /// 特定の単語が存在するかチェック
  bool containsWord(String word) {
    if (word.isEmpty) return false;
    final head = word.substring(0, 1);
    return _wordDatabase[head]?.contains(word) ?? false;
  }
  
  /// キャッシュから読み込み
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      final lastDownloadStr = prefs.getString(_lastDownloadKey);
      
      if (cacheJson != null) {
        final Map<String, dynamic> cacheMap = jsonDecode(cacheJson);
        _wordDatabase = cacheMap.map((key, value) => 
          MapEntry(key, List<String>.from(value)));
      }
      
      if (lastDownloadStr != null) {
        _lastDownload = DateTime.parse(lastDownloadStr);
      }
    } catch (e) {
      print('❌ キャッシュ読み込みエラー: $e');
    }
  }
  
  /// キャッシュに保存
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_wordDatabase));
      if (_lastDownload != null) {
        await prefs.setString(_lastDownloadKey, _lastDownload!.toIso8601String());
      }
    } catch (e) {
      print('❌ キャッシュ保存エラー: $e');
    }
  }
  
  /// 更新が必要かチェック
  bool _shouldUpdate() {
    if (_lastDownload == null) return true;
    return DateTime.now().difference(_lastDownload!).inDays > 7; // 7日ごとに更新
  }
  
  /// デフォルト単語の読み込み
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
  
  /// データベースサイズ取得
  int get databaseSize => _wordDatabase.values.fold(0, (sum, words) => sum + words.length);
  
  /// キャッシュクリア
  Future<void> clearCache() async {
    _wordDatabase.clear();
    _lastDownload = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_lastDownloadKey);
  }
  
  /// 強制更新
  Future<void> forceUpdate() async {
    await clearCache();
    await initialize();
  }
}
