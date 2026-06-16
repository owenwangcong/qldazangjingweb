/**
 * Extract OpenCC dictionaries from node_modules/opencc-js into plain TSV
 * assets consumed by the Flutter app's pure-Dart converter.
 *
 * Usage: node scripts/generate-opencc-assets.js
 * Output: flutter-app/assets/opencc/{s2t.tsv,t2s.tsv}
 */
const fs = require('fs');
const path = require('path');

const dictDir = path.join(__dirname, '..', 'node_modules', 'opencc-js', 'dist', 'esm-lib', 'dict');
const outDir = path.join(__dirname, '..', 'flutter-app', 'assets', 'opencc');

function loadDict(name) {
  const raw = fs.readFileSync(path.join(dictDir, `${name}.js`), 'utf8');
  const m = raw.match(/export default "([\s\S]*)";?\s*$/);
  if (!m) throw new Error(`Unexpected format in ${name}.js`);
  // JS string literal: unescape \" \\ \uXXXX
  const text = JSON.parse(`"${m[1]}"`);
  const map = new Map();
  for (const entry of text.split('|')) {
    if (!entry) continue;
    const sp = entry.indexOf(' ');
    if (sp <= 0) continue;
    const from = entry.slice(0, sp);
    // Multiple candidates are space-separated; keep the first (OpenCC default).
    const to = entry.slice(sp + 1).split(' ')[0];
    if (from && to && !map.has(from)) map.set(from, to);
  }
  return map;
}

function writeTsv(file, maps) {
  const merged = new Map();
  for (const m of maps) {
    for (const [k, v] of m) {
      if (!merged.has(k)) merged.set(k, v);
    }
  }
  const lines = [];
  for (const [k, v] of merged) {
    if (k !== v) lines.push(`${k}\t${v}`);
  }
  fs.writeFileSync(file, lines.join('\n'), 'utf8');
  console.log(`${path.basename(file)}: ${lines.length} entries`);
}

fs.mkdirSync(outDir, { recursive: true });
// Phrases take precedence over single characters (longest-match in Dart side).
writeTsv(path.join(outDir, 's2t.tsv'), [loadDict('STPhrases'), loadDict('STCharacters')]);
writeTsv(path.join(outDir, 't2s.tsv'), [loadDict('TSPhrases'), loadDict('TSCharacters')]);
console.log('Done.');
