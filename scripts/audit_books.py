from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"

files = sorted(RESOURCE_DIR.glob("*.json"))
all_titles: dict[str, list[str]] = defaultdict(list)
summary = []
errors = []

required_top = {"categoryId", "status", "lastUpdated", "channels", "blogs", "books"}
required_book = {"title", "author", "freeSourceUrl", "freeSourceType", "freeSourceNote", "verifiedOn", "verificationMethod"}

for path in files:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{path.name}: invalid JSON: {exc}")
        continue
    missing_top = required_top - data.keys()
    if missing_top:
        errors.append(f"{path.name}: missing top-level keys: {sorted(missing_top)}")
    books = data.get("books", [])
    if not isinstance(books, list):
        errors.append(f"{path.name}: books is not a list")
        books = []
    for idx, book in enumerate(books):
        if not isinstance(book, dict):
            errors.append(f"{path.name}: books[{idx}] is not an object")
            continue
        missing_book = required_book - book.keys()
        if missing_book:
            errors.append(f"{path.name}: books[{idx}] missing keys: {sorted(missing_book)}")
        title = str(book.get("title", "")).strip().casefold()
        if title:
            all_titles[title].append(path.name)
    summary.append({
        "file": path.name,
        "categoryId": data.get("categoryId"),
        "books": len(books),
        "channels": len(data.get("channels", []) or []),
        "blogs": len(data.get("blogs", []) or []),
        "lastUpdated": data.get("lastUpdated"),
    })

print(json.dumps({
    "resourceFileCount": len(files),
    "categorySummaries": summary,
    "totalBooks": sum(row["books"] for row in summary),
    "duplicateTitlesAcrossFiles": {title: sorted(set(names)) for title, names in all_titles.items() if len(set(names)) > 1},
    "topTitleCounts": Counter(title for title in all_titles for _ in [0]).most_common(10),
    "errors": errors,
}, indent=2, ensure_ascii=False))
