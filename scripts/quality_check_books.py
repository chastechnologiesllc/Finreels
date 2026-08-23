from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
DISALLOWED_DOMAINS = {
    "f5fp.com", "www.f5fp.com", "bdebooks.com", "www.bdebooks.com",
    "bookdio.org", "www.bookdio.org", "free-ebooks.net", "www.free-ebooks.net",
}
REQUIRED = {"title", "author", "freeSourceUrl", "freeSourceType", "freeSourceNote", "verifiedOn", "verificationMethod"}

def norm(value: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", value.casefold())).strip()

files = sorted(RESOURCE_DIR.glob("*.json"))
errors = []
blank_author = []
disallowed = []
missing_url = []
duplicates = []
counts = Counter()
all_titles = defaultdict(list)
for path in files:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{path.name}: invalid JSON: {exc}")
        continue
    books = data.get("books")
    if not isinstance(books, list):
        errors.append(f"{path.name}: books is not a list")
        continue
    seen = set()
    for index, book in enumerate(books):
        if not isinstance(book, dict):
            errors.append(f"{path.name}: books[{index}] is not an object")
            continue
        missing = REQUIRED - book.keys()
        if missing:
            errors.append(f"{path.name}: books[{index}] missing {sorted(missing)}")
        title = str(book.get("title", "")).strip()
        author = str(book.get("author", "")).strip()
        url = str(book.get("freeSourceUrl", "")).strip()
        if not author:
            blank_author.append({"file": path.name, "title": title})
        if not url:
            missing_url.append({"file": path.name, "title": title})
        if urlparse(url).netloc.lower() in DISALLOWED_DOMAINS:
            disallowed.append({"file": path.name, "title": title, "url": url})
        key = (norm(title), norm(author))
        if key in seen:
            duplicates.append({"file": path.name, "title": title, "author": author})
        seen.add(key)
        all_titles[key].append(path.name)
    counts[path.name] = len(books)

report = {
    "files": len(files),
    "totalBooks": sum(counts.values()),
    "jsonErrors": errors,
    "blankAuthors": blank_author,
    "missingUrls": missing_url,
    "disallowedHosts": disallowed,
    "withinFileDuplicates": duplicates,
    "categoryCounts": dict(counts),
    "crossFileDuplicateTitleAuthorPairs": sum(1 for key, paths in all_titles.items() if len(set(paths)) > 1),
}
print(json.dumps(report, ensure_ascii=False, indent=2))
if errors or blank_author or missing_url or disallowed or duplicates:
    raise SystemExit(1)
