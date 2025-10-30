import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:jp_transliterate/jp_transliterate.dart';

/// 音声認識サービス
class SpeechService {
  static SpeechService? _instance;
  static SpeechService get instance => _instance ??= SpeechService._();
  
  SpeechService._();
  
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _intermediateText = ''; // 中間結果を保存
  
  // コールバック
  Function(String)? onResult;
  Function(String)? onError;
  Function(String)? onStatus;
  VoidCallback? onListeningStarted;
  VoidCallback? onListeningStopped;
  
  // 自動送信機能
  bool _autoSubmit = false;
  Timer? _autoSubmitTimer;
  Duration _autoSubmitDelay = Duration(seconds: 2);
  
  /// 音声認識の初期化
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ 音声認識は既に初期化済み');
      return true;
    }
    
    print('🎤 音声認識の初期化を開始...');
    
    try {
      // マイク権限の確認
      print('🎤 マイク権限を確認中...');
      final permission = await Permission.microphone.request();
      print('🎤 マイク権限状態: ${permission.toString()}');
      
      if (!permission.isGranted) {
        print('❌ マイクの権限が許可されていません');
        print('⚠️ シミュレーターではマイク権限が制限される場合があります');
        print('💡 実機でテストするか、シミュレーターのマイク設定を確認してください');
        onError?.call('マイクの権限が許可されていません');
        // 権限が拒否されても音声認識ライブラリの初期化は試行
      } else {
        print('✅ マイク権限が許可されました');
      }
      
      // 音声認識の初期化
      print('🎤 音声認識ライブラリを初期化中...');
      print('🎤 実機での音声認識精度を最適化します');
      
      // 利用可能なロケールを確認
      final locales = await _speech.locales();
      print('🎤 利用可能なロケール数: ${locales.length}');
      final japaneseLocales = locales.where((locale) => locale.localeId.startsWith('ja')).toList();
      print('🎤 日本語ロケール: ${japaneseLocales.map((l) => l.localeId).join(', ')}');
      
      final available = await _speech.initialize(
        onError: (error) {
          print('❌ 音声認識エラー: ${error.errorMsg}');
          print('💡 シミュレーターでは音声認識が制限される場合があります');
          
          // シミュレーター環境での特別なエラーハンドリング
          _isRunningOnSimulator().then((isSimulator) {
            if (isSimulator) {
              print('📱 シミュレーター環境での音声認識エラー');
              print('💡 実機でのテストを強く推奨します');
              onError?.call('シミュレーターでは音声認識が制限されています。実機でテストしてください。');
            } else {
              onError?.call('音声認識エラー: ${error.errorMsg}');
            }
          });
        },
        onStatus: (status) {
          print('🎤 音声認識ステータス: $status');
          // 外部のonStatusコールバックを呼び出す
          onStatus?.call(status);

          // 状態管理を安定化
          if (status == 'listening') {
            if (!_isListening) {
              _isListening = true;
              onListeningStarted?.call();
            }
          } else if (status == 'notListening' || status == 'done') {
            if (_isListening) {
              _isListening = false;
              onListeningStopped?.call();
            }
          }
        },
      );
      
      print('🎤 音声認識ライブラリ初期化結果: $available');
      
      if (available) {
        _isInitialized = true;
        print('音声認識が初期化されました');
        return true;
      } else {
        onError?.call('音声認識が利用できません');
        return false;
      }
    } catch (e) {
      print('音声認識初期化エラー: $e');
      onError?.call('音声認識の初期化に失敗しました');
      return false;
    }
  }
  
  /// 音声認識を開始
  Future<void> startListening({Duration? timeout, String? expectedHead}) async {
    if (!_isInitialized) {
      print('❌ 音声認識が初期化されていません');
      onError?.call('音声認識が初期化されていません');
      return;
    }
    
    if (_isListening) {
      print('🎤 既に音声認識中です');
      return;
    }
    
    try {
      print('🎤 音声認識を開始します（タイムアウト: ${timeout?.inSeconds ?? 5}秒）');
      if (expectedHead != null) {
        print('🎤 期待される頭文字: "$expectedHead"');
      }
      print('🎤 デバイス上音声認識を使用（シミュレーター対応）');
      print('💡 実機でのテストを推奨します');
      
      // 環境に応じた音声認識設定を最適化
      final isSimulator = await _isRunningOnSimulator();
      if (isSimulator) {
        print('📱 シミュレーター環境を検出しました。音声認識設定を最適化します');
        print('⚠️ シミュレーターでは音声認識が制限される場合があります');
        print('💡 実機でのテストを強く推奨します');
      } else {
        print('📱 実機環境を検出しました。音声認識精度を最適化します');
        print('💡 実機ではより長い認識時間と詳細な設定を使用します');
      }
      
      // UIの表示時間と完全に一致させる
      final listenDuration = timeout ?? Duration(seconds: 5);

      // pauseForはlistenForと同じに設定して、UIの表示時間と完全に一致させる
      // これにより、プライバシーの観点から正確な時間管理を実現
      final pauseDuration = listenDuration;
      
      await _speech.listen(
        onResult: (result) {
          print('認識候補数: ${result.alternates.length}, 最終結果: ${result.finalResult}');
          print('🎤 メイン結果: "${result.recognizedWords}"');
          print('🎤 全候補を詳細表示:');
          for (int i = 0; i < result.alternates.length; i++) {
            print('  候補${i + 1}: "${result.alternates[i].recognizedWords}" (信頼度: ${result.alternates[i].confidence})');
          }
          
          // 音声認識の結果をそのまま使用（デバッグ用の候補選択は削除）
          final selectedText = result.recognizedWords;
          
          if (selectedText.isNotEmpty) {
            if (result.finalResult) {
              print('✅ 最終結果を処理します');
              _recognizedText = selectedText;
            } else {
              print('⏳ 中間結果を処理します（リアルタイム表示）');
              _intermediateText = selectedText;
              _recognizedText = selectedText; // 中間結果も表示（言い直しの場合は上書き）
            }
            
            print('認識結果: $_recognizedText');
            
            // ひらがな変換（必要に応じて）
            _convertToHiragana(_recognizedText).then((hiraganaText) {
              print('🎤 音声認識結果（ひらがな変換後）: $hiraganaText');
              
              // ひらがな変換後の結果をコールバック（中間結果も含む）
              print('🎤 [SpeechService] onResultコールバックを呼び出します: $hiraganaText');
              print('🎤 [SpeechService] onResultプロパティ: ${onResult != null ? "設定済み" : "null"}');
              onResult?.call(hiraganaText);
            });
          }
        },
        listenFor: listenDuration,
        pauseFor: pauseDuration,
        partialResults: true,
        localeId: 'ja_JP',
        onDevice: !isSimulator, // シミュレーターではオンデバイス認識を無効化
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        listenOptions: SpeechListenOptions(
          enableHapticFeedback: false,
          autoPunctuation: false,
        ),
        onSoundLevelChange: (level) {
          // 音声レベル変化の処理（必要に応じて）
          if (isSimulator) {
            print('🔊 音声レベル: $level (シミュレーター)');
          }
        },
      );
    } catch (e) {
      print('音声認識開始エラー: $e');
      onError?.call('音声認識の開始に失敗しました');
      
      // シミュレーター環境での特別なエラーハンドリング
      final isSimulator = await _isRunningOnSimulator();
      if (isSimulator) {
        print('📱 シミュレーター環境での音声認識エラー');
        print('💡 実機でのテストを強く推奨します');
        onError?.call('シミュレーターでは音声認識が制限されています。実機でテストしてください。');
      } else {
        print('📱 実機環境での音声認識エラー');
        onError?.call('音声認識に失敗しました。もう一度お試しください。');
      }
    }
  }
  
  /// シミュレーター環境かどうかを判定
  Future<bool> _isRunningOnSimulator() async {
    try {
      // iOSシミュレーターの判定
      final result = await _speech.locales();
      // シミュレーターでは利用可能なロケールが限定的
      return result.length < 5; // 通常の実機では10以上のロケールが利用可能
    } catch (e) {
      print('📱 シミュレーター判定エラー: $e');
      return true; // エラー時はシミュレーターと仮定
    }
  }
  
  /// シミュレーター環境でのフォールバック機能
  /// 音声認識が利用できない場合の代替手段を提供
  Future<String?> showSimulatorFallbackDialog(BuildContext context) async {
    if (!await _isRunningOnSimulator()) {
      return null; // 実機ではフォールバック機能は不要
    }
    
    print('📱 シミュレーター環境でのフォールバック機能を表示');
    
    // テキスト入力用のコントローラー
    final textController = TextEditingController();
    
    // 簡単なテキスト入力ダイアログを表示
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('音声認識の代替入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('シミュレーターでは音声認識が制限されています。'),
            const SizedBox(height: 16),
            const Text('手動で回答を入力してください：'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ひらがなで入力してください',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(textController.text);
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      print('📱 フォールバック入力: "$result"');
      // ひらがな変換を適用
      final hiraganaResult = await _convertToHiragana(result);
      return hiraganaResult;
    }
    
    return null;
  }
  
  // フォールバック機能は完全に削除しました
  
  /// 音声認識を停止
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      print('音声認識停止エラー: $e');
      onError?.call('音声認識の停止に失敗しました');
    }
  }

  /// 音声認識をキャンセル
  Future<void> cancel() async {
    try {
      await _speech.cancel();
      _isListening = false;
      _recognizedText = '';
      _intermediateText = '';
    } catch (e) {
      print('音声認識キャンセルエラー: $e');
      onError?.call('音声認識のキャンセルに失敗しました');
    }
  }

  /// 音声認識を完全にリセット（連続使用時に推奨）
  Future<void> reset() async {
    print('🔄 音声認識を完全にリセット');
    try {
      // 1. 停止を試みる
      if (_isListening) {
        await _speech.stop();
      }

      // 2. キャンセルしてリソースを解放
      await _speech.cancel();

      // 3. 内部状態をクリア
      _isListening = false;
      _recognizedText = '';
      _intermediateText = '';
      _autoSubmitTimer?.cancel();

      // 4. 少し待機してリソースが完全に解放されるのを待つ（短縮）
      await Future.delayed(const Duration(milliseconds: 200));

      print('✅ 音声認識リセット完了');
    } catch (e) {
      print('⚠️ 音声認識リセットエラー: $e');
    }
  }
  
  /// ひらがなへの変換（基本版）
  Future<String> _convertToHiragana(String text) async {
    if (text.isEmpty) return text;
    
    try {
      print('🔄 ひらがな変換開始: "$text"');
      
      // 1. ひらがなのみの場合はそのまま返す
      if (_isHiraganaOnly(text)) {
        print('✅ ひらがなのみのため変換をスキップ: "$text"');
        return text;
      }
      
      // 2. カタカナをひらがなに変換
      String result = _convertKatakanaToHiragana(text);
      
      // 3. 漢字をひらがなに変換
      result = await _convertKanjiToHiragana(result);
      
      // 4. ひらがなと伸ばし棒のみを抽出（伸ばし棒は保持）
      result = result.replaceAll(RegExp(r'[^あ-んー]'), '');
      
      // 5. 伸ばし棒の位置をチェック（最後の伸ばし棒は保持）
      if (result.endsWith('ー')) {
        print('✅ 最後の伸ばし棒を保持: "$result"');
      }
      
      // 6. 伸ばし棒が不適切に変換されていないかチェック
      if (text.contains('ー')) {
        final vowels = ['あ', 'い', 'う', 'え', 'お'];
        bool hasInappropriateConversion = false;
        for (String vowel in vowels) {
          if (result.contains(vowel) && !text.contains(vowel)) {
            hasInappropriateConversion = true;
            break;
          }
        }
        if (hasInappropriateConversion) {
          print('⚠️ 伸ばし棒の不適切な変換を検出、元のテキストを使用');
          return text; // 元のテキストを返す
        }
      }
      
      print('✅ ひらがな変換完了: "$text" → "$result"');
      return result;
    } catch (e) {
      print('❌ ひらがな変換エラー: $e');
      // エラー時は元のテキストからひらがなと伸ばし棒のみ抽出
      String fallback = text.replaceAll(RegExp(r'[^あ-んー]'), '');
      print('フォールバック変換: "$text" → "$fallback"');
      return fallback;
    }
  }
  
  /// ローマ字からひらがなへの変換
  String _convertRomajiToHiragana(String romaji) {
    if (romaji.isEmpty) return '';
    
    // ローマ字を小文字に統一
    String input = romaji.toLowerCase().trim();
    
    // ローマ字→ひらがな変換マップ
    final romajiMap = {
      // あ行
      'a': 'あ', 'i': 'い', 'u': 'う', 'e': 'え', 'o': 'お',
      'aa': 'ああ', 'ii': 'いい', 'uu': 'うう', 'ee': 'ええ', 'oo': 'おお',
      
      // か行
      'ka': 'か', 'ki': 'き', 'ku': 'く', 'ke': 'け', 'ko': 'こ',
      'ga': 'が', 'gi': 'ぎ', 'gu': 'ぐ', 'ge': 'げ', 'go': 'ご',
      'kya': 'きゃ', 'kyu': 'きゅ', 'kyo': 'きょ',
      'gya': 'ぎゃ', 'gyu': 'ぎゅ', 'gyo': 'ぎょ',
      
      // さ行
      'sa': 'さ', 'si': 'し', 'shi': 'し', 'su': 'す', 'se': 'せ', 'so': 'そ',
      'za': 'ざ', 'zi': 'じ', 'ji': 'じ', 'zu': 'ず', 'ze': 'ぜ', 'zo': 'ぞ',
      'sha': 'しゃ', 'shu': 'しゅ', 'sho': 'しょ',
      'ja': 'じゃ', 'ju': 'じゅ', 'jo': 'じょ',
      'sya': 'しゃ', 'syu': 'しゅ', 'syo': 'しょ',
      'jya': 'じゃ', 'jyu': 'じゅ', 'jyo': 'じょ',
      
      // た行
      'ta': 'た', 'ti': 'ち', 'chi': 'ち', 'tu': 'つ', 'tsu': 'つ', 'te': 'て', 'to': 'と',
      'da': 'だ', 'di': 'ぢ', 'du': 'づ', 'de': 'で', 'do': 'ど',
      'cha': 'ちゃ', 'chu': 'ちゅ', 'cho': 'ちょ',
      'tya': 'ちゃ', 'tyu': 'ちゅ', 'tyo': 'ちょ',
      
      // な行
      'na': 'な', 'ni': 'に', 'nu': 'ぬ', 'ne': 'ね', 'no': 'の',
      'nya': 'にゃ', 'nyu': 'にゅ', 'nyo': 'にょ',
      
      // は行
      'ha': 'は', 'hi': 'ひ', 'fu': 'ふ', 'he': 'へ', 'ho': 'ほ',
      'ba': 'ば', 'bi': 'び', 'bu': 'ぶ', 'be': 'べ', 'bo': 'ぼ',
      'pa': 'ぱ', 'pi': 'ぴ', 'pu': 'ぷ', 'pe': 'ぺ', 'po': 'ぽ',
      'hya': 'ひゃ', 'hyu': 'ひゅ', 'hyo': 'ひょ',
      'bya': 'びゃ', 'byu': 'びゅ', 'byo': 'びょ',
      'pya': 'ぴゃ', 'pyu': 'ぴゅ', 'pyo': 'ぴょ',
      
      // ま行
      'ma': 'ま', 'mi': 'み', 'mu': 'む', 'me': 'め', 'mo': 'も',
      'mya': 'みゃ', 'myu': 'みゅ', 'myo': 'みょ',
      
      // や行
      'ya': 'や', 'yu': 'ゆ', 'yo': 'よ',
      
      // ら行
      'ra': 'ら', 'ri': 'り', 'ru': 'る', 're': 'れ', 'ro': 'ろ',
      'rya': 'りゃ', 'ryu': 'りゅ', 'ryo': 'りょ',
      
      // わ行
      'wa': 'わ', 'wi': 'ゐ', 'we': 'ゑ', 'wo': 'を', 'n': 'ん',
      
      // 長音
      'aa': 'ああ', 'ii': 'いい', 'uu': 'うう', 'ee': 'ええ', 'oo': 'おお',
      'ou': 'おう', 'ei': 'えい',
    };
    
    // 特殊な組み合わせを先に処理
    String result = input;
    
    // 長音記号の処理
    result = result.replaceAllMapped(RegExp(r'([aiueo])\1'), (match) => match.group(1)! + match.group(1)!); // 同じ母音の連続
    result = result.replaceAllMapped(RegExp(r'([aiueo])u'), (match) => match.group(1)! + 'う'); // ou → おう
    result = result.replaceAllMapped(RegExp(r'([aiueo])i'), (match) => match.group(1)! + 'い'); // ei → えい
    
    // 長い組み合わせから順番に変換（優先度順）
    final sortedEntries = romajiMap.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    
    for (final entry in sortedEntries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    // 残った英字を除去
    result = result.replaceAll(RegExp(r'[a-zA-Z]'), '');
    
    // 空の場合は元のテキストを返す
    if (result.isEmpty) {
      return '';
    }
    
    return result;
  }
  
  /// 不適切な変換をチェック
  bool _isInappropriateConversion(String original, String converted) {
    // 長音記号「ー」が「あいうえお」のどれかに変換される問題をチェック
    if (original.contains('ー')) {
      // 元のテキストに「あいうえお」が含まれていないのに、変換結果に含まれている場合は不適切
      final vowels = ['あ', 'い', 'う', 'え', 'お'];
      for (String vowel in vowels) {
        if (converted.contains(vowel) && !original.contains(vowel)) {
          print('⚠️ 不適切な変換を検出: 「ー」が「$vowel」に変換されました');
          return true;
        }
      }
    }
    
    // その他の不適切な変換パターンをチェック
    // 例: 「っ」が「つ」に変換される問題など
    if (original.contains('っ') && converted.contains('つ') && !original.contains('つ')) {
      return true;
    }
    
    return false;
  }

  /// 漢字をひらがなに変換（包括版）
  Future<String> _convertKanjiToHiragana(String text) async {
    try {
      // jp_transliterateライブラリを使用して漢字→ひらがな変換を試行
      final result = await JpTransliterate.transliterate(kanji: text);
      if (result.hiragana.isNotEmpty && result.hiragana != text) {
        print('📚 jp_transliterate変換: "$text" → "${result.hiragana}"');
        
        // 不適切な変換をチェック（長音記号「ー」が「あ」に変換される問題を防ぐ）
        if (_isInappropriateConversion(text, result.hiragana)) {
          print('⚠️ 不適切な変換を検出: "${result.hiragana}" → 元のテキストを使用');
          return text;
        }
        
        return result.hiragana;
      }
    } catch (e) {
      print('⚠️ jp_transliterate変換エラー: $e');
    }
    
    // フォールバック: カスタム辞書を使用
    final kanjiMap = {
      // 音声認識でよく使われる単語の正確な変換
      'クラッカー': 'くらっかー',
      'クラッカ': 'くらっかー',
      'クラ': 'くら',
      
      '仁': 'じん',
      '義': 'ぎ',
      '人': 'じん',
      '気': 'き',
      '心': 'しん',
      '愛': 'あい',
      '美': 'び',
      '和': 'わ',
      '正': 'せい',
      '善': 'ぜん',
      '悪': 'あく',
      '強': 'きょう',
      '弱': 'じゃく',
      '大': 'だい',
      '小': 'しょう',
      '高': 'こう',
      '低': 'てい',
      '新': 'しん',
      '古': 'こ',
      '明': 'めい',
      '暗': 'あん',
      '削': 'さく',
      '除': 'じょ',
      '雪': 'ゆき',
      '石': 'いし',
      '器': 'き',
      '木': 'き',
      '花': 'はな',
      '草': 'くさ',
      '山': 'やま',
      '川': 'かわ',
      '海': 'うみ',
      '空': 'そら',
      '風': 'かぜ',
      '雨': 'あめ',
      '星': 'ほし',
      '月': 'つき',
      '暇': 'ひま',
      '青': 'あお',
      '赤': 'あか',
      
      // 魚介類
      '鱈': 'たら',
      '鰯': 'いわし',
      '鯖': 'さば',
      '鮪': 'まぐろ',
      '鰤': 'ぶり',
      '鯛': 'たい',
      '鰹': 'かつお',
      '鮭': 'さけ',
      '鱒': 'ます',
      '鰻': 'うなぎ',
      '蛸': 'たこ',
      '烏賊': 'いか',
      '海老': 'えび',
      '蟹': 'かに',
      '蛤': 'はまぐり',
      '鮑': 'あわび',
      
      // 動物
      '犬': 'いぬ',
      '猫': 'ねこ',
      '象': 'ぞう',
      '虎': 'とら',
      '熊': 'くま',
      '狼': 'おおかみ',
      '狐': 'きつね',
      '狸': 'たぬき',
      '兎': 'うさぎ',
      '鼠': 'ねずみ',
      '猿': 'さる',
      '馬': 'うま',
      '牛': 'うし',
      '豚': 'ぶた',
      '羊': 'ひつじ',
      '鳥': 'とり',
      '鷹': 'たか',
      '鷲': 'わし',
      '鶴': 'つる',
      '雀': 'すずめ',
      '鳩': 'はと',
      '鴉': 'からす',
      '鴨': 'かも',
      '鶏': 'にわとり',
      '竜': 'りゅう',
      '龍': 'りゅう',
      '鹿': 'しか',
      
      // 食べ物
      '林檎': 'りんご',
      '蜜柑': 'みかん',
      '葡萄': 'ぶどう',
      '桃': 'もも',
      '梨': 'なし',
      '柿': 'かき',
      '栗': 'くり',
      '苺': 'いちご',
      '西瓜': 'すいか',
      '南瓜': 'かぼちゃ',
      '茄子': 'なす',
      '胡瓜': 'きゅうり',
      '人参': 'にんじん',
      '大根': 'だいこん',
      '玉葱': 'たまねぎ',
      '馬鈴薯': 'じゃがいも',
      '薩摩芋': 'さつまいも',
      '牛蒡': 'ごぼう',
      '筍': 'たけのこ',
      '蓮根': 'れんこん',
      '椎茸': 'しいたけ',
      '松茸': 'まつたけ',
      '太陽': 'たいよう',
      '地球': 'ちきゅう',
      '世界': 'せかい',
      '日本': 'にほん',
      '東京': 'とうきょう',
      '大阪': 'おおさか',
      '京都': 'きょうと',
      '学校': 'がっこう',
      '先生': 'せんせい',
      '学生': 'がくせい',
      '友達': 'ともだち',
      '家族': 'かぞく',
      '父': 'ちち',
      '母': 'はは',
      '兄': 'あに',
      '姉': 'あね',
      '弟': 'おとうと',
      '妹': 'いもうと',
      '子供': 'こども',
      '大人': 'おとな',
      '老人': 'ろうじん',
      '男': 'おとこ',
      '女': 'おんな',
      '人': 'ひと',
      '動物': 'どうぶつ',
      '犬': 'いぬ',
      '猫': 'ねこ',
      '鳥': 'とり',
      '魚': 'さかな',
      '虫': 'むし',
      '車': 'くるま',
      '電車': 'でんしゃ',
      '飛行機': 'ひこうき',
      '船': 'ふね',
      '自転車': 'じてんしゃ',
      '歩く': 'あるく',
      '走る': 'はしる',
      '泳ぐ': 'およぐ',
      '飛ぶ': 'とぶ',
      '食べる': 'たべる',
      '飲む': 'のむ',
      '見る': 'みる',
      '聞く': 'きく',
      '話す': 'はなす',
      '読む': 'よむ',
      '書く': 'かく',
      '勉強': 'べんきょう',
      '仕事': 'しごと',
      '遊ぶ': 'あそぶ',
      '寝る': 'ねる',
      '起きる': 'おきる',
      '座る': 'すわる',
      '立つ': 'たつ',
      '裏': 'うら', '表': 'おもて', '裏表': 'うらおもて',
    };
    
    String result = text;
    for (final entry in kanjiMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    // 漢字が残っている場合は、強制的にひらがなのみに変換
    if (result.contains(RegExp(r'[\u4e00-\u9faf]'))) {
      // 漢字が含まれている場合は、ひらがなとカタカナのみを抽出
      result = result.replaceAll(RegExp(r'[^あ-んー]'), '');
      print('漢字→ひらがな変換（強制）: "$text" → "$result"');
    } else {
      print('漢字→ひらがな変換: "$text" → "$result"');
    }
    
    return result;
  }
  
  /// ひらがな、カタカナ、または漢字かチェック
  bool _isHiraganaOrKatakana(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // ひらがな、カタカナ、漢字、伸ばし棒以外の文字が含まれている場合は false
      if (!((code >= 0x3041 && code <= 0x3096) || // ひらがな
            (code >= 0x30A1 && code <= 0x30F6) || // カタカナ
            (code >= 0x4E00 && code <= 0x9FFF) || // 基本漢字
            (code >= 0x3400 && code <= 0x4DBF) || // 拡張A漢字
            code == 0x30FC)) { // 伸ばし棒
        return false;
      }
    }
    return true;
  }

  /// ひらがなのみかチェック
  bool _isHiraganaOnly(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (!((code >= 0x3041 && code <= 0x3096) || // ひらがな
            code == 0x30FC)) { // 伸ばし棒
        return false;
      }
    }
    return true;
  }

  /// カタカナのみかチェック
  bool _isKatakanaOnly(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (!((code >= 0x30A1 && code <= 0x30F6) || // カタカナ
            code == 0x30FC)) { // 伸ばし棒
        return false;
      }
    }
    return true;
  }

  /// 漢字が含まれているかチェック
  bool _containsKanji(String text) {
    if (text.isEmpty) return false;
    
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if ((code >= 0x4E00 && code <= 0x9FFF) || // 基本漢字
          (code >= 0x3400 && code <= 0x4DBF)) { // 拡張A漢字
        return true;
      }
    }
    return false;
  }
  
  /// ローマ字テキストかどうかを判定
  bool _isRomajiText(String text) {
    if (text.isEmpty) return false;
    
    // 英字のみかどうかをチェック
    final romajiPattern = RegExp(r'^[a-zA-Z\s]+$');
    return romajiPattern.hasMatch(text);
  }
  
  /// 日本語テキストかどうかを判定（ひらがな、カタカナ、漢字）
  bool _isJapaneseText(String text) {
    if (text.isEmpty) return false;
    
    // ひらがな、カタカナ、漢字、長音符、句読点を含むパターン
    final japanesePattern = RegExp(r'^[あ-んア-ン一-龯ー、。！？\s]*$');
    return japanesePattern.hasMatch(text);
  }
  
  
  /// カタカナをひらがなに変換
  String _convertKatakanaToHiragana(String text) {
    if (text.isEmpty) return text;
    
    String result = text;
    for (int i = 0; i < result.length; i++) {
      int code = result.codeUnitAt(i);
      if (code >= 0x30A1 && code <= 0x30F6) { // カタカナの範囲
        result = result.replaceRange(i, i + 1, String.fromCharCode(code - 0x60));
      }
    }
    return result;
  }
  
  /// 現在の認識結果を取得
  Future<String> getRecognizedText() async {
    return await _convertToHiragana(_recognizedText);
  }
  
  /// 自動送信機能の設定
  void setAutoSubmit(bool enabled, {Duration? delay}) {
    _autoSubmit = enabled;
    if (delay != null) {
      _autoSubmitDelay = delay;
    }
    if (!enabled) {
      _autoSubmitTimer?.cancel();
      _autoSubmitTimer = null;
    }
  }
  
  /// 自動送信タイマーの開始
  void _startAutoSubmitTimer() {
    if (!_autoSubmit) return;
    
    _autoSubmitTimer?.cancel();
    _autoSubmitTimer = Timer(_autoSubmitDelay, () async {
      if (_recognizedText.isNotEmpty) {
        final hiraganaText = await _convertToHiragana(_recognizedText);
        onResult?.call(hiraganaText);
      }
    });
  }
  
  /// 音声認識中かどうか
  bool get isListening => _isListening;
  
  /// 自動送信が有効かどうか
  bool get isAutoSubmitEnabled => _autoSubmit;
  
  /// 音声認識が利用可能かどうか
  bool get isAvailable => _speech.isAvailable;
  
  /// 利用可能な言語を取得
  Future<List<LocaleName>> get locales async => await _speech.locales();
  
  /// 日本語ロケールが利用可能かチェック
  Future<bool> get isJapaneseAvailable async {
    final availableLocales = await locales;
    return availableLocales.any((locale) => locale.localeId.startsWith('ja'));
  }
  
  /// リソースクリーンアップ
  void dispose() {
    if (_isListening) {
      stopListening();
    }
    _autoSubmitTimer?.cancel();
    _speech.cancel();
  }
}