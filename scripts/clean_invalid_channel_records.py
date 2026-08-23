from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
TODAY = '2026-08-23'
CHANNEL_ID = re.compile(r'^UC[\w-]{22}$')

removed = {'invalidChannels': 0, 'duplicateChannels': 0, 'duplicateBlogs': 0}
for path in sorted(RESOURCE_DIR.glob('*.json')):
    data = json.loads(path.read_text(encoding='utf-8'))
    clean_channels = []
    seen_ids = set()
    for item in data.get('channels', []):
        channel_id = str(item.get('id', ''))
        if not CHANNEL_ID.fullmatch(channel_id):
            removed['invalidChannels'] += 1
            continue
        if channel_id in seen_ids:
            removed['duplicateChannels'] += 1
            continue
        seen_ids.add(channel_id)
        clean_channels.append(item)
    clean_blogs = []
    seen_urls = set()
    for item in data.get('blogs', []):
        url = str(item.get('url', '')).rstrip('/')
        if not url or url in seen_urls:
            removed['duplicateBlogs'] += 1
            continue
        seen_urls.add(url)
        clean_blogs.append(item)
    data['channels'] = clean_channels
    data['blogs'] = clean_blogs
    data['lastUpdated'] = TODAY
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(removed, indent=2))
