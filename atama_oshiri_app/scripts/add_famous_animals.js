const fs = require('fs');
const path = require('path');

const animals = [
  'しまえなが',
  'ぱんだ',
  'れっさーぱんだ',
  'おこじょ',
  'しろくま',
  'くろくま',
  'きつね',
  'たぬき',
  'うさぎ',
  'ねこ',
  'いぬ',
  'とら',
  'らいおん',
  'ぞう',
  'きりん',
  'さる',
  'いのしし',
  'しか',
  'うま',
  'うし',
  'ぶた',
  'ひつじ',
  'やぎ',
  'にわとり',
  'あひる',
  'がちょう',
  'すずめ',
  'からす',
  'つばめ',
  'はと',
  'わし',
  'たか',
  'ふくろう',
  'ペンギン',
  'あざらし',
  'いるか',
  'くじら',
  'さめ',
  'まぐろ',
  'さば',
  'たい',
  'あじ',
  'いわし',
  'さんま',
  'さけ',
  'ます',
  'うなぎ',
  'なまず',
  'どじょう',
  'こい',
  'きんぎょ',
  'めだか',
  'かえる',
  'とかげ',
  'へび',
  'かめ',
  'わに',
  'とり',
  'ちょう',
  'はち',
  'あり',
  'くも',
  'かたつむり',
  'みみず',
  'だんごむし'
];

function load(char) {
  const file = path.join(__dirname, `../assets/dictionary_new/char_${char}.json`);
  try {
    return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : [];
  } catch (e) {
    return [];
  }
}

const cats = {};
animals.forEach(w => {
  if (w.length >= 3) {
    const c = w[0];
    if (!cats[c]) cats[c] = [];
    cats[c].push(w);
  }
});

Object.keys(cats).forEach(c => {
  const all = [...new Set([...load(c), ...cats[c]])].filter(w => w.length >= 3);
  const out = path.join(__dirname, `../assets/dictionary_new/char_${c}.json`);
  fs.writeFileSync(out, JSON.stringify(all, null, 2), 'utf8');
  console.log(`${c}: ${all.length}個`);
});

console.log('完了！');
