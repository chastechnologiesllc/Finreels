from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
CATEGORY_FILE = ROOT / 'assets' / 'data' / 'resource_categories.json'

category_ids = {item['id'] for item in json.loads(CATEGORY_FILE.read_text())['categories']}
files = sorted(RESOURCE_DIR.glob('*.json'))
report = {'files': len(files), 'errors': [], 'underTarget': [], 'general': None, 'totals': {'channels': 0, 'blogs': 0}}

for path in files:
    try:
        data = json.loads(path.read_text())
    except Exception as exc:
        report['errors'].append(f'{path.name}: invalid JSON: {exc}')
        continue
    if path.name == '_general.json':
        target_channels = target_blogs = 10
        report['general'] = {'channels': len(data.get('channels', [])), 'blogs': len(data.get('blogs', []))}
    else:
        target_channels = target_blogs = 20
        if data.get('categoryId') not in category_ids:
            report['errors'].append(f'{path.name}: categoryId is not in resource_categories.json')
    channels = data.get('channels', [])
    blogs = data.get('blogs', [])
    report['totals']['channels'] += len(channels)
    report['totals']['blogs'] += len(blogs)
    if len(channels) < target_channels or len(blogs) < target_blogs:
        report['underTarget'].append({'file': path.name, 'channels': len(channels), 'blogs': len(blogs), 'target': target_channels})
    channel_ids = [str(item.get('id', '')) for item in channels]
    duplicate_channels = sorted({value for value in channel_ids if value and channel_ids.count(value) > 1})
    if duplicate_channels:
        report['errors'].append(f'{path.name}: duplicate channel IDs: {duplicate_channels}')
    blog_urls = [str(item.get('url', '')).rstrip('/') for item in blogs]
    duplicate_blogs = sorted({value for value in blog_urls if value and blog_urls.count(value) > 1})
    if duplicate_blogs:
        report['errors'].append(f'{path.name}: duplicate blog URLs: {duplicate_blogs}')
    for item in channels:
        if not re.fullmatch(r'UC[\w-]{22}', str(item.get('id', ''))):
            report['errors'].append(f'{path.name}: invalid channel ID for {item.get("name", "unnamed")}')
        if not str(item.get('handle', '')).startswith('@'):
            report['errors'].append(f'{path.name}: invalid handle for {item.get("name", "unnamed")}')
        for field in ('name', 'description', 'focus', 'verificationMethod'):
            if not str(item.get(field, '')).strip():
                report['errors'].append(f'{path.name}: channel {item.get("name", "unnamed")} missing {field}')
    for item in blogs:
        url = str(item.get('url', ''))
        if not re.match(r'^https?://', url):
            report['errors'].append(f'{path.name}: invalid blog URL {url}')
        for field in ('name', 'focus', 'verificationMethod'):
            if not str(item.get(field, '')).strip():
                report['errors'].append(f'{path.name}: blog {item.get("name", "unnamed")} missing {field}')

print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(1 if report['errors'] or report['underTarget'] else 0)
