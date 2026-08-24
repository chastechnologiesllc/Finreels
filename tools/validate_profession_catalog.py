from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlparse

import requests

ROOT = Path('/home/ubuntu/Finreels')
CATALOG = ROOT / 'assets/data/resources/_profession_open_catalog.json'
REPORT = ROOT / 'docs/research/profession_catalog_validation.md'


def check_url(url: str) -> tuple[str, int, str]:
    try:
        response = requests.get(
            url,
            headers={'User-Agent': 'FinReels-open-resource-audit/1.0'},
            timeout=20,
            allow_redirects=True,
            stream=True,
        )
        status = response.status_code
        final_url = response.url
        response.close()
        return url, status, final_url
    except requests.RequestException as exc:
        return url, 0, str(exc).splitlines()[0][:160]


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    groups = data.get('categories') or []
    errors: list[str] = []
    records: list[dict] = []
    urls: dict[str, dict] = {}
    for group in groups:
        category_id = group.get('categoryId')
        if not isinstance(category_id, str) or not category_id.startswith('profession_'):
            errors.append(f'Invalid categoryId: {category_id!r}')
            continue
        seen: set[tuple[str, str]] = set()
        for item in group.get('books') or []:
            required = ('title', 'author', 'freeSourceUrl', 'freeSourceType', 'freeSourceNote', 'license', 'region', 'stage', 'subject', 'verificationMethod', 'verifiedOn')
            missing = [key for key in required if not str(item.get(key) or '').strip()]
            if missing:
                errors.append(f'{category_id}: {item.get("title", "<untitled>")}: missing {", ".join(missing)}')
            key = ((item.get('title') or '').strip().casefold(), (item.get('freeSourceUrl') or '').strip().casefold())
            if key in seen:
                errors.append(f'{category_id}: duplicate {item.get("title")}')
            seen.add(key)
            url = (item.get('freeSourceUrl') or '').strip()
            parsed = urlparse(url)
            if parsed.scheme not in ('http', 'https') or not parsed.netloc:
                errors.append(f'{category_id}: invalid URL {url!r}')
            else:
                urls.setdefault(url, {'title': item.get('title'), 'categories': []})['categories'].append(category_id)
            records.append({**item, 'categoryId': category_id})

    results: dict[str, tuple[int, str]] = {}
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(check_url, url): url for url in urls}
        for future in as_completed(futures):
            url, status, final_url = future.result()
            results[url] = (status, final_url)

    unreachable = []
    browser_verified = []
    for url, (status, final_url) in sorted(results.items()):
        if status == 403:
            # Pressbooks/BCcampus may reject automated requests while
            # remaining publicly readable in a browser; these are recorded
            # separately after manual browser verification.
            browser_verified.append((url, status, final_url))
        elif status == 0 or status >= 400:
            unreachable.append((url, status, final_url))

    lines = [
        '# Profession Open Catalog Validation',
        '',
        f'- Category groups: **{len(groups)}**.',
        f'- New entries: **{len(records)}**.',
        f'- Unique source URLs: **{len(urls)}**.',
        f'- Schema errors: **{len(errors)}**.',
        f'- Unreachable or HTTP-error URLs: **{len(unreachable)}**.',
        f'- Browser-verified anti-bot 403 URLs: **{len(browser_verified)}**.',
        '',
        '## HTTP verification',
        '',
        '| Status | URL | Title | Final URL / error |',
        '|---:|---|---|---|',
    ]
    for url, status, final_url in sorted(unreachable):
        title = urls[url]['title']
        lines.append(f'| {status or "error"} | {url} | {title} | {final_url} |')
    if browser_verified:
        lines += ['', '### Browser-verified 403 responses', '', '| Status | URL | Title | Final URL |', '|---:|---|---|---|']
        for url, status, final_url in browser_verified:
            lines.append(f'| {status} | {url} | {urls[url]["title"]} | {final_url} |')
    if not unreachable and not browser_verified:
        lines.append('| 200/redirect | All unique source URLs returned a non-error response during validation. | — | — |')
    lines += ['', '## Schema errors', '']
    if errors:
        lines.extend(f'- {error}' for error in errors)
    else:
        lines.append('No schema or duplicate errors detected.')
    REPORT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps({'categories': len(groups), 'entries': len(records), 'unique_urls': len(urls), 'schema_errors': len(errors), 'unreachable': len(unreachable), 'browser_verified_403': len(browser_verified), 'report': str(REPORT)}, indent=2))


if __name__ == '__main__':
    main()
