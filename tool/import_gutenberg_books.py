import csv
import json
import os
import re
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / 'tmp/book_sources/pg_catalog.csv'
CATEGORY_PATH = ROOT / 'assets/data/resource_categories.json'
RESOURCE_DIR = ROOT / 'assets/data/resources'
MANIFEST_PATH = ROOT / 'docs/research/gutenberg_import_manifest_2026-08-26.json'
TARGET_TOTAL = int(os.environ.get('TARGET_TOTAL', '20000'))

GENERIC = {
    'a', 'an', 'and', 'are', 'business', 'care', 'content', 'course', 'digital',
    'design', 'development', 'education', 'engineering', 'finance', 'for', 'from',
    'general', 'health', 'in', 'learning', 'management', 'marketing', 'media',
    'of', 'online', 'practice', 'professional', 'science', 'service', 'services',
    'social', 'technology', 'the', 'to', 'trade', 'work', 'writing',
}

def norm(value):
    return re.sub(r'[^a-z0-9]+', ' ', str(value or '').lower()).strip()

def words(value):
    return {w for w in norm(value).split() if len(w) >= 3 and w not in GENERIC}

def phrase_hits(phrases, text):
    return [p for p in phrases if p and p in text]

def resource_file_by_category():
    out = {}
    for path in RESOURCE_DIR.glob('*.json'):
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
        except Exception:
            continue
        cid = data.get('categoryId')
        if isinstance(cid, str) and cid:
            out[cid] = path
    return out

categories = json.loads(CATEGORY_PATH.read_text(encoding='utf-8'))['categories']
file_by_category = resource_file_by_category()
existing = []
existing_titles = set()
existing_urls = set()
for path in RESOURCE_DIR.glob('*.json'):
    data = json.loads(path.read_text(encoding='utf-8'))
    for book in data.get('books', []):
        existing.append(book)
        title = norm(book.get('title'))
        url = norm(book.get('freeSourceUrl'))
        if title:
            existing_titles.add(title)
        if url:
            existing_urls.add(url)

# High-confidence category vocabulary. A title/subject/bookshelf must contain
# either a multi-word category/keyword phrase or a strong non-generic token.
category_vocab = {}
for category in categories:
    name = norm(category['name'])
    keywords = [norm(k) for k in category.get('searchKeywords', [])]
    strong_name = ' '.join(w for w in name.split() if w not in GENERIC and len(w) >= 4)
    strong_keywords = [k for k in keywords if len(k.split()) > 1 or any(w not in GENERIC and len(w) >= 5 for w in k.split())]
    strong_tokens = set()
    for value in [name, *keywords]:
        strong_tokens.update(words(value))
    category_vocab[category['id']] = {
        'name': category['name'],
        'name_phrase': name,
        'strong_name': strong_name,
        'phrases': sorted(set([p for p in [name, strong_name, *strong_keywords] if len(p) >= 5]), key=len, reverse=True),
        'tokens': strong_tokens,
    }

rows = []
with CSV_PATH.open(newline='', encoding='utf-8-sig') as fh:
    for row in csv.DictReader(fh):
        if row.get('Type') != 'Text' or row.get('Language') != 'en':
            continue
        try:
            pg_id = int(row['Text#'])
        except (TypeError, ValueError):
            continue
        title = ' '.join((row.get('Title') or '').split()).strip()
        author = ' '.join((row.get('Authors') or '').split()).strip()
        if not title or not author:
            continue
        title_key = norm(title)
        url = f'https://www.gutenberg.org/ebooks/{pg_id}'
        if title_key in existing_titles or norm(url) in existing_urls:
            continue
        subjects = ' '.join((row.get('Subjects') or '').split())
        shelves = ' '.join((row.get('Bookshelves') or '').split())
        locc = ' '.join((row.get('LoCC') or '').split())
        title_text = norm(title)
        metadata_text = norm(' '.join([title, subjects, shelves, locc]))
        title_tokens = words(title)
        meta_tokens = words(metadata_text)
        matches = []
        for category in categories:
            vocab = category_vocab[category['id']]
            score = 0
            reasons = []
            for phrase in phrase_hits(vocab['phrases'], metadata_text):
                score += 50 if phrase in title_text else 28
                reasons.append(f'phrase:{phrase}')
            title_strong = title_tokens & vocab['tokens']
            meta_strong = meta_tokens & vocab['tokens']
            if title_strong:
                score += 24 * min(2, len(title_strong))
                reasons.append('title-token:' + ','.join(sorted(title_strong)))
            if meta_strong:
                score += 10 * min(3, len(meta_strong))
                reasons.append('subject-token:' + ','.join(sorted(meta_strong)))
            if score >= 45:
                matches.append((score, category['id'], category['name'], reasons[:5]))
        matches.sort(key=lambda x: (-x[0], x[2], x[1]))
        rows.append({
            'id': pg_id,
            'title': title,
            'author': author,
            'subjects': subjects,
            'shelves': shelves,
            'locc': locc,
            'issued': row.get('Issued') or '',
            'matches': matches,
        })

