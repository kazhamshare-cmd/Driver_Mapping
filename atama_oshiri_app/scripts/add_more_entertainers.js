const fs = require('fs');
const path = require('path');

const more = [
  'くりぃむしちゅー',
  'ナインティナイン',
  'ロンドンブーツ',
  'ダウンタウン',
  '千鳥',
  'フットボールアワー',
  'サンドイッチマン',
  'チュートリアル',
  'オードリー',
  'アンタッチャブル',
  'バナナマン',
  'ロバート',
  'ハライチ',
  'EXIT',
  '見取り図',
  'ミキ',
  '霜降り明星',
  'かまいたち',
  'オズワルド',
  'ランジャタイ',
  'インパルス',
  '千鳥',
  'フットボールアワー',
  'サンドイッチマン',
  'チュートリアル',
  'オードリー',
  'アンタッチャブル',
  'バナナマン',
  'ロバート',
  'ハライチ',
  'EXIT',
  '見取り図',
  'ミキ',
  '霜降り明星',
  'かまいたち',
  'オズワルド',
  'ランジャタイ',
  'インパルス'
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
more.forEach(w => {
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
