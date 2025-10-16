const fs = require('fs');
const path = require('path');

const dictionaryPath = path.join(__dirname, '../assets/dictionary_new');

function normalizeToHiragana(text) {
    return text.normalize('NFKC').replace(/[\u30a1-\u30f6]/g, function(match) {
        return String.fromCharCode(match.charCodeAt(0) - 0x60);
    }).replace(/ー/g, ''); // 長音符は一旦削除
}

async function addWordToDictionary(word) {
    const firstChar = normalizeToHiragana(word)[0];
    const filePath = path.join(dictionaryPath, `char_${firstChar}.json`);

    let words = [];
    if (fs.existsSync(filePath)) {
        const fileContent = await fs.promises.readFile(filePath, 'utf8');
        words = JSON.parse(fileContent);
    }

    const normalizedWord = normalizeToHiragana(word);
    if (!words.includes(normalizedWord)) {
        words.push(normalizedWord);
        words.sort(); // ソートして追加
        await fs.promises.writeFile(filePath, JSON.stringify(words, null, 2), 'utf8');
        console.log(`「${word}」を「char_${firstChar}.json」に追加しました。`);
    } else {
        console.log(`「${word}」は既に「char_${firstChar}.json」に存在します。`);
    }
}

async function addNezucchi() {
    console.log('ねづっちを追加中...');
    const wordsToAdd = [
        "ねづっち",
    ];

    for (const word of wordsToAdd) {
        await addWordToDictionary(word);
    }

    // 辞書ファイルの単語数を再確認
    const charNPath = path.join(dictionaryPath, 'char_ね.json');
    if (fs.existsSync(charNPath)) {
        const fileContent = await fs.promises.readFile(charNPath, 'utf8');
        const words = JSON.parse(fileContent);
        console.log(`「ね」: ${words.length}個の単語`);
    }
    console.log('完了しました！');
}

addNezucchi();
