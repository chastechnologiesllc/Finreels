import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / 'tmp/book_sources/pg_catalog.csv'
RESOURCE_DIR = ROOT / 'assets/data/resources'


def clean(value):
    return ' '.join(str(value or '').replace('\n', ' ').split()).strip()

def split_terms(value):
    return [clean(part) for part in str(value or '').split(';') if clean(part)]

def pg_id_from_url(url):
    match = re.search(r'/ebooks/(\d+)', str(url or ''))
    return int(match.group(1)) if match else None

metadata = {}
with CSV_PATH.open(newline='', encoding='utf-8-sig') as fh:
    for row in csv.DictReader(fh):
        try:
            book_id = int(row['Text#'])
        except (TypeError, ValueError):
            continue
        terms = []
        terms.extend(split_terms(row.get('Subjects')))
        terms.extend(split_terms(row.get('Bookshelves')))
        terms.extend(split_terms(row.get('LoCC')))
        metadata[book_id] = list(dict.fromkeys(terms))

changed = 0
records = 0
for path in sorted(RESOURCE_DIR.glob('*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    dirty = False
    for book in data.get('books', []):
        book_id = pg_id_from_url(book.get('freeSourceUrl'))
        if book_id is None or book_id not in metadata:
            continue
        keywords = metadata[book_id]
        if book.get('searchKeywords') != keywords:
            book['searchKeywords'] = keywords
            dirty = True
            changed += 1
        records += 1
    if dirty:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'gutenbergRecordsSeen': records, 'recordsEnriched': changed}, indent=2))
