from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
CATEGORY_FILE = ROOT / 'assets' / 'data' / 'resource_categories.json'

canonical = {item['id'] for item in json.loads(CATEGORY_FILE.read_text())['categories']}
changed = []
for path in sorted(RESOURCE_DIR.glob('*.json')):
    if path.name == '_general.json':
        continue
    data = json.loads(path.read_text())
    stem = path.stem
    if stem in canonical and data.get('categoryId') != stem:
        old = data.get('categoryId')
        data['categoryId'] = stem
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        changed.append({'file': path.name, 'old': old, 'new': stem})
print(json.dumps({'changed': len(changed), 'items': changed}, ensure_ascii=False, indent=2))
