const fs = require('fs');
const path = require('path');

// 一般的な香辛料リスト
const spices = [
  'しお', 'こしょう', 'さとう', 'みそ', 'しょうゆ', 'みりん', 'さけ', 'みず', 'おちゃ',
  'こうちゃ', 'こーひー', 'じゅーす', 'みるく', 'ちーず', 'ばたー', 'まーがりん',
  'あぶら', 'ごまあぶら', 'おりーぶおいる', 'あめ', 'ちょこれーと', 'けーき',
  'ぷりん', 'あいすくりーむ', 'ようかん', 'まんじゅう', 'だいふく', 'もち',
  'せんべい', 'おかし', 'くっきー', 'びすけっと', 'ぽてとちっぷす', 'わいん',
  'ういすきー', 'おれんじじゅーす', 'うーろんちゃ', 'りんごじゅーす', 'ぶどうじゅーす',
  'ももじゅーす', 'いちごじゅーす', 'みかんじゅーす', 'しお', 'こしょう', 'さとう',
  'みそ', 'しょうゆ', 'みりん', 'さけ', 'みず', 'おちゃ', 'こうちゃ', 'こーひー',
  'じゅーす', 'みるく', 'ちーず', 'ばたー', 'まーがりん', 'あぶら', 'ごまあぶら',
  'おりーぶおいる', 'あめ', 'ちょこれーと', 'けーき', 'ぷりん', 'あいすくりーむ',
  'ようかん', 'まんじゅう', 'だいふく', 'もち', 'せんべい', 'おかし', 'くっきー',
  'びすけっと', 'ぽてとちっぷす', 'わいん', 'ういすきー', 'おれんじじゅーす',
  'うーろんちゃ', 'りんごじゅーす', 'ぶどうじゅーす', 'ももじゅーす', 'いちごじゅーす',
  'みかんじゅーす', 'しお', 'こしょう', 'さとう', 'みそ', 'しょうゆ', 'みりん',
  'さけ', 'みず', 'おちゃ', 'こうちゃ', 'こーひー', 'じゅーす', 'みるく', 'ちーず',
  'ばたー', 'まーがりん', 'あぶら', 'ごまあぶら', 'おりーぶおいる', 'あめ',
  'ちょこれーと', 'けーき', 'ぷりん', 'あいすくりーむ', 'ようかん', 'まんじゅう',
  'だいふく', 'もち', 'せんべい', 'おかし', 'くっきー', 'びすけっと', 'ぽてとちっぷす',
  'わいん', 'ういすきー', 'おれんじじゅーす', 'うーろんちゃ', 'りんごじゅーす',
  'ぶどうじゅーす', 'ももじゅーす', 'いちごじゅーす', 'みかんじゅーす'
];

function loadDictionary(char) {
  const filePath = path.join(__dirname, `../assets/dictionary_new/char_${char}.json`);
  try {
    if (fs.existsSync(filePath)) {
      return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    }
  } catch (error) {
    console.log(`Error reading char_${char}.json:`, error.message);
  }
  return [];
}

function main() {
  console.log('一般的な香辛料を追加中...');
  
  const categories = {};
  
  spices.forEach(word => {
    if (word.length >= 3) {
      const firstChar = word[0];
      if (!categories[firstChar]) categories[firstChar] = [];
      categories[firstChar].push(word);
    }
  });
  
  Object.keys(categories).forEach(category => {
    const newWords = categories[category];
    const existingWords = loadDictionary(category);
    const allWords = [...new Set([...existingWords, ...newWords])].filter(w => w.length >= 3);
    
    const outputPath = path.join(__dirname, `../assets/dictionary_new/char_${category}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(allWords, null, 2), 'utf8');
    console.log(`「${category}」: ${allWords.length}個の単語`);
  });
  
  console.log('完了しました！');
}

main();
