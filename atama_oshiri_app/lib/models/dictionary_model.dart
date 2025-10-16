import 'dart:convert';
import 'package:flutter/services.dart';

/// しりとり用辞書データモデル
class DictionaryModel {
  static DictionaryModel? _instance;
  static DictionaryModel get instance => _instance ??= DictionaryModel._();
  
  DictionaryModel._();
  
  Map<String, List<String>> _dictionary = {};
  bool _isLoaded = false;
  
  /// 辞書データをロード
  Future<void> loadDictionary() async {
    if (_isLoaded) return;
    
    try {
      // 複数の辞書ファイルを統合
      await _loadMultipleDictionaries();
      _isLoaded = true;
      print('辞書データをロードしました: ${_dictionary.length}文字、総単語数: $totalWordCount');
    } catch (e) {
      print('辞書データのロードに失敗しました: $e');
      // フォールバック用の最小辞書
      _loadFallbackDictionary();
    }
  }
  
  /// 複数の辞書ファイルを統合してロード
  Future<void> _loadMultipleDictionaries() async {
    _dictionary = {};
    
    // ひらがな文字一覧（濁音・半濁音含む）
    const hiraganaChars = [
      'あ', 'い', 'う', 'え', 'お',
      'か', 'き', 'く', 'け', 'こ',
      'が', 'ぎ', 'ぐ', 'げ', 'ご',
      'さ', 'し', 'す', 'せ', 'そ',
      'ざ', 'じ', 'ず', 'ぜ', 'ぞ',
      'た', 'ち', 'つ', 'て', 'と',
      'だ', 'ぢ', 'づ', 'で', 'ど',
      'な', 'に', 'ぬ', 'ね', 'の',
      'は', 'ひ', 'ふ', 'へ', 'ほ',
      'ば', 'び', 'ぶ', 'べ', 'ぼ',
      'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ',
      'ま', 'み', 'む', 'め', 'も',
      'や', 'ゆ', 'よ',
      'ら', 'り', 'る', 'れ', 'ろ',
      'わ', 'ゐ', 'ゑ', 'を', 'ん',
      'っ'
    ];
    
    // 各文字の辞書ファイルをロード
    for (final char in hiraganaChars) {
      await _loadCharDictionary(char);
    }
    
    // 重複除去
    _removeDuplicates();
  }
  
  /// 特定の文字の辞書ファイルをロード
  Future<void> _loadCharDictionary(String char) async {
    try {
      final String jsonString = await rootBundle.loadString('assets/dictionary/char_$char.json');
      final List<dynamic> words = json.decode(jsonString);
      
      _dictionary[char] = words.cast<String>();
      print('$char の辞書をロードしました: ${words.length}単語');
    } catch (e) {
      print('$char の辞書ロードに失敗: $e');
      _dictionary[char] = [];
    }
  }
  
  
  /// 重複除去
  void _removeDuplicates() {
    _dictionary.forEach((char, words) {
      // 重複を除去し、ソート
      final uniqueWords = words.toSet().toList()..sort();
      _dictionary[char] = uniqueWords;
    });
  }
  
