from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
ADDITIONS = ROOT / "docs" / "research" / "otl_book_additions.json"
TODAY = date(2026, 8, 23).isoformat()

# These hosts are explicitly rejected by the free-book brief because they are
# unauthorized-looking file mirrors or generic ebook sites rather than a
# clearly legitimate publisher, library, university, author, or government
# source. Internet Archive is deliberately not in this set: its lending model
# is legal, although those entries are recorded as borrowable rather than
# downloadable.
DISALLOWED_DOMAINS = {
    "f5fp.com",
    "www.f5fp.com",
    "bdebooks.com",
    "www.bdebooks.com",
    "bookdio.org",
    "www.bookdio.org",
    "free-ebooks.net",
    "www.free-ebooks.net",
}


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def is_disallowed(url: str) -> bool:
    return urlparse(url).netloc.lower() in DISALLOWED_DOMAINS


def dedupe_books(books: list[dict]) -> tuple[list[dict], int, int]:
    kept = []
    seen = set()
    removed_source = 0
    removed_duplicate = 0
    for book in books:
        url = str(book.get("freeSourceUrl", "")).strip()
        if is_disallowed(url):
            removed_source += 1
            continue
        key = (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        if not key[0]:
            continue
        if key in seen:
            removed_duplicate += 1
            continue
        seen.add(key)
        kept.append(book)
    return kept, removed_source, removed_duplicate


additions = json.loads(ADDITIONS.read_text(encoding="utf-8"))["candidates"]
report = {"files": {}, "removedDisallowed": 0, "removedDuplicates": 0, "added": 0}

for filename, new_books in additions.items():
    path = RESOURCE_DIR / filename
    data = json.loads(path.read_text(encoding="utf-8"))
    original_books = data.get("books", [])
    existing_books, removed_source, removed_duplicate = dedupe_books(original_books)
    existing_keys = {
        (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        for book in existing_books
    }
    appended = []
    for book in new_books:
        key = (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        if key in existing_keys:
            continue
        existing_keys.add(key)
        appended.append(book)
    final_books = existing_books + appended
    data["books"] = final_books
    data["lastUpdated"] = TODAY
    note = (
        f"{TODAY}: Added {len(appended)} high-confidence openly licensed textbook records "
        "from the Open Textbook Library catalog; records were limited to titles with a non-empty license and a $0.00 Online, PDF, or eBook format."
    )
    notes = str(data.get("notes", "")).strip()
    data["notes"] = (notes + " " + note).strip()
    action_required = data.get("actionRequired")
    if not isinstance(action_required, list):
        action_required = []
    if removed_source:
        action_required.append(
            f"{TODAY}: Removed {removed_source} existing book entries hosted on disallowed generic or unauthorized-looking ebook domains; these require replacement with legitimate free sources."
        )
    if appended:
        action_required.append(
            f"{TODAY}: Review the {len(appended)} Open Textbook Library additions for pathway sequencing and local relevance before promoting them in the UI."
        )
    data["actionRequired"] = action_required
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report["files"][filename] = {
        "before": len(original_books),
        "removedDisallowed": removed_source,
        "removedDuplicates": removed_duplicate,
        "added": len(appended),
        "after": len(final_books),
    }
    report["removedDisallowed"] += removed_source
    report["removedDuplicates"] += removed_duplicate
    report["added"] += len(appended)

print(json.dumps(report, ensure_ascii=False, indent=2))
