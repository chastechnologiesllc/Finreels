from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path('/home/ubuntu/Rumuo')
CSV_PATH = Path('/home/ubuntu/upload/MBBS_Textbooks_Nigeria_Africa_Global.csv')
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
CATEGORIES_PATH = ROOT / 'assets' / 'data' / 'resource_categories.json'
OUT_PATH = ROOT / 'docs' / 'research' / 'profession_catalog_audit.md'


def load_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def main() -> None:
    with CSV_PATH.open(newline='', encoding='utf-8-sig') as handle:
        mbbs_rows = list(csv.DictReader(handle))

    categories = load_json(CATEGORIES_PATH).get('categories', [])
    category_by_id = {item.get('id'): item for item in categories}
    files = sorted(RESOURCE_DIR.glob('*.json'))
    profession_files = [path for path in files if path.name.startswith('profession_')]

    rows = []
    section_books = Counter()
    region_counts = Counter()
    source_type_counts = Counter()
    license_signal_counts = Counter()
    empty_book_fields = Counter()
    duplicate_keys = Counter()

    for path in files:
        data = load_json(path)
        category_id = data.get('categoryId')
        section = category_id.split('_', 1)[0] if category_id else 'general'
        books = data.get('books') or []
        for book in books:
            title = (book.get('title') or '').strip()
            author = (book.get('author') or '').strip()
            url = (book.get('freeSourceUrl') or '').strip()
            key = (title.casefold(), author.casefold(), url.casefold())
            duplicate_keys[key] += 1
            section_books[section] += 1
            source_type_counts[(book.get('freeSourceType') or 'missing').strip().lower()] += 1
            if not title:
                empty_book_fields['title'] += 1
            if not author or author.casefold() == 'unknown':
                empty_book_fields['author'] += 1
            if not url:
                empty_book_fields['freeSourceUrl'] += 1
            note = ' '.join(str(book.get(field) or '') for field in ('freeSourceNote', 'verificationMethod'))
            lower_note = note.casefold()
            has_license = any(token in lower_note for token in ('license', 'licensed', 'openly licensed', 'public domain', 'open access', 'creative commons', 'cc by', 'cc-by'))
            license_signal_counts['with_license_signal' if has_license else 'without_license_signal'] += 1
            region = (book.get('region') or '').strip() or 'unspecified'
            region_counts[region] += 1
            rows.append({
                'category_id': category_id,
                'section': section,
                'file': path.name,
                'title': title,
                'author': author,
                'url': url,
                'source_type': book.get('freeSourceType') or 'missing',
                'region': region,
                'has_license_signal': has_license,
            })

    duplicate_groups = [key for key, count in duplicate_keys.items() if count > 1 and key != ('', '', '')]
    profession_summary = []
    for path in profession_files:
        data = load_json(path)
        category_id = data.get('categoryId')
        category = category_by_id.get(category_id, {})
        profession_summary.append({
            'id': category_id,
            'name': category.get('name') or category_id,
            'books': len(data.get('books') or []),
            'channels': len(data.get('channels') or []),
            'blogs': len(data.get('blogs') or []),
            'updated': data.get('lastUpdated'),
        })

    lines = [
        '# Profession Resource Catalog Audit',
        '',
        'This report is generated from the supplied MBBS CSV and the checked-in Rumuo resource assets. It is an audit only; it does not treat copyrighted textbook titles as free resources and does not add any unverified links.',
        '',
        '## Input coverage',
        '',
        f'- Supplied MBBS rows: **{len(mbbs_rows)}**.',
        f'- Profession JSON files found: **{len(profession_files)}**.',
        f'- All resource JSON files scanned: **{len(files)}**.',
        f'- Existing book records scanned: **{len(rows)}**.',
        f'- Duplicate title/author/source groups: **{len(duplicate_groups)}**.',
        '',
        '## Profession coverage',
        '',
        '| Profession asset | Category | Books | Channels | Blogs | Last updated |',
        '|---|---|---:|---:|---:|---|',
    ]
    for item in profession_summary:
        lines.append(f"| `{item['id']}` | {item['name']} | {item['books']} | {item['channels']} | {item['blogs']} | {item['updated'] or 'missing'} |")

    lines += [
        '',
        '## Existing book-data quality signals',
        '',
        '| Signal | Count |',
        '|---|---:|',
    ]
    for key, count in sorted(empty_book_fields.items()):
        lines.append(f'| Missing or weak `{key}` | {count} |')
    for key, count in sorted(license_signal_counts.items()):
        lines.append(f'| {key.replace("_", " ").capitalize()} | {count} |')
    lines += [
        '',
        '### Source types',
        '',
        '| Type | Count |',
        '|---|---:|',
    ]
    for key, count in sorted(source_type_counts.items()):
        lines.append(f'| `{key}` | {count} |')
    lines += [
        '',
        '### Regions explicitly recorded on book records',
        '',
        '| Region | Count |',
        '|---|---:|',
    ]
    for key, count in sorted(region_counts.items()):
        lines.append(f'| {key} | {count} |')
    lines += [
        '',
        '## Supplied MBBS CSV subjects',
        '',
        '| Stage | Subject | Approximate years | Rows |',
        '|---|---|---|---:|',
    ]
    subject_counts = Counter((row.get('Stage'), row.get('Subject'), row.get('Year_Approx')) for row in mbbs_rows)
    for (stage, subject, years), count in sorted(subject_counts.items()):
        lines.append(f'| {stage} | {subject} | {years} | {count} |')
    lines += [
        '',
        '## Research and integration policy',
        '',
        'The next catalog pass should add only resources with a directly verifiable free access path and an explicit legal basis such as an open textbook license, public-domain status, an official government or institutional open publication, or a publisher-authorized free edition. Commercial textbook titles in the supplied MBBS list are useful as curriculum references, but they must not be linked as free books unless an authorized open copy is verified.',
        '',
        'Resources should be tagged by profession, subject, progression level, geography, source type, license evidence, verification date, and canonical URL. A single global textbook may be linked to multiple profession categories only when the subject overlap is explicit; duplicate records should be canonicalized rather than copied blindly.',
    ]
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps({
        'mbbs_rows': len(mbbs_rows),
        'profession_files': len(profession_files),
        'resource_files': len(files),
        'book_records': len(rows),
        'duplicate_groups': len(duplicate_groups),
        'license_signals': dict(license_signal_counts),
        'source_types': dict(source_type_counts),
        'region_counts': dict(region_counts),
        'report': str(OUT_PATH),
    }, indent=2))


if __name__ == '__main__':
    main()
