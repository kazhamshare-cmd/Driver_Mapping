import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 選択的単語ダウンロードサービス
class SelectiveWordService {
  static SelectiveWordService? _instance;
  static SelectiveWordService get instance => _instance ??= SelectiveWordService._();
  
  SelectiveWordService._();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _wordsCollection = 'words';
  static const String _cacheKey = 'cached_words';
  
  Map<String, List<String>> _cachedWords = {};
  
  /// 必要な単語のみをダウンロード
  Future<List<String>> getWordsForChallenge(String head, String tail) async {
    try {
      // キャッシュから確認
      final cacheKey = '${head}_$tail';
      if (_cachedWords.containsKey(cacheKey)) {
        print('📦 キャッシュから単語を取得: $cacheKey');
        return _cachedWords[cacheKey]!;
      }
      
      // Firebaseから必要な単語のみをダウンロード
      print('🌐 Firebaseから単語をダウンロード: $head → $tail');
      final words = await _downloadWordsFromFirebase(head, tail);
      
      // キャッシュに保存
      _cachedWords[cacheKey] = words;
      await _saveToCache();
      
      return words;
    } catch (e) {
      print('❌ 単語取得エラー: $e');
      // フォールバック: デフォルト単語
      return _getDefaultWords(head);
    }
  }
  
  /// Firebaseから単語をダウンロード
  Future<List<String>> _downloadWordsFromFirebase(String head, String tail) async {
    try {
      // 頭文字でフィルタリング
      final query = await _firestore
          .collection(_wordsCollection)
          .where('head', isEqualTo: head)
          .where('tail', isEqualTo: tail)
          .limit(100) // 最大100件に制限
          .get();
      
      final words = query.docs
          .map((doc) => doc.data()['word'] as String)
          .toList();
      
      print('✅ Firebaseから${words.length}件の単語を取得');
      return words;
    } catch (e) {
      print('❌ Firebaseダウンロードエラー: $e');
      return _getDefaultWords(head);
    }
  }
  
  /// デフォルト単語の取得
  List<String> _getDefaultWords(String head) {
    final defaultWords = {
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
    
    return defaultWords[head] ?? [];
  }
  
  /// キャッシュに保存
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedWords));
    } catch (e) {
      print('❌ キャッシュ保存エラー: $e');
    }
  }
  
  /// キャッシュから読み込み
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson != null) {
        final Map<String, dynamic> cacheMap = jsonDecode(cacheJson);
        _cachedWords = cacheMap.map((key, value) => 
          MapEntry(key, List<String>.from(value)));
      }
    } catch (e) {
      print('❌ キャッシュ読み込みエラー: $e');
    }
  }
  
  /// キャッシュクリア
  Future<void> clearCache() async {
    _cachedWords.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
  
  /// キャッシュサイズ取得
  int get cacheSize => _cachedWords.values.fold(0, (sum, words) => sum + words.length);
}
