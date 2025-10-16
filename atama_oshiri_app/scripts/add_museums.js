const fs = require('fs');
const path = require('path');

// 世界の有名美術館・博物館名リスト
const museums = [
  'おるせーびじゅつかん', 'うふぃっつびじゅつかん', 'めとろぽりたんびじゅつかん',
  'こくりつびじゅつかん', 'とうきょうびじゅつかん', 'きょうとびじゅつかん',
  'ならびじゅつかん', 'たてしきびじゅつかん', 'こくりつしんびじゅつかん',
  'きんせいびじゅつかん', 'あだちびじゅつかん', 'もりびじゅつかん',
  'ひらしまびじゅつかん', 'かがわびじゅつかん', 'ふくおかびじゅつかん',
  'さっぽろびじゅつかん', 'せんだいびじゅつかん', 'よこはまびじゅつかん',
  'なごやびじゅつかん', 'おおさかびじゅつかん', 'こうべびじゅつかん',
  'ひろしまびじゅつかん', 'ふくおかびじゅつかん', 'くまもとびじゅつかん',
  'かごしまびじゅつかん', 'おきなわびじゅつかん', 'あおもりびじゅつかん',
  'あきたびじゅつかん', 'いわてびじゅつかん', 'みやぎびじゅつかん',
  'ふくしまびじゅつかん', 'いばらきびじゅつかん', 'とちぎびじゅつかん',
  'ぐんまびじゅつかん', 'さいたまびじゅつかん', 'ちばびじゅつかん',
  'とうきょうびじゅつかん', 'かながわびじゅつかん', 'にいがたびじゅつかん',
  'とやまびじゅつかん', 'いしかわびじゅつかん', 'ふくいびじゅつかん',
  'やまなしびじゅつかん', 'ながのびじゅつかん', 'ぎふびじゅつかん',
  'しずおかびじゅつかん', 'あいちびじゅつかん', 'みえびじゅつかん',
  'しがびじゅつかん', 'きょうとびじゅつかん', 'おおさかびじゅつかん',
  'ひょうごびじゅつかん', 'ならびじゅつかん', 'わかやまびじゅつかん',
  'とっとりびじゅつかん', 'しまねびじゅつかん', 'おかやまびじゅつかん',
  'ひろしまびじゅつかん', 'やまぐちびじゅつかん', 'とくしまびじゅつかん',
  'かがわびじゅつかん', 'えひめびじゅつかん', 'こうちびじゅつかん',
  'ふくおかびじゅつかん', 'さがびじゅつかん', 'ながさきびじゅつかん',
  'くまもとびじゅつかん', 'おおいたびじゅつかん', 'みやざきびじゅつかん',
  'かごしまびじゅつかん', 'おきなわびじゅつかん'
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
  console.log('世界の有名美術館・博物館名を追加中...');
  
  const categories = {};
  
  museums.forEach(word => {
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
