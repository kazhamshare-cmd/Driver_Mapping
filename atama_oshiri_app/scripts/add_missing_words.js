const fs = require('fs');
const path = require('path');

const words = [
  'いんすたばえ',
  'ふてほど',
  'せいふりゅうつうまい'
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
words.forEach(w => {
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