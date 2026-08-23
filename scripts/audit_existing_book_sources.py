from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"

by_domain = Counter()
examples = defaultdict(list)
flagged = []
patterns = ("f5fp", "bdebooks", "free-ebooks", "bookdio", "pdf", "download", "archive.org")
for path in sorted(RESOURCE_DIR.glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    for book in data.get("books", []):
        url = str(book.get("freeSourceUrl", "")).strip()
        domain = urlparse(url).netloc.lower() or "(missing)"
        by_domain[domain] += 1
        if len(examples[domain]) < 3:
            examples[domain].append(f"{book.get('title')} -> {url}")
        lowered = url.lower()
        if not url or any(p in lowered for p in patterns):
            flagged.append({"file": path.name, "title": book.get("title"), "url": url, "sourceNote": book.get("freeSourceNote", "")})

print("domains:")
for domain, count in by_domain.most_common():
    print(f"{count:4d} {domain}")
    for item in examples[domain]:
        print(f"      {item}")
print("\nflagged:")
print(json.dumps(flagged, ensure_ascii=False, indent=2))
