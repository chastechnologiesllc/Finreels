from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
ADDITION_FILES = [
    ROOT / "docs" / "research" / "pg_general_selected_additions.json",
    ROOT / "docs" / "research" / "pg_trade_selected_additions.json",
]
TODAY = date(2026, 8, 23).isoformat()
DISALLOWED_DOMAINS = {
    "f5fp.com", "www.f5fp.com", "bdebooks.com", "www.bdebooks.com",
    "bookdio.org", "www.bookdio.org", "free-ebooks.net", "www.free-ebooks.net",
}


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def disallowed(url: str) -> bool:
    return urlparse(url).netloc.lower() in DISALLOWED_DOMAINS


def clean(books: list[dict]) -> tuple[list[dict], int, int]:
    kept, seen = [], set()
    removed_source = removed_duplicate = 0
    for book in books:
        url = str(book.get("freeSourceUrl", "")).strip()
        if disallowed(url):
            removed_source += 1
            continue
        key = (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        if not key[0] or key in seen:
            removed_duplicate += 1
            continue
        seen.add(key)
        kept.append(book)
    return kept, removed_source, removed_duplicate


report = {"files": {}, "added": 0, "removedDisallowed": 0, "removedDuplicates": 0}
for addition_file in ADDITION_FILES:
    payload = json.loads(addition_file.read_text(encoding="utf-8"))
    for filename, additions in payload.get("candidates", {}).items():
        path = RESOURCE_DIR / filename
        data = json.loads(path.read_text(encoding="utf-8"))
        before = len(data.get("books", []))
        current, rm_source, rm_dup = clean(data.get("books", []))
        keys = {(normalize(str(book.get("title", ""))), normalize(str(book.get("author", "")))) for book in current}
        appended = []
        for book in additions:
            key = (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
            if key in keys or disallowed(str(book.get("freeSourceUrl", ""))):
                continue
            keys.add(key)
            appended.append(book)
        data["books"] = current + appended
        data["lastUpdated"] = TODAY
        data["notes"] = (str(data.get("notes", "")).strip() + " " + f"{TODAY}: Added {len(appended)} selected Project Gutenberg public-domain non-fiction records to the General collection.").strip()
        action = data.get("actionRequired") if isinstance(data.get("actionRequired"), list) else []
        if appended:
            action.append(f"{TODAY}: Review the {len(appended)} Project Gutenberg additions for pathway sequencing and contemporary-context caveats; public-domain works may be historical.")
        data["actionRequired"] = action
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        report["files"][filename] = {"before": before, "removedDisallowed": rm_source, "removedDuplicates": rm_dup, "added": len(appended), "after": len(data["books"])}
        report["added"] += len(appended)
        report["removedDisallowed"] += rm_source
        report["removedDuplicates"] += rm_dup
print(json.dumps(report, ensure_ascii=False, indent=2))
