const fs = require('fs');
const path = require('path');

const root = path.join(process.cwd(), 'assets', 'data', 'resources');
const files = fs.readdirSync(root).filter((name) => name.endsWith('.json')).sort();
const books = [];
const byFile = [];
for (const name of files) {
  const file = path.join(root, name);
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const entries = Array.isArray(data.books) ? data.books : [];
  byFile.push({file: name, count: entries.length});
  for (const book of entries) books.push({file: name, ...book});
}
const norm = (v) => String(v || '').trim().toLowerCase().replace(/\s+/g, ' ');
const groups = (items, key) => {
  const map = new Map();
  for (const item of items) {
    const k = key(item);
    if (!k) continue;
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(item);
  }
  return [...map.entries()].filter(([, values]) => values.length > 1);
};
const sourceTypes = {};
for (const book of books) {
  const type = norm(book.freeSourceType) || 'missing';
  sourceTypes[type] = (sourceTypes[type] || 0) + 1;
}
const report = {
  generatedAt: new Date().toISOString(),
  resourceFiles: files.length,
  totalBooks: books.length,
  filesWithBooks: byFile.filter((x) => x.count > 0).length,
  byFile,
  sourceTypes,
  duplicateTitles: groups(books, (b) => norm(b.title)).map(([key, values]) => ({key, files: values.map((v) => v.file)})),
  duplicateUrls: groups(books, (b) => norm(b.freeSourceUrl)).map(([key, values]) => ({key, files: values.map((v) => v.file)})),
  missingRequired: books.filter((b) => !norm(b.title) || !norm(b.author) || !/^https?:\/\//i.test(String(b.freeSourceUrl || ''))).map((b) => ({file: b.file, title: b.title, url: b.freeSourceUrl})),
};
console.log(JSON.stringify(report, null, 2));