  /// フォールバック用の最小辞書
  void _loadFallbackDictionary() {
    _dictionary = {
      'あ': ['あめ', 'あり', 'あし', 'あか', 'あお'],
      'い': ['いぬ', 'いえ', 'いす', 'いちご', 'いち'],
      'う': ['うま', 'うし', 'うさぎ', 'うみ', 'うた'],
      'え': ['えんぴつ', 'えき', 'えほん', 'えいが', 'えん'],
      'お': ['おかし', 'おに', 'おはな', 'おかね', 'おと'],
      'か': ['かばん', 'かみ', 'かさ', 'かば', 'かめ'],
      'き': ['きつね', 'きりん', 'き', 'きのこ', 'きんぎょ'],
      'く': ['くま', 'くつ', 'くるま', 'くも', 'くじら'],
      'け': ['けん', 'けいさつ', 'けんこう', 'けがわ', 'けいと'],
      'こ': ['こねこ', 'こい', 'こま', 'こども', 'こおり'],
      'さ': ['さかな', 'さくら', 'さる', 'さつまいも', 'さとう'],
      'し': ['しろ', 'しんぶん', 'しゃしん', 'しゃく', 'しゃり'],
      'す': ['すいか', 'すずめ', 'すし', 'すいとう', 'すな'],
      'せ': ['せんせい', 'せかい', 'せいかつ', 'せき', 'せん'],
      'そ': ['そら', 'そば', 'そん', 'そふ', 'そんざい'],
      'た': ['たまご', 'たこ', 'たてもの', 'たな', 'たま'],
      'ち': ['ちょうちょ', 'ちず', 'ちいさい', 'ちか', 'ちから'],
      'つ': ['つき', 'つくえ', 'つきみ', 'つくし', 'つな'],
      'て': ['てがみ', 'てんき', 'てんとうむし', 'てん', 'てら'],
      'と': ['とり', 'とけい', 'とら', 'とんぼ', 'とし'],
      'な': ['なす', 'なつ', 'なかま', 'なか', 'なみ'],
      'に': ['にんじん', 'にわとり', 'にほん', 'にし', 'にん'],
      'ぬ': ['ぬいぐるみ', 'ぬの', 'ぬま', 'ぬりえ', 'ぬく'],
      'ね': ['ねこ', 'ねずみ', 'ねんがじょう', 'ねこ', 'ねん'],
      'の': ['のり', 'のう', 'のうりつ', 'のう', 'のう'],
      'は': ['はな', 'はち', 'はさみ', 'はなび', 'はし'],
      'ひ': ['ひこうき', 'ひつじ', 'ひまわり', 'ひ', 'ひら'],
      'ふ': ['ふね', 'ふく', 'ふうせん', 'ふく', 'ふる'],
      'へ': ['へび', 'へや', 'へいわ', 'へい', 'へい'],
      'ほ': ['ほん', 'ほし', 'ほんとう', 'ほん', 'ほん'],
      'ま': ['まんが', 'まど', 'まつ', 'まん', 'まん'],
      'み': ['みかん', 'みず', 'みどり', 'み', 'み'],
      'む': ['むし', 'むら', 'むすこ', 'む', 'む'],
      'め': ['めがね', 'め', 'めん', 'め', 'め'],
      'も': ['もも', 'もり', 'もん', 'も', 'も'],
      'や': ['やさい', 'やま', 'やね', 'や', 'や'],
      'ゆ': ['ゆき', 'ゆめ', 'ゆう', 'ゆ', 'ゆ'],
      'よ': ['よる', 'よこ', 'よ', 'よ', 'よ'],
      'ら': ['らくだ', 'らく', 'ら', 'ら', 'ら'],
      'り': ['りんご', 'りす', 'り', 'り', 'り'],
      'る': ['るす', 'る', 'る', 'る', 'る'],
      'れ': ['れいぞうこ', 'れ', 'れ', 'れ', 'れ'],
      'ろ': ['ろく', 'ろ', 'ろ', 'ろ', 'ろ'],
      'わ': ['わに', 'わか', 'わ', 'わ', 'わ'],
    };
    _isLoaded = true;
  }
  
  /// 指定された文字で始まる単語のリストを取得
  List<String> getWordsStartingWith(String char) {
    return _dictionary[char] ?? [];
  }
  
  /// 単語が辞書に存在するかチェック
  bool isWordValid(String word) {
    if (word.isEmpty) return false;

    // ひらがな正規化
    final normalizedWord = _normalizeWord(word);
    final firstChar = normalizedWord[0];
    final words = getWordsStartingWith(firstChar);
    final isValid = words.contains(normalizedWord);

    print('📚 辞書チェック: "$word" → 正規化: "$normalizedWord" → 結果: ${isValid ? "✅ 存在" : "❌ 不存在"}');
    if (!isValid && words.isNotEmpty) {
      print('  辞書内の最初の5単語: ${words.take(5).join(", ")}');
    }

    return isValid;
  }

