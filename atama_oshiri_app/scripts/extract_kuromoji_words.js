const kuromoji = require('kuromoji');
const fs = require('fs');
const path = require('path');

// ひらがなに変換する関数
function katakanaToHiragana(str) {
  return str.replace(/[\u30A1-\u30F6]/g, function(match) {
    const chr = match.charCodeAt(0) - 0x60;
    return String.fromCharCode(chr);
  });
}

// ひらがなのみかチェック
function isHiraganaOnly(str) {
  return /^[\u3041-\u3096]+$/.test(str);
}

// 単語の長さチェック（2文字以上）
function isValidLength(str) {
  return str.length >= 2;
}

// kuromoji.jsの辞書から単語を抽出
function extractWordsFromKuromoji() {
  return new Promise((resolve, reject) => {
    kuromoji.builder({ dicPath: 'node_modules/kuromoji/dict' }).build((err, tokenizer) => {
      if (err) {
        reject(err);
        return;
      }

      const words = new Set();
      
      // 一般的な日本語単語のリスト
      const testWords = [
        '愛', '青い', '赤い', '暑い', '甘い', '浅い', '荒い', '扱い', '紫陽花', '挨拶',
        '赤ちゃん', '青空', '赤ちゃん', '青い空', '赤い花', '暑い日', '甘い物', '浅い川',
        '荒い海', '扱い方', '紫陽花', '挨拶回り', '愛する', '青い海', '赤い夕日', '暑い夏',
        '甘い夢', '浅い眠り', '荒い風', '扱いやすい', '紫陽花の花', '挨拶状',
        // より多くの単語を追加
        'あい', 'あおい', 'あかい', 'あつい', 'あまい', 'あさい', 'あらい', 'あつかい',
        'あじさい', 'あいさつ', 'あいこ', 'あいす', 'あいず', 'あいせき', 'あいそう',
        'あいた', 'あいだ', 'あいち', 'あいつ', 'あいて', 'あいと', 'あいど', 'あいな',
        'あいの', 'あいは', 'あいば', 'あいひ', 'あいふ', 'あいへ', 'あいほ', 'あいま',
        'あいみ', 'あいむ', 'あいめ', 'あいも', 'あいや', 'あいゆ', 'あいよ', 'あいら',
        'あいり', 'あいる', 'あいれ', 'あいろ', 'あいわ', 'あいを', 'あいん'
      ];

      testWords.forEach(word => {
        try {
          const tokens = tokenizer.tokenize(word);
          tokens.forEach(token => {
            if (token.reading) {
              const hiragana = katakanaToHiragana(token.reading);
              if (isHiraganaOnly(hiragana) && isValidLength(hiragana)) {
                words.add(hiragana);
              }
            }
          });
        } catch (e) {
          // エラーは無視
        }
      });

      resolve(Array.from(words).sort());
    });
  });
}

// メイン処理
async function main() {
  try {
    console.log('kuromoji.jsから単語を抽出中...');
    const words = await extractWordsFromKuromoji();
    
    console.log(`抽出された単語数: ${words.length}`);
    console.log('最初の20個:');
    words.slice(0, 20).forEach((word, index) => {
      console.log(`  ${index + 1}. ${word}`);
    });

    // JSONファイルに保存
    const outputPath = path.join(__dirname, '../assets/dictionary_new/char_あ_kuromoji.json');
    fs.writeFileSync(outputPath, JSON.stringify(words, null, 2), 'utf8');
    
    console.log(`\n単語リストを ${outputPath} に保存しました。`);
    
  } catch (error) {
    console.error('エラー:', error);
  }
}

main();
