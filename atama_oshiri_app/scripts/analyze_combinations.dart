import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 組み合わせ分析開始...');
  
  // 開始文字リスト（「ゐ」「を」を除外）
  final startChars = [
    'あ', 'い', 'う', 'え', 'お',
    'か', 'き', 'く', 'け', 'こ',
    'さ', 'し', 'す', 'せ', 'そ',
    'た', 'ち', 'つ', 'て', 'と',
    'な', 'に', 'ぬ', 'ね', 'の',
    'は', 'ひ', 'ふ', 'へ', 'ほ',
    'ま', 'み', 'む', 'め', 'も',
    'や', 'ゆ', 'よ',
    'ら', 'り', 'る', 'れ', 'ろ',
    'わ'
  ];
  
  // 終了文字リスト（「ん」を除外）
  final endChars = [
    'あ', 'い', 'う', 'え', 'お',
    'か', 'き', 'く', 'け', 'こ',
    'さ', 'し', 'す', 'せ', 'そ',
    'た', 'ち', 'つ', 'て', 'と',
    'な', 'に', 'ぬ', 'ね', 'の',
    'は', 'ひ', 'ふ', 'へ', 'ほ',
    'ま', 'み', 'む', 'め', 'も',
    'や', 'ゆ', 'よ',
    'ら', 'り', 'る', 'れ', 'ろ',
    'わ'
  ];
  
  final validCombinations = <String, int>{};
  final invalidCombinations = <String>[];
  
  // 各組み合わせをチェック
  for (final startChar in startChars) {
    for (final endChar in endChars) {
      final combination = '$startChar-$endChar';
      final count = await countValidWords(startChar, endChar);
      
      if (count >= 10) {
        validCombinations[combination] = count;
        print('✅ $combination: $count個の回答例');
      } else {
        invalidCombinations.add(combination);
        if (count > 0) {
          print('⚠️  $combination: $count個の回答例（不足）');
        }
      }
    }
  }
  
  print('\n📊 分析結果:');
  print('有効な組み合わせ: ${validCombinations.length}個');
  print('無効な組み合わせ: ${invalidCombinations.length}個');
  
  // 有効な組み合わせをファイルに保存
  final validFile = File('valid_combinations.json');
  await validFile.writeAsString(jsonEncode(validCombinations));
  
  print('\n💾 有効な組み合わせを valid_combinations.json に保存しました');
}

Future<int> countValidWords(String startChar, String endChar) async {
  try {
    // 開始文字の辞書ファイルを読み込み
    final file = File('assets/dictionary/char_$startChar.json');
    if (!await file.exists()) return 0;
    
    final content = await file.readAsString();
    final words = List<String>.from(jsonDecode(content));
    
    int count = 0;
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // 終了文字をチェック（長音符対応）
      final lastChar = getLastCharForShiritori(word);
      if (lastChar == endChar) {
        count++;
      }
    }
    
    return count;
  } catch (e) {
    return 0;
  }
}

String getLastCharForShiritori(String word) {
  if (word.isEmpty) return '';
  
  // 長音符「ー」の場合は、その前の文字を返す
  String lastChar = word[word.length - 1];
  if (lastChar == 'ー' && word.length >= 2) {
    lastChar = word[word.length - 2];
  }
  
  // 小文字（拗音・促音）を大文字に変換
  const smallToLarge = {
    'ゃ': 'や', 'ゅ': 'ゆ', 'ょ': 'よ',
    'ぁ': 'あ', 'ぃ': 'い', 'ぅ': 'う', 'ぇ': 'え', 'ぉ': 'お',
    'ゎ': 'わ', 'っ': 'つ',
  };
  
  return smallToLarge[lastChar] ?? lastChar;
}