  /// 頭お尻ゲーム用：指定された頭文字と尻文字で始まり・終わる単語が存在するかチェック
  bool isWordValidForHeadTail(String word, String headChar, String tailChar) {
    if (word.isEmpty) return false;

    // ひらがな正規化
    final normalizedWord = _normalizeWord(word);
    if (normalizedWord.isEmpty) return false;

    // 頭文字チェック（濁音・半濁音の違いを許容）
    final actualHeadChar = normalizedWord[0];
    if (!_isCompatibleHeadChar(actualHeadChar, headChar)) {
      print('📚 頭文字不一致: 期待="$headChar", 実際="$actualHeadChar"');
      return false;
    }

    // 尻文字チェック（長音符対応）
    final actualTailChar = getLastCharForShiritori(normalizedWord);
    if (actualTailChar != tailChar) {
      print('📚 尻文字不一致: 期待="$tailChar", 実際="$actualTailChar"');
      return false;
    }

    // 辞書に存在するかチェック
    final words = getWordsStartingWith(headChar);
    final isValid = words.contains(normalizedWord);

    print('📚 頭お尻チェック: "$word" → 正規化: "$normalizedWord" → 頭:"$actualHeadChar" 尻:"$actualTailChar" → 結果: ${isValid ? "✅ 正解" : "❌ 不正解"}');
    if (!isValid && words.isNotEmpty) {
      print('  辞書内の最初の5単語: ${words.take(5).join(", ")}');
    }

    return isValid;
  }
  
  /// 単語をひらがなに正規化（重複除去対応）
  String _normalizeWord(String word) {
    if (word.isEmpty) return word;

    // 中黒（・）とスペースを削除
    // 例: 「ボン・ジョビ」→「ボンジョビ」
    String result = word.replaceAll('・', '').replaceAll(' ', '').replaceAll('　', '');

    // カタカナをひらがなに変換（伸ばし棒「ー」は除く）
    for (int i = 0; i < result.length; i++) {
      int code = result.codeUnitAt(i);
      if (code >= 0x30A1 && code <= 0x30F6) { // カタカナの範囲
        result = result.replaceRange(i, i + 1, String.fromCharCode(code - 0x60));
      }
    }

    // 英数字や記号を除去（ひらがな・カタカナ・漢字・伸ばし棒「ー」のみ残す）
    result = result.replaceAll(RegExp(r'[^あ-んア-ン一-龯ー]'), '');

    return result;
  }

  /// 音声認識結果を辞書形式に変換
  /// 例: 「りぴーたー」→「りぴいた」、「りみーたー」→「りみった」
  String convertSpeechToDictionary(String speechResult) {
    if (speechResult.isEmpty) return speechResult;

    String result = speechResult;

    // 長音符「ー」を適切な文字に変換
    result = _convertLongVowelToKana(result);

    return result;
  }

  /// 長音符を適切なかなに変換
  String _convertLongVowelToKana(String word) {
    if (word.isEmpty) return word;

    String result = word;
    
    // 長音符「ー」の前の文字に基づいて適切な文字に変換
    for (int i = 0; i < result.length; i++) {
      if (result[i] == 'ー' && i > 0) {
        String prevChar = result[i - 1];
        String replacement = _getLongVowelReplacement(prevChar);
        result = result.replaceRange(i, i + 1, replacement);
      }
    }

    return result;
  }

  /// 長音符の前の文字に基づいて適切な文字を返す
  String _getLongVowelReplacement(String prevChar) {
    // 拗音の場合は対応する母音を返す
    if (prevChar == 'ゃ') return 'あ';
    if (prevChar == 'ゅ') return 'う';
    if (prevChar == 'ょ') return 'お';
    
    // あ段の文字の場合は「あ」に
    if ('かがさざただなはばぱまやらわ'.contains(prevChar)) return 'あ';
    // い段の文字の場合は「い」に
    if ('きぎしじちぢにひびぴみりゐ'.contains(prevChar)) return 'い';
    // う段の文字の場合は「う」に
    if ('くぐすずつづぬふぶぷむゆる'.contains(prevChar)) return 'う';
    // え段の文字の場合は「え」に
    if ('けげせぜてでねへべぺめれゑ'.contains(prevChar)) return 'え';
    // お段の文字の場合は「お」に
    if ('こごそぞとどのほぼぽもよろを'.contains(prevChar)) return 'お';
    // 母音の場合はそのまま
    if ('あいうえお'.contains(prevChar)) return prevChar;
    
    // デフォルトは「あ」
    return 'あ';
  }
  
