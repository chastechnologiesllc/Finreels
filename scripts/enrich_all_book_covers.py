from __future__ import annotations

import json
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
REPORT = ROOT / 'docs' / 'research' / 'all_book_cover_enrichment_report.json'
TODAY = '2026-08-24'
DIRECT_FILE_RE = re.compile(r'\.(pdf|epub|zip)(?:$|[?#])', re.I)
PG_RE = re.compile(r'https?://www\.gutenberg\.org/ebooks/(\d+)', re.I)
TRUSTED_PAGE_HOSTS = {
    'openstax.org', 'www.openstax.org', 'open.umn.edu', 'www.open.umn.edu',
    'pressbooks.pub', 'openoregon.pressbooks.pub', 'press.rebus.community',
    'milneopentextbooks.org', 'usq.pressbooks.pub', 'uark.pressbooks.pub',
    'iastate.pressbooks.pub', 'pressbooks.bccampus.ca', 'smarthistory.org',
    'www.openbookpublishers.com', 'vtechworks.lib.vt.edu', 'saylor.org',
    'www.saylor.org', 'archive.org', 'www.archive.org', 'opentextbc.ca',
    'opentext.ku.edu', 'kpu.pressbooks.pub', 'mlpp.pressbooks.pub',
    'oercommons.org', 'oer.galileo.usg.edu', 'commons.libretexts.org',
    'socialsci.libretexts.org', 'biz.libretexts.org', 'textbooks.lib.wvu.edu',
    'books.open.tudelft.nl', 'oaktrust.library.tamu.edu', 'people.cs.uct.ac.za',
    'library.oapen.org', 'pdxscholar.library.pdx.edu', 'ufdc.ufl.edu',
    'wacclearinghouse.org', 'oasis.col.org', 'www.aupress.ca',
}


def norm(value: str) -> str:
    return re.sub(r'[^a-z0-9]+', ' ', value.casefold()).strip()


def meaningful_tokens(value: str) -> set[str]:
    stop = {'the', 'a', 'an', 'of', 'and', 'in', 'to', 'for', 'on', 'with', 'by', 'from', 'book', 'books'}
    return {x for x in norm(value).split() if len(x) > 2 and x not in stop}


def title_matches(book_title: str, page_title: str) -> bool:
    wanted = meaningful_tokens(book_title)
    found = meaningful_tokens(page_title)
    return bool(wanted and found and len(wanted & found) / len(wanted) >= 0.45)


def unique(values: list[str | None]) -> list[str]:
    out: list[str] = []
    for value in values:
        value = (value or '').strip()
        if value and value not in out:
            out.append(value)
    return out


def discover_page_cover(book: dict) -> dict:
    source = str(book.get('freeSourceUrl', '')).strip()
    title = str(book.get('title', '')).strip()
    if not source.startswith('http') or DIRECT_FILE_RE.search(source):
        return {'cover': None, 'reason': 'not_html_source'}
    source_host = urlparse(source).netloc.lower()
    try:
        response = requests.get(
            source,
            headers={'User-Agent': 'FinReels-cover-research/2.0'},
            timeout=12,
            allow_redirects=True,
        )
        if response.status_code >= 400 or 'text/html' not in response.headers.get('content-type', '').lower():
            return {'cover': None, 'reason': f'http_{response.status_code}'}
        soup = BeautifulSoup(response.text, 'html.parser')
        title_tag = soup.find('meta', attrs={'property': 'og:title'})
        page_title = str(title_tag.get('content', '')) if title_tag else ''
        if not page_title and soup.title:
            page_title = soup.title.get_text(' ', strip=True)
        if not title_matches(title, page_title or title):
            return {'cover': None, 'reason': 'page_title_mismatch'}
        image_tag = soup.find('meta', attrs={'property': 'og:image'})
        image = str(image_tag.get('content', '')).strip() if image_tag else ''
        if not image:
            image_link = soup.find('link', attrs={'rel': lambda value: value and 'image_src' in value})
            image = str(image_link.get('href', '')).strip() if image_link else ''
        if not image:
            return {'cover': None, 'reason': 'no_page_image'}
        image = urljoin(response.url, image)
        image_host = urlparse(image).netloc.lower()
        if image_host != source_host and image_host not in TRUSTED_PAGE_HOSTS:
            return {'cover': None, 'reason': 'untrusted_image_host'}
        if any(token in image.casefold() for token in ('placeholder', 'default-cover', 'no-cover', 'logo', 'favicon')):
            return {'cover': None, 'reason': 'placeholder_image'}
        return {'cover': image, 'reason': 'title_matched_page_image'}
    except Exception as exc:
        return {'cover': None, 'reason': str(exc)}


records: list[tuple[Path, int, dict]] = []
for path in sorted(RESOURCE_DIR.glob('*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    for index, book in enumerate(data.get('books', [])):
        candidates = [book.get('coverUrl'), *(book.get('coverCandidates') or [])]
        if any(str(value or '').strip() for value in candidates):
            continue
        records.append((path, index, book))

report = {'date': TODAY, 'scanned': len(records), 'gutenberg': 0, 'pageSpecific': 0, 'unresolved': 0, 'changedFiles': [], 'results': []}
updates: dict[tuple[Path, int], dict] = {}

def process(item: tuple[Path, int, dict]) -> tuple[Path, int, dict, dict]:
    path, index, book = item
    source = str(book.get('freeSourceUrl', '')).strip()
    pg = PG_RE.search(source)
    if pg:
        ebook_id = pg.group(1)
        medium = f'https://www.gutenberg.org/cache/epub/{ebook_id}/pg{ebook_id}.cover.medium.jpg'
        small = f'https://www.gutenberg.org/cache/epub/{ebook_id}/pg{ebook_id}.cover.small.jpg'
        embedded = f'https://www.gutenberg.org/cache/epub/{ebook_id}/images/cover.jpg'
        return path, index, book, {'cover': medium, 'candidates': [medium, small, embedded], 'reason': 'exact_gutenberg_id'}
    result = discover_page_cover(book)
    return path, index, book, result

with ThreadPoolExecutor(max_workers=16) as pool:
    futures = [pool.submit(process, item) for item in records]
    for future in as_completed(futures):
        path, index, book, result = future.result()
        if result.get('cover'):
            cover = result['cover']
            book['coverUrl'] = cover
            book['coverCandidates'] = unique([cover, *(result.get('candidates') or [])])
            updates[(path, index)] = dict(book)
            report['gutenberg' if result['reason'] == 'exact_gutenberg_id' else 'pageSpecific'] += 1
            report['changedFiles'].append(str(path.relative_to(ROOT)))
        else:
            report['unresolved'] += 1
        report['results'].append({'file': str(path.relative_to(ROOT)), 'title': book.get('title', ''), 'reason': result.get('reason', '')})

changed = sorted(set(report['changedFiles']))
for relative in changed:
    path = ROOT / relative
    data = json.loads(path.read_text(encoding='utf-8'))
    for (updated_path, index), book in updates.items():
        if updated_path == path:
            data['books'][index] = book
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
report['changedFiles'] = changed
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: report[k] for k in ('date', 'scanned', 'gutenberg', 'pageSpecific', 'unresolved', 'changedFiles')}, ensure_ascii=False, indent=2))
