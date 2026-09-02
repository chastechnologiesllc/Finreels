from __future__ import annotations

import json
from pathlib import Path

ROOT = Path('/home/ubuntu/Rumuo/assets/data/resources')
terms = [
    'openstax', 'engineering', 'architecture', 'law', 'accounting', 'finance',
    'agriculture', 'education', 'psychology', 'communication', 'photography',
    'nursing', 'anatomy', 'microbiology', 'chemistry', 'biology', 'statistics',
    'marketing', 'management', 'economics', 'computer', 'python', 'data',
]
for path in sorted(ROOT.glob('profession_*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    print(f"\n## {data.get('categoryId')} ({len(data.get('books') or [])} books)")
    for book in data.get('books') or []:
        title = book.get('title', '')
        note = ' '.join(str(book.get(key) or '') for key in ('freeSourceNote', 'verificationMethod'))
        haystack = f"{title} {note}".casefold()
        if any(term in haystack for term in terms):
            print(f"- {title} | {book.get('freeSourceUrl', '')}")