  /// 使用可能な単語を取得（既出単語を除外）
  List<String> getAvailableWords(String char, Set<String> usedWords) {
    final allWords = getWordsStartingWith(char);
    return allWords.where((word) => !usedWords.contains(word)).toList();
  }
  
  /// 辞書の統計情報を取得
  Map<String, int> getDictionaryStats() {
    final stats = <String, int>{};
    _dictionary.forEach((char, words) {
      stats[char] = words.length;
    });
    return stats;
  }
  
  /// 辞書がロードされているかチェック
  bool get isLoaded => _isLoaded;
  
  /// 辞書の総単語数を取得
  int get totalWordCount {
    return _dictionary.values.fold(0, (sum, words) => sum + words.length);
  }
  
  /// 正確なしりとりルールに基づく最後の文字を取得
  String getLastCharForShiritori(String word) {
    if (word.isEmpty) return '';

    // カタカナをひらがなに変換
    String normalizedWord = _normalizeWord(word);
    if (normalizedWord.isEmpty) return '';

    // 最後の文字を取得
    String lastChar = normalizedWord[normalizedWord.length - 1];

    // 長音符「ー」の場合は、その前の文字を返す（母音変換はしない）
    if (lastChar == 'ー' && normalizedWord.length >= 2) {
      lastChar = normalizedWord[normalizedWord.length - 2];
    }

    // 小文字（拗音・促音）を大文字に変換
    lastChar = _normalizeSmallKana(lastChar);

    return lastChar;
  }

  /// 小文字（拗音・促音）を大文字に変換
  String _normalizeSmallKana(String char) {
    const smallToLarge = {
      'ゃ': 'や',
      'ゅ': 'ゆ',
      'ょ': 'よ',
      'ぁ': 'あ',
      'ぃ': 'い',
      'ぅ': 'う',
      'ぇ': 'え',
      'ぉ': 'お',
      'ゎ': 'わ',
      'っ': 'つ',
    };
    return smallToLarge[char] ?? char;
  }

  /// 文字の母音を取得（長音符対応）
  String _getVowelFromChar(String char) {
    // あ段
    if ('かがさざただなはばぱまやらわ'.contains(char)) return 'あ';
    // い段
    if ('きぎしじちぢにひびぴみりゐ'.contains(char)) return 'い';
    // う段
    if ('くぐすずつづぬふぶぷむゆる'.contains(char)) return 'う';
    // え段
    if ('けげせぜてでねへべぺめれゑ'.contains(char)) return 'え';
    // お段
    if ('こごそぞとどのほぼぽもよろを'.contains(char)) return 'お';
    // 既に母音の場合
    if ('あいうえお'.contains(char)) return char;
    return char;
  }

  /// しりとりで許可される開始文字のリストを取得（濁音・半濁音を含む）
  List<String> getAllowedStartingChars(String baseChar) {
    // 濁音・半濁音のバリエーションマップ
    const dakutenVariations = {
      // か行
      'か': ['か', 'が'],
      'き': ['き', 'ぎ'],
      'く': ['く', 'ぐ'],
      'け': ['け', 'げ'],
      'こ': ['こ', 'ご'],
      // さ行
      'さ': ['さ', 'ざ'],
      'し': ['し', 'じ'],
      'す': ['す', 'ず'],
      'せ': ['せ', 'ぜ'],
      'そ': ['そ', 'ぞ'],
      // た行
      'た': ['た', 'だ'],
      'ち': ['ち', 'ぢ'],
      'つ': ['つ', 'づ'],
      'て': ['て', 'で'],
      'と': ['と', 'ど'],
      // は行
      'は': ['は', 'ば', 'ぱ'],
      'ひ': ['ひ', 'び', 'ぴ'],
      'ふ': ['ふ', 'ぶ', 'ぷ'],
      'へ': ['へ', 'べ', 'ぺ'],
      'ほ': ['ほ', 'ぼ', 'ぽ'],
    };

    // 逆マップ（濁音・半濁音から清音へ）
    const reverseDakuten = {
      // か行
      'が': 'か', 'ぎ': 'き', 'ぐ': 'く', 'げ': 'け', 'ご': 'こ',
      // さ行
      'ざ': 'さ', 'じ': 'し', 'ず': 'す', 'ぜ': 'せ', 'ぞ': 'そ',
      // た行
      'だ': 'た', 'ぢ': 'ち', 'づ': 'つ', 'で': 'て', 'ど': 'と',
      // は行（濁音）
      'ば': 'は', 'び': 'ひ', 'ぶ': 'ふ', 'べ': 'へ', 'ぼ': 'ほ',
      // は行（半濁音）
      'ぱ': 'は', 'ぴ': 'ひ', 'ぷ': 'ふ', 'ぺ': 'へ', 'ぽ': 'ほ',
    };

    // 濁音・半濁音の場合は清音に変換
    final normalizedBase = reverseDakuten[baseChar] ?? baseChar;

    // バリエーションを返す（なければ元の文字のみ）
    return dakutenVariations[normalizedBase] ?? [baseChar];
  }


