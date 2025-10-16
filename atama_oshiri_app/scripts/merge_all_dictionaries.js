const fs = require('fs');
const path = require('path');

// 全ての辞書ファイルを結合する関数
function mergeAllDictionaries() {
  const dictionaryDir = path.join(__dirname, '../assets/dictionary_new');
  const allWords = new Set();
  
  // 既存の辞書ファイルを読み込み
  const files = fs.readdirSync(dictionaryDir).filter(file => file.startsWith('char_') && file.endsWith('.json'));
  
  files.forEach(file => {
    try {
      const filePath = path.join(dictionaryDir, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const words = JSON.parse(content);
      
      words.forEach(word => {
        if (word && typeof word === 'string' && word.length >= 3) { // 3文字以上
          allWords.add(word);
        }
      });
    } catch (error) {
      console.log(`Error reading ${file}:`, error.message);
    }
  });
  
  return Array.from(allWords);
}

// 有名人データベースを追加する関数
function addCelebrityDatabase() {
  const celebrities = [
    // ハリウッドスター
    'とむくらーず', 'とむくらーず', 'トム・クルーズ', 'トムクルーズ',
    'ぶらどぴっと', 'ぶらどぴっと', 'ブラッド・ピット', 'ブラッドピット',
    'れおなるどでぃかぷりお', 'れおなるどでぃかぷりお', 'レオナルド・ディカプリオ', 'レオナルドディカプリオ',
    'すかーれっとじょーはんそん', 'すかーれっとじょーはんそん', 'スカーレット・ジョハンソン', 'スカーレットジョハンソン',
    'えますとーん', 'えますとーん', 'エマ・ストーン', 'エマストーン',
    'ろばーとだうにーじゅにあ', 'ろばーとだうにーじゅにあ', 'ロバート・ダウニー・ジュニア', 'ロバートダウニージュニア',
    'ちりすとふぁー', 'ちりすとふぁー', 'クリス・エヴァンス', 'クリスエヴァンス',
    'まーくらふぉろ', 'まーくらふぉろ', 'マーク・ラファロ', 'マークラファロ',
    'じぇれみーれなー', 'じぇれみーれなー', 'ジェレミー・レナー', 'ジェレミーレナー',
    'すかーれっとじょはんそん', 'すかーれっとじょはんそん', 'スカーレット・ジョハンソン', 'スカーレットジョハンソン',
    
    // 日本のアーティスト・有名人
    'あいみょん', 'あいみょん', 'あいみょん', 'あいみょん',
    'ゆい', 'ゆい', 'ゆい', 'ゆい',
    'りんご', 'りんご', 'りんご', 'りんご',
    'あだちみなみ', 'あだちみなみ', 'あだちみなみ', 'あだちみなみ',
    'すずきあや', 'すずきあや', 'すずきあや', 'すずきあや',
    'たかはしあい', 'たかはしあい', 'たかはしあい', 'たかはしあい',
    'やまもとたかし', 'やまもとたかし', 'やまもとたかし', 'やまもとたかし',
    'さとうまさみ', 'さとうまさみ', 'さとうまさみ', 'さとうまさみ',
    'いけだあい', 'いけだあい', 'いけだあい', 'いけだあい',
    'なかがわまき', 'なかがわまき', 'なかがわまき', 'なかがわまき',
    
    // 政治家・著名人
    'あべしんぞう', 'あべしんぞう', 'あべしんぞう', 'あべしんぞう',
    'すがよしひで', 'すがよしひで', 'すがよしひで', 'すがよしひで',
    'こいずみじゅんいちろう', 'こいずみじゅんいちろう', 'こいずみじゅんいちろう', 'こいずみじゅんいちろう',
    'はたやまゆきお', 'はたやまゆきお', 'はたやまゆきお', 'はたやまゆきお',
    'おおしまゆうこ', 'おおしまゆうこ', 'おおしまゆうこ', 'おおしまゆうこ',
    
    // スポーツ選手
    'おおたにしょうへい', 'おおたにしょうへい', 'おおたにしょうへい', 'おおたにしょうへい',
    'いちろー', 'いちろー', 'いちろー', 'いちろー',
    'なかむらあい', 'なかむらあい', 'なかむらあい', 'なかむらあい',
    'たなかまなみ', 'たなかまなみ', 'たなかまなみ', 'たなかまなみ',
    'はやしゆうすけ', 'はやしゆうすけ', 'はやしゆうすけ', 'はやしゆうすけ',
    
    // その他の有名人
    'みやざきあおい', 'みやざきあおい', 'みやざきあおい', 'みやざきあおい',
    'ながさきまさみ', 'ながさきまさみ', 'ながさきまさみ', 'ながさきまさみ',
    'こいけゆうこ', 'こいけゆうこ', 'こいけゆうこ', 'こいけゆうこ',
    'たけうちゆうき', 'たけうちゆうき', 'たけうちゆうき', 'たけうちゆうき',
    'さかもとりょうこ', 'さかもとりょうこ', 'さかもとりょうこ', 'さかもとりょうこ'
  ];
  
  return celebrities;
}

// カタカナをひらがなに変換する関数
function katakanaToHiragana(str) {
  return str.replace(/[\u30A1-\u30F6]/g, function(match) {
    const chr = match.charCodeAt(0) - 0x60;
    return String.fromCharCode(chr);
  });
}

// 漢字をひらがなに変換する関数（簡易版）
function kanjiToHiragana(str) {
  const kanjiHiraganaMap = {
    '愛': 'あい', '青': 'あお', '赤': 'あか', '暑': 'あつ', '甘': 'あま',
    '浅': 'あさ', '荒': 'あら', '紫陽花': 'あじさい', '挨拶': 'あいさつ',
    '青森': 'あおもり', '秋田': 'あきた', '愛知': 'あいち', '明石': 'あかし',
    '朝日': 'あさひ', '天草': 'あまがさ', '餡子': 'あんこ', '杏': 'あんず',
    '餡蜜': 'あんみつ', '青森銀行': 'あおもりぎんこう', '秋田銀行': 'あきたぎんこう',
    '愛知銀行': 'あいちぎんこう', '愛知製鋼': 'あいちせいけん',
    '愛知中央銀行': 'あいちちゅうおうぎんこう',
    '微塵子': 'みじんこ', '民間企業': 'みんかんきぎょう',
    '巫女': 'みこ', '都': 'みやこ', '道子': 'みちこ', '身の子': 'みのこ',
    '雅子': 'みやびこ', '緑': 'みどり', '緑色': 'みどりいろ',
    '緑が丘': 'みどりがおか', '緑が丘西': 'みどりがおかにし',
    '緑が丘東': 'みどりがおかひがし', '緑狩り': 'みどりがり',
    '緑台': 'みどりだい', '緑台北': 'みどりだいきた',
    '緑台西': 'みどりだいにし', '緑台東': 'みどりだいひがし',
    '緑台南': 'みどりだいみなみ', '緑谷': 'みどりだに',
    '緑通り北': 'みどりどおりきた', '緑通り南': 'みどりどおりみなみ',
    '緑山': 'みどりやま', '赤信号': 'あかしんごう',
    'IPS細胞': 'あいぴーえすさいぼう', '芥川龍之介': 'あくただわりゅうのすけ',
    '明日のジョー': 'あしたのじょー', '安倍晋三': 'あべしんぞう',
    '菅義偉': 'すがよしひで', '小泉純一郎': 'こいずみじゅんいちろう',
    '鳩山由紀夫': 'はとやまゆきお', '大島優子': 'おおしまゆうこ',
    '大谷翔平': 'おおたにしょうへい', '一朗': 'いちろー',
    '中村愛': 'なかむらあい', '田中真奈美': 'たなかまなみ',
    '林優介': 'はやしゆうすけ', '宮崎あおい': 'みやざきあおい',
    '長崎真実': 'ながさきまさみ', '小池優子': 'こいけゆうこ',
    '武内由紀': 'たけうちゆうき', '坂本良子': 'さかもとりょうこ'
  };
  
  let result = str;
  Object.keys(kanjiHiraganaMap).forEach(kanji => {
    result = result.replace(new RegExp(kanji, 'g'), kanjiHiraganaMap[kanji]);
  });
  return result;
}

// 単語をひらがなに変換する関数
function convertToHiragana(word) {
  let hiragana = katakanaToHiragana(word);
  hiragana = kanjiToHiragana(hiragana);
  return hiragana;
}

// メイン処理
function main() {
  console.log('全ての辞書ファイルを結合中...');
  
  // 既存の辞書ファイルを結合
  const existingWords = mergeAllDictionaries();
  console.log(`既存の辞書から取得した単語数: ${existingWords.length}個`);
  
  // 有名人データベースを追加
  const celebrityWords = addCelebrityDatabase();
  console.log(`有名人データベースから取得した単語数: ${celebrityWords.length}個`);
  
  // 全ての単語を結合
  const allWords = [...existingWords, ...celebrityWords];
  console.log(`結合後の総単語数: ${allWords.length}個`);
  
  // 重複を除去
  const uniqueWords = [...new Set(allWords)];
  console.log(`重複除去後の単語数: ${uniqueWords.length}個`);
  
  // 3文字以上の単語のみをフィルタリング
  const filteredWords = uniqueWords.filter(word => word && word.length >= 3);
  console.log(`3文字以上の単語数: ${filteredWords.length}個`);
  
  // 単語を分類
  const categories = {};
  filteredWords.forEach(word => {
    const hiragana = convertToHiragana(word);
    const firstChar = hiragana[0];
    if (!categories[firstChar]) {
      categories[firstChar] = [];
    }
    categories[firstChar].push(hiragana);
  });
  
  // 各文字の辞書ファイルを作成
  Object.keys(categories).forEach(category => {
    const uniqueCategoryWords = [...new Set(categories[category])];
    const outputPath = path.join(__dirname, `../assets/dictionary_new/char_${category}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(uniqueCategoryWords, null, 2), 'utf8');
    console.log(`「${category}」の辞書: ${uniqueCategoryWords.length}個の単語を保存しました。`);
  });
  
  // 統計情報を表示
  console.log('\n=== 辞書統計 ===');
  Object.keys(categories).forEach(category => {
    const uniqueCategoryWords = [...new Set(categories[category])];
    console.log(`「${category}」で始まる: ${uniqueCategoryWords.length}個`);
  });
  
  console.log(`\n総単語数: ${filteredWords.length}個`);
  console.log('辞書の結合が完了しました！');
}

main();
