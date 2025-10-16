const fs = require('fs');
const path = require('path');

// 追加単語リスト
const additionalWords = [
  'じゃにーず', 'じぇいそーるぶらざーず', 'みせすぐりーんあっぷる'
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
  console.log('追加単語を登録中...');
  
  const categories = {};
  
  additionalWords.forEach(word => {
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
