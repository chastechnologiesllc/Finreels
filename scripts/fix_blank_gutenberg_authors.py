from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
changed = 0
for path in sorted(RESOURCE_DIR.glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    file_changed = 0
    for book in data.get("books", []):
        if str(book.get("freeSourceUrl", "")).startswith("https://www.gutenberg.org/ebooks/") and not str(book.get("author", "")).strip():
            book["author"] = "Unknown author (Project Gutenberg record)"
            file_changed += 1
    if file_changed:
        data["lastUpdated"] = "2026-08-23"
        notes = str(data.get("notes", "")).strip()
        data["notes"] = (notes + " 2026-08-23: Filled missing author metadata on Project Gutenberg records with an explicit fallback rather than leaving the field blank.").strip()
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        changed += file_changed
        print(f"{path.name}: {file_changed}")
print(f"changed={changed}")