  /// 頭文字の互換性をチェック（濁音・半濁音の違いを許容）
  bool _isCompatibleHeadChar(String actual, String expected) {
    // 完全一致の場合
    if (actual == expected) return true;
    
    // 濁音・半濁音の互換性チェック
    final compatibilityMap = {
      // は行
      'は': ['ば', 'ぱ'], 'ひ': ['び', 'ぴ'], 'ふ': ['ぶ', 'ぷ'], 'へ': ['べ', 'ぺ'], 'ほ': ['ぼ', 'ぽ'],
      'ば': ['は', 'ぱ'], 'び': ['ひ', 'ぴ'], 'ぶ': ['ふ', 'ぷ'], 'べ': ['へ', 'ぺ'], 'ぼ': ['ほ', 'ぽ'],
      'ぱ': ['は', 'ば'], 'ぴ': ['ひ', 'び'], 'ぷ': ['ふ', 'ぶ'], 'ぺ': ['へ', 'べ'], 'ぽ': ['ほ', 'ぼ'],
      
      // か行
      'か': ['が'], 'き': ['ぎ'], 'く': ['ぐ'], 'け': ['げ'], 'こ': ['ご'],
      'が': ['か'], 'ぎ': ['き'], 'ぐ': ['く'], 'げ': ['け'], 'ご': ['こ'],
      
      // さ行
      'さ': ['ざ'], 'し': ['じ'], 'す': ['ず'], 'せ': ['ぜ'], 'そ': ['ぞ'],
      'ざ': ['さ'], 'じ': ['し'], 'ず': ['す'], 'ぜ': ['せ'], 'ぞ': ['そ'],
      
      // た行
      'た': ['だ'], 'ち': ['ぢ'], 'つ': ['づ'], 'て': ['で'], 'と': ['ど'],
      'だ': ['た'], 'ぢ': ['ち'], 'づ': ['つ'], 'で': ['て'], 'ど': ['と'],
    };
    
    final compatibleChars = compatibilityMap[expected] ?? [];
    return compatibleChars.contains(actual);
  }

  /// ランダムな初期単語を取得（「ん」で終わらない単語のみ）
  String getRandomStartingWord() {
    if (!_isLoaded || _dictionary.isEmpty) {
      return 'しりとり'; // フォールバック
    }

    // 「ん」で終わらない単語を持つ文字リスト
    final validChars = _dictionary.keys.where((char) {
      final words = _dictionary[char] ?? [];
      return words.any((word) => !word.endsWith('ん') && word.length >= 2);
    }).toList();

    if (validChars.isEmpty) {
      return 'しりとり'; // フォールバック
    }

    // ランダムな文字を選択
    final random = DateTime.now().millisecondsSinceEpoch;
    final randomChar = validChars[random % validChars.length];

    // その文字で始まる「ん」で終わらない単語リスト
    final validWords = (_dictionary[randomChar] ?? [])
        .where((word) => !word.endsWith('ん') && word.length >= 2)
        .toList();

    if (validWords.isEmpty) {
      return 'しりとり'; // フォールバック
    }

    // ランダムな単語を選択
    return validWords[random % validWords.length];
  }
}
