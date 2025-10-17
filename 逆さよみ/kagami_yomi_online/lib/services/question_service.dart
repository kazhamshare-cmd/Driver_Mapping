import 'dart:math';
import '../models/question.dart';

class QuestionService {
  static final QuestionService _instance = QuestionService._internal();
  factory QuestionService() => _instance;
  QuestionService._internal();

  final Random _random = Random();

  // レベル1: 2-3文字のランダムな組み合わせ（逆読み形式）
  final List<String> _level1Questions = [
    'まんち',  // 鏡文字: ちんま
    'おあお',  // 鏡文字: おあお（回文）
    'こおあ',  // 鏡文字: あおこ
    'きんさ',  // 鏡文字: さんき
    'はのま',  // 鏡文字: まのは
    'らしち',  // 鏡文字: ちしら
    'のきあ',  // 鏡文字: あきの
    'まおさ',  // 鏡文字: さおま
    'ちはし',  // 鏡文字: しはち
    'らきお',  // 鏡文字: おきら
    'さまの',  // 鏡文字: のまさ
    'おちあ',  // 鏡文字: あちお
    'きらは',  // 鏡文字: はらき
    'まちし',  // 鏡文字: しちま
    'のおき',  // 鏡文字: きおの
    'あはら',  // 鏡文字: らはあ
    'しさま',  // 鏡文字: ましさ
    'ちおの',  // 鏡文字: のおち
    'はきさ',  // 鏡文字: さきは
    'らまあ',  // 鏡文字: あまら
    'おしき',  // 鏡文字: きしお
    'さちの',  // 鏡文字: のちさ
    'きあは',  // 鏡文字: はあき
    'まらし',  // 鏡文字: しらま
    'のさお',  // 鏡文字: おさの
    'あちま',  // 鏡文字: まちあ
    'しおき',  // 鏡文字: きおし
    'ちさら',  // 鏡文字: らさち
    'はまの',  // 鏡文字: のまは
    'らあお',  // 鏡文字: おあら
  ];

  // レベル2: 4文字のランダムな組み合わせ（逆読み形式）
  final List<String> _level2Questions = [
    'らきさま',  // 鏡文字: まさきら
    'おちのは',  // 鏡文字: はのちお
    'きあしち',  // 鏡文字: ちしあき
    'まはおの',  // 鏡文字: のおはま
    'さらきあ',  // 鏡文字: あきらさ
    'ちのまし',  // 鏡文字: しまのち
    'はおさら',  // 鏡文字: らさおは
    'おきちあ',  // 鏡文字: あちきお
    'のしはま',  // 鏡文字: まはしの
    'あまきお',  // 鏡文字: おきまあ
    'しちさの',  // 鏡文字: のさちし
    'きらおは',  // 鏡文字: はおらき
    'まのあし',  // 鏡文字: しあのま
    'ちおきさ',  // 鏡文字: さきおち
    'らはまの',  // 鏡文字: のまはら
    'おあちき',  // 鏡文字: きちあお
    'さしのま',  // 鏡文字: まのしさ
    'はきらお',  // 鏡文字: おらきは
  ];

  // レベル3: 5文字のランダムな組み合わせ（逆読み形式）
  final List<String> _level3Questions = [
    'のまちきあ',  // 鏡文字: あきちまの
    'はおさらし',  // 鏡文字: しらさおは
    'ちきのまお',  // 鏡文字: おまのきち
    'まあしちら',  // 鏡文字: らちしあま
    'さのはきお',  // 鏡文字: おきはのさ
    'おちあまき',  // 鏡文字: きまあちお
    'きはらのし',  // 鏡文字: しのらはき
    'らまおちあ',  // 鏡文字: あちおまら
    'あしさきの',  // 鏡文字: のきさしあ
    'のおまはち',  // 鏡文字: ちはまおの
  ];

