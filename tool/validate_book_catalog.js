const fs = require('fs');
const path = require('path');
const root = path.join(process.cwd(), 'assets', 'data', 'resources');
let count = 0;
let keywordCount = 0;
const urls = new Set();
const duplicateUrls = [];
for (const name of fs.readdirSync(root).filter((n) => n.endsWith('.json')).sort()) {
  const file = path.join(root, name);
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Array.isArray(data.books)) {
    if (name === '_profession_open_catalog.json' && Array.isArray(data.categories)) continue;
    throw new Error(`${name} missing books array`);
  }
  for (const book of data.books) {
    count += 1;
    if (!book.title || !book.author || !/^https?:\/\//.test(book.freeSourceUrl || '')) {
      throw new Error(`Invalid required fields in ${name}: ${JSON.stringify(book)}`);
    }
    if (Array.isArray(book.searchKeywords) && book.searchKeywords.length > 0) keywordCount += 1;
    const url = String(book.freeSourceUrl).trim().toLowerCase();
    if (urls.has(url)) duplicateUrls.push(url);
    urls.add(url);
  }
}
JSON.parse(fs.readFileSync('assets/data/resource_categories.json', 'utf8'));
JSON.parse(fs.readFileSync('docs/research/gutenberg_import_manifest_2026-08-26.json', 'utf8'));
console.log(JSON.stringify({bookEntries: count, uniqueSourceUrls: urls.size, duplicateSourceUrls: duplicateUrls.length, withSearchKeywords: keywordCount, targetReached: count >= 20000}, null, 2));
