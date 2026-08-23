from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IN_PATH = ROOT / "docs" / "research" / "pg_book_additions.json"
OUT_PATH = ROOT / "docs" / "research" / "pg_general_selected_additions.json"

MAX_TITLES = 500
priority = [
    "Category: Psychiatry/Psychology",
    "Category: Philosophy & Ethics",
    "Category: Economics",
    "Category: Business/Management",
    "Category: Education",
    "Category: Journalism/Media/Writing",
    "Category: Language & Communication",
    "Category: Sociology",
    "Category: Nutrition",
    "Category: Science - Biology",
    "Category: Science - Physics",
    "Category: Science - Chemistry/Biochemistry",
    "Category: Mathematics",
    "Category: History - Modern (1750+)",
    "Category: History - Early Modern (c. 1450-1750)",
    "Category: History - Ancient",
    "Category: History - European",
    "Category: History - American",
    "Category: History - British",
    "Category: History - Other",
    "Category: Travel Writing",
    "Category: Art",
    "Category: Music",
    "Category: Architecture",
    "Category: Fashion",
    "Category: Cooking & Drinking",
    "Category: Parenthood & Family Relations",
    "Category: Sports/Hobbies",
]

payload = json.loads(IN_PATH.read_text(encoding="utf-8"))
items = payload.get("candidates", {}).get("_general.json", [])
groups = {shelf: [] for shelf in priority}
for item in items:
    match = re.search(r"matched bookshelf: (.+?)\.", item.get("verificationMethod", ""))
    shelves = [s.strip() for s in match.group(1).split(";")] if match else []
    chosen = next((shelf for shelf in priority if shelf in shelves), None)
    if chosen:
        groups[chosen].append(item)

selected = []
# Round-robin preserves breadth and prevents one huge shelf from crowding out
# the rest of the General learning collection.
while len(selected) < MAX_TITLES and any(groups.values()):
    progress = False
    for shelf in priority:
        if groups[shelf] and len(selected) < MAX_TITLES:
            selected.append(groups[shelf].pop(0))
            progress = True
    if not progress:
        break

result = {
    "source": payload.get("source"),
    "retrievedOn": payload.get("retrievedOn"),
    "policy": "Balanced public-domain non-fiction selection from Project Gutenberg shelves; limited to the first 250 deduplicated candidates for the General collection.",
    "selectedCount": len(selected),
    "candidates": {"_general.json": selected},
}
OUT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "availableGeneralCandidates": len(items),
    "selectedCount": len(selected),
    "remainingAfterSelection": len(items) - len(selected),
    "shelfCounts": {shelf: sum(1 for item in selected if shelf in item.get("verificationMethod", "")) for shelf in priority},
    "output": str(OUT_PATH),
}, ensure_ascii=False, indent=2))