  // レベル4: 簡単な漢字1文字（ひらがな読みで逆読み）
  final List<Map<String, String>> _level4Questions = [
    {'kanji': '山', 'reading': 'やま'},
    {'kanji': '川', 'reading': 'かわ'},
    {'kanji': '海', 'reading': 'うみ'},
    {'kanji': '空', 'reading': 'そら'},
    {'kanji': '月', 'reading': 'つき'},
    {'kanji': '星', 'reading': 'ほし'},
    {'kanji': '風', 'reading': 'かぜ'},
    {'kanji': '雨', 'reading': 'あめ'},
    {'kanji': '雪', 'reading': 'ゆき'},
    {'kanji': '花', 'reading': 'はな'},
    {'kanji': '木', 'reading': 'き'},
    {'kanji': '森', 'reading': 'もり'},
    {'kanji': '犬', 'reading': 'いぬ'},
    {'kanji': '猫', 'reading': 'ねこ'},
    {'kanji': '鳥', 'reading': 'とり'},
    {'kanji': '魚', 'reading': 'さかな'},
    {'kanji': '車', 'reading': 'くるま'},
    {'kanji': '本', 'reading': 'ほん'},
    {'kanji': '手', 'reading': 'て'},
    {'kanji': '足', 'reading': 'あし'},
    {'kanji': '目', 'reading': 'め'},
    {'kanji': '耳', 'reading': 'みみ'},
    {'kanji': '口', 'reading': 'くち'},
    {'kanji': '火', 'reading': 'ひ'},
    {'kanji': '水', 'reading': 'みず'},
    {'kanji': '土', 'reading': 'つち'},
    {'kanji': '金', 'reading': 'かね'},
    {'kanji': '石', 'reading': 'いし'},
    {'kanji': '竹', 'reading': 'たけ'},
    {'kanji': '草', 'reading': 'くさ'},
  ];

  // レベル5: 簡単な漢字2文字（ひらがな読みで逆読み）
  final List<Map<String, String>> _level5Questions = [
    {'kanji': '学校', 'reading': 'がっこう'},
    {'kanji': '公園', 'reading': 'こうえん'},
    {'kanji': '病院', 'reading': 'びょういん'},
    {'kanji': '電車', 'reading': 'でんしゃ'},
    {'kanji': '飛行機', 'reading': 'ひこうき'},
    {'kanji': '図書館', 'reading': 'としょかん'},
    {'kanji': '郵便局', 'reading': 'ゆうびんきょく'},
    {'kanji': '動物', 'reading': 'どうぶつ'},
    {'kanji': '植物', 'reading': 'しょくぶつ'},
    {'kanji': '天気', 'reading': 'てんき'},
    {'kanji': '太陽', 'reading': 'たいよう'},
    {'kanji': '地球', 'reading': 'ちきゅう'},
    {'kanji': '宇宙', 'reading': 'うちゅう'},
    {'kanji': '教室', 'reading': 'きょうしつ'},
    {'kanji': '先生', 'reading': 'せんせい'},
    {'kanji': '友達', 'reading': 'ともだち'},
    {'kanji': '家族', 'reading': 'かぞく'},
    {'kanji': '会社', 'reading': 'かいしゃ'},
    {'kanji': '銀行', 'reading': 'ぎんこう'},
    {'kanji': '駅', 'reading': 'えき'},
    {'kanji': '店', 'reading': 'みせ'},
    {'kanji': '時計', 'reading': 'とけい'},
    {'kanji': '眼鏡', 'reading': 'めがね'},
    {'kanji': '鉛筆', 'reading': 'えんぴつ'},
    {'kanji': '消しゴム', 'reading': 'けしごむ'},
    {'kanji': '定規', 'reading': 'じょうぎ'},
    {'kanji': '机', 'reading': 'つくえ'},
    {'kanji': '椅子', 'reading': 'いす'},
  ];

  // レベル6: 簡単な漢字3文字以上（ひらがな読みで逆読み）
  final List<Map<String, String>> _level6Questions = [
    {'kanji': '小学校', 'reading': 'しょうがっこう'},
    {'kanji': '中学校', 'reading': 'ちゅうがっこう'},
    {'kanji': '高校', 'reading': 'こうこう'},
    {'kanji': '大学', 'reading': 'だいがく'},
    {'kanji': '美術館', 'reading': 'びじゅつかん'},
    {'kanji': '博物館', 'reading': 'はくぶつかん'},
    {'kanji': '遊園地', 'reading': 'ゆうえんち'},
    {'kanji': '動物園', 'reading': 'どうぶつえん'},
    {'kanji': '水族館', 'reading': 'すいぞくかん'},
    {'kanji': '映画館', 'reading': 'えいがかん'},
    {'kanji': '体育館', 'reading': 'たいいくかん'},
    {'kanji': '音楽室', 'reading': 'おんがくしつ'},
    {'kanji': '保健室', 'reading': 'ほけんしつ'},
    {'kanji': '運動場', 'reading': 'うんどうじょう'},
    {'kanji': '新幹線', 'reading': 'しんかんせん'},
    {'kanji': '自動車', 'reading': 'じどうしゃ'},
    {'kanji': '自転車', 'reading': 'じてんしゃ'},
    {'kanji': '消防車', 'reading': 'しょうぼうしゃ'},
    {'kanji': '救急車', 'reading': 'きゅうきゅうしゃ'},
    {'kanji': '郵便局', 'reading': 'ゆうびんきょく'},
    {'kanji': '警察署', 'reading': 'けいさつしょ'},
  ];

