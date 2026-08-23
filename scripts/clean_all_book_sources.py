from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
TODAY = "2026-08-23"
DISALLOWED_DOMAINS = {
    "f5fp.com", "www.f5fp.com", "bdebooks.com", "www.bdebooks.com",
    "bookdio.org", "www.bookdio.org", "free-ebooks.net", "www.free-ebooks.net",
}


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()

report = {}
for path in sorted(RESOURCE_DIR.glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    books = data.get("books", [])
    kept = []
    seen = set()
    removed_source = removed_duplicate = 0
    for book in books:
        url = str(book.get("freeSourceUrl", "")).strip()
        if urlparse(url).netloc.lower() in DISALLOWED_DOMAINS:
            removed_source += 1
            continue
        key = (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        if not key[0] or key in seen:
            removed_duplicate += 1
            continue
        seen.add(key)
        kept.append(book)
    if removed_source or removed_duplicate:
        data["books"] = kept
        data["lastUpdated"] = TODAY
        notes = str(data.get("notes", "")).strip()
        data["notes"] = (notes + " " + f"{TODAY}: Removed disallowed generic or unauthorized-looking ebook hosts and duplicate book records during repository-wide compliance cleanup.").strip()
        action = data.get("actionRequired") if isinstance(data.get("actionRequired"), list) else []
        action.append(f"{TODAY}: Re-research removed entries using a legitimate open, public-domain, institutional, government, or author-controlled source before adding replacements.")
        data["actionRequired"] = action
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report[path.name] = {"before": len(books), "removedDisallowed": removed_source, "removedDuplicates": removed_duplicate, "after": len(kept)}

print(json.dumps({
    "files": len(report),
    "changedFiles": sum(1 for row in report.values() if row["removedDisallowed"] or row["removedDuplicates"]),
    "removedDisallowed": sum(row["removedDisallowed"] for row in report.values()),
    "removedDuplicates": sum(row["removedDuplicates"] for row in report.values()),
    "report": report,
}, ensure_ascii=False, indent=2))
