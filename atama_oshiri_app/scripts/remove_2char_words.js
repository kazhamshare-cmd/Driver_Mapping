const fs = require('fs');
const path = require('path');

// 辞書ディレクトリのパス
const dictionaryDir = path.join(__dirname, '../assets/dictionary');

// 2文字の単語を削除する関数
function removeTwoCharWords(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    const jsonData = JSON.parse(data);
    
    let totalOriginal = 0;
    let totalFiltered = 0;
    let totalRemoved = 0;
    
    // 配列の場合
    if (Array.isArray(jsonData)) {
      const filteredWords = jsonData.filter(word => word.length >= 3);
      const removedCount = jsonData.length - filteredWords.length;
      
      if (removedCount > 0) {
        console.log(`${path.basename(filePath)}: ${removedCount}個の2文字単語を削除 (${jsonData.length} → ${filteredWords.length})`);
        fs.writeFileSync(filePath, JSON.stringify(filteredWords, null, 2), 'utf8');
      } else {
        console.log(`${path.basename(filePath)}: 2文字単語なし`);
      }
      
      return { original: jsonData.length, filtered: filteredWords.length, removed: removedCount };
    }
    
    // オブジェクトの場合
    if (typeof jsonData === 'object' && jsonData !== null) {
      const processedData = {};
      
      for (const [key, value] of Object.entries(jsonData)) {
        if (Array.isArray(value)) {
          const filteredWords = value.filter(word => word.length >= 3);
          const removedCount = value.length - filteredWords.length;
          
          processedData[key] = filteredWords;
          totalOriginal += value.length;
          totalFiltered += filteredWords.length;
          totalRemoved += removedCount;
          
          if (removedCount > 0) {
            console.log(`  ${key}: ${removedCount}個の2文字単語を削除 (${value.length} → ${filteredWords.length})`);
          }
        } else {
          processedData[key] = value;
        }
      }
      
      if (totalRemoved > 0) {
        console.log(`${path.basename(filePath)}: 合計${totalRemoved}個の2文字単語を削除 (${totalOriginal} → ${totalFiltered})`);
        fs.writeFileSync(filePath, JSON.stringify(processedData, null, 2), 'utf8');
      } else {
        console.log(`${path.basename(filePath)}: 2文字単語なし`);
      }
      
      return { original: totalOriginal, filtered: totalFiltered, removed: totalRemoved };
    }
    
    return { original: 0, filtered: 0, removed: 0 };
  } catch (error) {
    console.error(`エラー: ${filePath} - ${error.message}`);
    return { original: 0, filtered: 0, removed: 0 };
  }
}

// メイン処理
function main() {
  console.log('辞書から2文字の単語を削除中...\n');
  
  const files = fs.readdirSync(dictionaryDir);
  const jsonFiles = files.filter(file => file.endsWith('.json'));
  
  let totalOriginal = 0;
  let totalFiltered = 0;
  let totalRemoved = 0;
  
  jsonFiles.forEach(file => {
    const filePath = path.join(dictionaryDir, file);
    const result = removeTwoCharWords(filePath);
    
    totalOriginal += result.original;
    totalFiltered += result.filtered;
    totalRemoved += result.removed;
  });
  
  console.log('\n=== 処理完了 ===');
  console.log(`総単語数: ${totalOriginal} → ${totalFiltered}`);
  console.log(`削除された2文字単語: ${totalRemoved}個`);
  console.log(`削除率: ${((totalRemoved / totalOriginal) * 100).toFixed(2)}%`);
}

// スクリプト実行
if (require.main === module) {
  main();
}

module.exports = { removeTwoCharWords };