  // ランダムに問題を取得（レベル1-3のひらがな問題のみ）
  Question getRandomQuestion() {
    final allHiraganaQuestions = [
      ..._level1Questions,
      ..._level2Questions,
      ..._level3Questions,
    ];
    final word = allHiraganaQuestions[_random.nextInt(allHiraganaQuestions.length)];
    return _createQuestion(word);
  }

  // 問題を複数取得（レベル1-3のひらがな問題のみ）
  List<Question> getQuestions(int count) {
    final allHiraganaQuestions = [
      ..._level1Questions,
      ..._level2Questions,
      ..._level3Questions,
    ];
    final shuffled = List<String>.from(allHiraganaQuestions)..shuffle(_random);
    return shuffled.take(count).map((word) => _createQuestion(word)).toList();
  }

  // 特定の単語から問題を作成（ひらがな用）
  Question _createQuestion(String word) {
    final characters = word.split('');
    // シャッフルした文字リストも一緒に作成
    final shuffledChars = List<String>.from(characters)..shuffle(_random);

    // textは反転させて格納（鏡文字表示時に左から読めるように）
    final reversedText = word.split('').reversed.join('');

    return Question(
      text: reversedText,  // 反転した文字列を格納
      answer: word,         // 正解はそのまま
      characters: shuffledChars,
    );
  }

  // 漢字問題を作成（ひらがな読みで逆読み）
  Question _createKanjiQuestion(Map<String, String> kanjiData) {
    final kanji = kanjiData['kanji']!;
    final reading = kanjiData['reading']!;

    // 読みがなの文字リスト
    final characters = reading.split('');
    // シャッフルした文字リストも一緒に作成
    final shuffledChars = List<String>.from(characters)..shuffle(_random);

    // 漢字を反転させて表示用のtextにする
    final reversedKanji = kanji.split('').reversed.join('');

    // 正解は読みがなを逆読みした文字列
    final reversedReading = reading.split('').reversed.join('');

    return Question(
      text: reversedKanji,     // 反転した漢字を鏡文字で表示
      answer: reversedReading,  // 逆読みしたひらがなが正解
      characters: shuffledChars, // ひらがなの文字リスト
    );
  }

  // レベル別に問題を取得
  Question getQuestionByLevel(int level) {
    switch (level) {
      case 1:
        final word = _level1Questions[_random.nextInt(_level1Questions.length)];
        return _createQuestion(word);
      case 2:
        final word = _level2Questions[_random.nextInt(_level2Questions.length)];
        return _createQuestion(word);
      case 3:
        final word = _level3Questions[_random.nextInt(_level3Questions.length)];
        return _createQuestion(word);
      case 4:
        final kanjiData = _level4Questions[_random.nextInt(_level4Questions.length)];
        return _createKanjiQuestion(kanjiData);
      case 5:
        final kanjiData = _level5Questions[_random.nextInt(_level5Questions.length)];
        return _createKanjiQuestion(kanjiData);
      case 6:
        final kanjiData = _level6Questions[_random.nextInt(_level6Questions.length)];
        return _createKanjiQuestion(kanjiData);
      default:
        final word = _level1Questions[_random.nextInt(_level1Questions.length)];
        return _createQuestion(word);
    }
  }

  // ステージ番号に応じた難易度の問題を取得
  // ステージが進むにつれて段階的にレベルアップ
  Question getQuestionForStage(int stage) {
    int level;

    if (stage < 3) {
      level = 1; // ステージ0-2: レベル1（3文字ひらがな）
    } else if (stage < 6) {
      level = 2; // ステージ3-5: レベル2（4文字ひらがな）
    } else if (stage < 9) {
      level = 3; // ステージ6-8: レベル3（5文字ひらがな）
    } else if (stage < 12) {
      level = 4; // ステージ9-11: レベル4（漢字1文字）
    } else if (stage < 15) {
      level = 5; // ステージ12-14: レベル5（漢字2文字）
    } else {
      level = 6; // ステージ15以上: レベル6（漢字3文字）
    }

    return getQuestionByLevel(level);
  }
}
