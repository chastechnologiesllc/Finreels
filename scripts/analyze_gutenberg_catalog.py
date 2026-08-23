from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "docs" / "research" / "project_gutenberg_catalog.csv"
with PATH.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

shelves = Counter()
subjects = Counter()
for row in rows:
    for value in row.get("Bookshelves", "").split(";"):
        value = value.strip()
        if value:
            shelves[value] += 1
    for value in row.get("Subjects", "").split(";"):
        value = value.strip()
        if value:
            subjects[value] += 1

print("rows=", len(rows))
print("bookshelves:")
for value, count in shelves.most_common(160):
    print(f"{count:5d}  {value}")
print("subjects:")
for value, count in subjects.most_common(160):
    print(f"{count:5d}  {value}")
