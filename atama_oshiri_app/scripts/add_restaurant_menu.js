const fs = require('fs');
const path = require('path');

// 食堂・レストランの一般的なメニューリスト
const menuItems = [
  // 和食
  'ていしょく', 'みそらーめん', 'かつどん', 'てんどん', 'うなぎどん', 'おやこどん', 'ぎゅうどん',
  'すし', 'ちらしずし', 'まきずし', 'にぎりずし', 'てんぷら', 'すきやき', 'しゃぶしゃぶ',
  'やきにく', 'おでん', 'なべ', 'みそしる', 'すーぷ', 'さしみ', 'つけもの', 'ごはん',
  
  // 洋食
  'ぴざ', 'ぱすた', 'すぱげってぃ', 'らーめん', 'うどん', 'そば', 'そうめん', 'きしめん',
  'ひやむぎ', 'やきそば', 'ちゃーはん', 'おむらいす', 'どんぶり', 'どんぶりもの',
  'すーぷ', 'さらだ', 'ぽてと', 'ふらいどぽてと', 'ぽてとちっぷす', 'からあげ',
  'とんかつ', 'えびふらい', 'さきふらい', 'からあげ', 'とりにく', 'ぎゅうにく',
  'ぶたにく', 'さかな', 'えび', 'かに', 'たこ', 'いか', 'あわび', 'ほたて',
  
  // デザート・飲み物
  'すとろべりーけーき', 'ちょこれーとけーき', 'ぷりん', 'あいすくりーむ', 'ようかん',
  'まんじゅう', 'だいふく', 'もち', 'せんべい', 'おかし', 'くっきー', 'びすけっと',
  'みず', 'おちゃ', 'こうちゃ', 'こーひー', 'じゅーす', 'みるく', 'さけ', 'びーる',
  'わいん', 'ういすきー', 'おれんじじゅーす', 'うーろんちゃ', 'りんごじゅーす',
  'ぶどうじゅーす', 'ももじゅーす', 'いちごじゅーす', 'みかんじゅーす',
  
  // 中華料理
  'ちゃーはん', 'やきそば', 'ぎょうざ', 'しゅうまい', 'ちゅうかどん', 'ちゅうかそば',
  'まーぼーどん', 'たんめん', 'らーめん', 'うどん', 'そば', 'そうめん',
  
  // その他
  'えびちり', 'えびふらい', 'さきふらい', 'とりにく', 'ぎゅうにく', 'ぶたにく',
  'さかな', 'えび', 'かに', 'たこ', 'いか', 'あわび', 'ほたて', 'あさり',
  'しじみ', 'はまぐり', 'かき', 'うに', 'いくら', 'たらこ', 'めんたいこ'
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
  console.log('食堂・レストランの一般的なメニューを追加中...');
  
  const categories = {};
  
  menuItems.forEach(word => {
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
