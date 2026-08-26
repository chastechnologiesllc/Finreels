import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / 'tmp/book_sources/pg_catalog.csv'
CATEGORY_PATH = ROOT / 'assets/data/resource_categories.json'
RESOURCE_DIR = ROOT / 'assets/data/resources'


def norm(value):
    return re.sub(r'[^a-z0-9]+', ' ', str(value or '').lower()).strip()


def tokens(value):
    return set(norm(value).split())

categories = json.loads(CATEGORY_PATH.read_text())['categories']
existing_titles = set()
for path in RESOURCE_DIR.glob('*.json'):
    try:
        data = json.loads(path.read_text())
    except Exception:
        continue
    for book in data.get('books', []):
        title = norm(book.get('title'))
        if title:
            existing_titles.add(title)

# Explicit domain signals keep the assignment explainable and prevent a generic
# title from being forced into a category solely because of a single common word.
DOMAIN_TERMS = {
    'law': ['law', 'legal', 'constitution', 'justice', 'court', 'crime', 'criminal', 'rights', 'jurisprudence', 'attorney'],
    'medicine': ['medicine', 'medical', 'doctor', 'physician', 'surgery', 'nursing', 'health', 'disease', 'anatomy', 'physiology'],
    'teaching': ['education', 'teaching', 'school', 'teacher', 'pedagogy', 'instruction', 'child study'],
    'accounting': ['accounting', 'bookkeeping', 'finance', 'financial', 'banking', 'economics', 'business', 'commerce', 'investment'],
}

rows = []
with CSV_PATH.open(newline='', encoding='utf-8-sig') as fh:
    for row in csv.DictReader(fh):
        if row.get('Type') != 'Text' or row.get('Language') != 'en':
            continue
        title = (row.get('Title') or '').replace('\n', ' ').strip()
        author = (row.get('Authors') or '').replace('\n', ' ').strip()
        if not title or not author or norm(title) in existing_titles:
            continue
        meta = ' '.join([title, row.get('Subjects') or '', row.get('LoCC') or '', row.get('Bookshelves') or ''])
        meta_norm = norm(meta)
        score_by_category = []
        for category in categories:
            hay = meta_norm
            name = norm(category['name'])
            aliases = [norm(x) for x in category.get('searchKeywords', [])]
            score = 0
            reasons = []
            if name and name in hay:
                score += 8
                reasons.append('category-name')
            for alias in aliases:
                if alias and alias in hay:
                    score += 3
                    reasons.append(f'keyword:{alias}')
            # For multiword category names, reward each meaningful word but avoid
            # common stopwords and tiny fragments.
            for word in tokens(name):
                if len(word) >= 5 and word in hay.split():
                    score += 1
            if score:
                score_by_category.append((score, category['id'], category['name'], reasons[:6]))
        # Keep a general bucket for books that are clearly useful but lack a
        # conservative category match; category assignment is never fabricated.
        score_by_category.sort(reverse=True)
        rows.append({
            'id': int(row['Text#']),
            'title': title,
            'author': author,
            'subjects': row.get('Subjects') or '',
            'bookshelves': row.get('Bookshelves') or '',
            'locc': row.get('LoCC') or '',
            'issued': row.get('Issued') or '',
            'matches': score_by_category[:5],
        })

print(json.dumps({
    'catalogRows': sum(1 for _ in csv.DictReader(CSV_PATH.open(newline='', encoding='utf-8-sig'))),
    'eligibleEnglishTextRows': len(rows),
    'existingTitleCount': len(existing_titles),
    'highConfidenceByScore': {
        str(threshold): sum(1 for r in rows if r['matches'] and r['matches'][0][0] >= threshold)
        for threshold in [3, 5, 8]
    },
    'topCategoryDistribution': Counter(r['matches'][0][2] for r in rows if r['matches']).most_common(80),
    'sampleTopMatches': [r for r in rows if r['matches']][:30],
}, indent=2))
