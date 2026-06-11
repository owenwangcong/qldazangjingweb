/**
 * Gzip every canon volume from public/data/books into Flutter assets so the
 * app ships fully offline (no network download of scripture text).
 *
 * Usage: node scripts/generate-book-assets.js
 * Output: flutter-app/assets/books/{id}.json.gz
 */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const srcDir = path.join(__dirname, '..', 'public', 'data', 'books');
const outDir = path.join(__dirname, '..', 'flutter-app', 'assets', 'books');

fs.mkdirSync(outDir, { recursive: true });

const files = fs.readdirSync(srcDir).filter((f) => f.endsWith('.json'));
let rawTotal = 0;
let gzTotal = 0;

for (const file of files) {
  const raw = fs.readFileSync(path.join(srcDir, file));
  const gz = zlib.gzipSync(raw, { level: 9 });
  fs.writeFileSync(path.join(outDir, `${file}.gz`), gz);
  rawTotal += raw.length;
  gzTotal += gz.length;
}

console.log(
  `${files.length} books: raw ${(rawTotal / 1048576).toFixed(1)} MB -> ` +
    `gzip ${(gzTotal / 1048576).toFixed(1)} MB ` +
    `(${(100 - (gzTotal / rawTotal) * 100).toFixed(0)}% saved)`,
);