# Prefer category-assigned records, cap any one category so mass categories do
# not absorb the entire expansion, then fill the remaining target from general.
category_buckets = defaultdict(list)
for row in rows:
    if row['matches']:
        category_buckets[row['matches'][0][1]].append(row)
for bucket in category_buckets.values():
    bucket.sort(key=lambda r: (-r['matches'][0][0], r['id']))

current_total = len(existing)
needed = max(0, TARGET_TOTAL - current_total)
selected = []
assigned = {}
CATEGORY_CAP = 350
for category in categories:
    bucket = category_buckets.get(category['id'], [])
    for row in bucket[:CATEGORY_CAP]:
        if len(selected) >= needed:
            break
        selected.append(row)
        assigned[row['id']] = category['id']
    if len(selected) >= needed:
        break
if len(selected) < needed:
    selected_ids = {r['id'] for r in selected}
    general_candidates = [r for r in rows if r['id'] not in selected_ids]
    general_candidates.sort(key=lambda r: (0 if r['matches'] else 1, -((r['matches'][0][0]) if r['matches'] else 0), r['id']))
    selected.extend(general_candidates[:needed - len(selected)])

# Construct entries with authoritative source links and explicit jurisdiction note.
def book_entry(row):
    pg_id = row['id']
    subjects = row['subjects']
    subject = subjects.split(';')[0].strip() if subjects else None
    return {
        'title': row['title'],
        'author': row['author'],
        'freeSourceUrl': f'https://www.gutenberg.org/ebooks/{pg_id}',
        'freeSourceType': 'web',
        'freeSourceNote': 'Project Gutenberg edition. Public-domain status follows Project Gutenberg policy and can vary by jurisdiction; readers should check local copyright law.',
        'verificationMethod': f'Imported from Project Gutenberg official pg_catalog.csv (ebook {pg_id}); English Text record with catalog subjects/bookshelves and stable ebook URL.',
        'coverUrl': f'https://www.gutenberg.org/cache/epub/{pg_id}/pg{pg_id}.cover.medium.jpg',
        'coverCandidates': [
            f'https://www.gutenberg.org/cache/epub/{pg_id}/pg{pg_id}.cover.medium.jpg',
            f'https://www.gutenberg.org/cache/epub/{pg_id}/pg{pg_id}.cover.small.jpg',
        ],
        'subject': subject,
        'region': 'Global',
        'license': 'Project Gutenberg public-domain edition; jurisdiction varies',
    }

by_file = defaultdict(list)
for row in selected:
    cid = assigned.get(row['id'])
    by_file[cid or '_general'].append(book_entry(row))

# Write only the required number of new records, preserving all existing arrays
# and object fields in each resource file.
for cid, additions in by_file.items():
    path = RESOURCE_DIR / '_general.json' if cid == '_general' else file_by_category.get(cid)
    if path is None:
        raise RuntimeError(f'No resource file for category {cid}')
    data = json.loads(path.read_text(encoding='utf-8'))
    data.setdefault('books', []).extend(additions)
    data['lastUpdated'] = str(date.today())
    data.setdefault('notes', '')
    note = f' Added {len(additions)} Project Gutenberg public-domain catalog records with source links and cover candidates on {date.today()}.'
    data['notes'] = (str(data['notes']).rstrip() + note).strip()
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

manifest = {
    'generatedOn': str(date.today()),
    'source': 'https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv',
    'sourcePolicy': 'English Text records from Project Gutenberg official catalog; public-domain status is jurisdiction-specific.',
    'currentEntriesBeforeImport': current_total,
    'targetEntries': TARGET_TOTAL,
    'newEntriesImported': len(selected),
    'totalEntriesAfterImport': current_total + len(selected),
    'uniqueExistingTitlesBeforeImport': len(existing_titles),
    'candidateRowsAfterExistingTitleExclusion': len(rows),
    'categoryAssignedNewEntries': sum(1 for r in selected if r['id'] in assigned),
    'generalNewEntries': sum(1 for r in selected if r['id'] not in assigned),
    'categoryCounts': Counter(assigned.values()),
    'sampleAssigned': [
        {'id': r['id'], 'title': r['title'], 'categoryId': assigned.get(r['id'], '_general'), 'match': r['matches'][0] if r['matches'] else None}
        for r in selected[:100]
    ],
}
manifest['categoryCounts'] = dict(manifest['categoryCounts'])
MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: manifest[k] for k in ['currentEntriesBeforeImport', 'targetEntries', 'newEntriesImported', 'totalEntriesAfterImport', 'categoryAssignedNewEntries', 'generalNewEntries']}, indent=2))
