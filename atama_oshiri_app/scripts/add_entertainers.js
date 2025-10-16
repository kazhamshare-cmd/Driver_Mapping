const fs = require('fs');
const path = require('path');

const entertainers = [
  'たかあんどとし',
  'さんどいっちまん',
  'ゆーじこーじ',
  'めいぷるちょうごうきん',
  'はじめしゃちょー',
  'とうかいおんえあ',
  'ひかきん',
  'ふじわら',
  'みやざき',
  'たかし',
  'やまざき',
  'さとう',
  'すずき',
  'たなか',
  'わたなべ',
  'いとう',
  'こばやし',
  'かとう',
  'よしだ',
  'やまだ',
  'いのうえ',
  'まつもと',
  'きむら',
  'はしもと',
  'やまぐち',
  'もり',
  'さかもと',
  'いけだ',
  'ふくしま',
  'おかだ',
  'なかむら',
  'はせがわ',
  'まえだ',
  'あべ',
  'ふじた',
  'おおた',
  'たけだ',
  'なかじま',
  'いしだ',
  'うえだ',
  'もりた',
  'こんどう',
  'ひらた',
  'さいとう',
  'よこやま',
  'まつだ',
  'いわさき',
  'たなべ',
  'かわむら',
  'なかがわ',
  'おおの',
  'いしばし',
  'あいかわ',
  'まつい',
  'さかき',
  'やまもと',
  'いまい',
  'たかぎ',
  'おおはし',
  'ふじい',
  'あさだ',
  'いけがみ',
  'えぐち',
  'おおくぼ',
  'かわしま',
  'きのした',
  'くろだ',
  'こいけ',
  'こまつ',
  'さいとう',
  'しばた',
  'すがわら',
  'たかはし',
  'つじ',
  'とみた',
  'なかむら',
  'にしむら',
  'はた',
  'ふじわら',
  'まつおか',
  'みやもと',
  'むらかみ',
  'やまざき',
  'よしむら'
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
entertainers.forEach(w => {
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
