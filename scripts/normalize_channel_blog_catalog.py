from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
CATEGORY_FILE = ROOT / "assets" / "data" / "resource_categories.json"
TODAY = "2026-08-23"

categories = json.loads(CATEGORY_FILE.read_text(encoding="utf-8"))["categories"]
canonical_ids = {category["id"] for category in categories}

def key(value: str) -> str:
    return ''.join(ch for ch in value.casefold() if ch.isalnum())

def merge_unique(target: list[dict], incoming: list[dict], field: str) -> list[dict]:
    seen = {key(str(item.get(field, ""))) for item in target if item.get(field)}
    for item in incoming:
        marker = key(str(item.get(field, "")))
        if marker and marker not in seen:
            target.append(item)
            seen.add(marker)
    return target

# Consolidate resource files whose historical filename differs only in
# punctuation/word-joining from the canonical taxonomy ID.
for path in sorted(RESOURCE_DIR.glob("*.json")):
    if path.name == "_general.json":
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    category_id = str(data.get("categoryId", ""))
    if category_id in canonical_ids:
        continue
    matches = [candidate for candidate in canonical_ids if key(candidate) == key(category_id)]
    if not matches:
        continue
    canonical_id = matches[0]
    canonical_path = RESOURCE_DIR / f"{canonical_id}.json"
    canonical = json.loads(canonical_path.read_text(encoding="utf-8")) if canonical_path.exists() else {"categoryId": canonical_id, "status": "verified", "channels": [], "blogs": [], "books": []}
    canonical["channels"] = merge_unique(canonical.get("channels", []), data.get("channels", []), "id")
    canonical["blogs"] = merge_unique(canonical.get("blogs", []), data.get("blogs", []), "url")
    canonical["books"] = merge_unique(canonical.get("books", []), data.get("books", []), "freeSourceUrl")
    canonical["lastUpdated"] = TODAY
    canonical_path.write_text(json.dumps(canonical, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    path.unlink()

# General must be a compact, broad discovery bucket of exactly ten channels
# and ten blogs. Category-specific files carry the larger specialized pools.
general_path = RESOURCE_DIR / "_general.json"
general = json.loads(general_path.read_text(encoding="utf-8"))
preferred_channels = [
    "OpenLearn from The Open University", "MIT OpenCourseWare", "YaleCourses",
    "Stanford Online", "Khan Academy", "CrashCourse", "TED-Ed", "SciShow",
    "3Blue1Brown", "The School of Life",
]
preferred_blogs = [
    "OpenLearn", "MIT OpenCourseWare", "The Conversation", "Greater Good Magazine",
    "Farnam Street", "Ness Labs", "The Decision Lab", "Our World in Data",
    "Smithsonian Magazine", "BBC Future",
]

def select_by_name(items: list[dict], names: list[str], field: str) -> list[dict]:
    by_name = {key(str(item.get("name", ""))): item for item in items}
    chosen = []
    for name in names:
        item = by_name.get(key(name))
        if item:
            chosen.append(item)
    if len(chosen) < 10:
        used = {key(str(item.get(field, ""))) for item in chosen}
        for item in items:
            marker = key(str(item.get(field, "")))
            if marker and marker not in used:
                chosen.append(item)
                used.add(marker)
            if len(chosen) == 10:
                break
    return chosen[:10]

general["channels"] = select_by_name(general.get("channels", []), preferred_channels, "id")
general["blogs"] = select_by_name(general.get("blogs", []), preferred_blogs, "url")
general["lastUpdated"] = TODAY
general["notes"] = (str(general.get("notes", "")).strip() + f" {TODAY}: General is intentionally limited to ten broad discovery channels and ten broad learning blogs; specialized sources live in their categories.").strip()
general_path.write_text(json.dumps(general, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"generalChannels": len(general["channels"]), "generalBlogs": len(general["blogs"]), "canonicalFiles": len(list(RESOURCE_DIR.glob("*.json")))}, indent=2))
