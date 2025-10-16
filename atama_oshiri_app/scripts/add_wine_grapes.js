const fs = require('fs');
const path = require('path');

// ワインの葡萄品種リスト
const wineGrapes = [
  'せっちゃくざい', 'かべるねそーびによん', 'ぼるどー',
  'しゃるどね', 'めるろー', 'ぴののわーる', 'そーびによんぶらん',
  'りーすりんぐ', 'しらーず', 'てんぷらにーりょ', 'がめーねぐろ',
  'さんじょべーぜ', 'ぐるなっしゅ', 'むーるべーどる', 'かりにゃん',
  'ますかっと', 'ぴのぐり', 'じんふぁんでる', 'まるべっく',
  'ぷちゔぇるど', 'あるばりーにょ', 'さんぎょべーぜ'
];

function katakanaToHiragana(str) {
  return str.replace(/[\u30A1-\u30F6]/g, m => String.fromCharCode(m.charCodeAt(0) - 0x60));
}

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
  console.log('ワインの葡萄品種を追加中...');
  
  const hiraganaWords = wineGrapes.map(word => katakanaToHiragana(word));
  const categories = {};
  
  hiraganaWords.forEach(word => {
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

