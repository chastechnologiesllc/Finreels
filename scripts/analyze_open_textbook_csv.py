from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "docs" / "research" / "open_textbook_library.csv"

with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

subject_counts = Counter()
license_counts = Counter()
free_format_counts = Counter()
for row in rows:
    for key in ("Subject 1", "Subject 2"):
        value = row.get(key, "").strip()
        if value:
            subject_counts[value] += 1
    license_counts[row.get("License", "").strip() or "(missing)"] += 1
    for i in range(1, 7):
        t = row.get(f"Type {i}", "").strip()
        price = row.get(f"Price {i}", "").strip()
        if t and price == "$0.00":
            free_format_counts[t] += 1

print(f"rows={len(rows)}")
print("subjects:")
for name, count in subject_counts.most_common():
    print(f"{count:4d}  {name}")
print("licenses:")
for name, count in license_counts.most_common():
    print(f"{count:4d}  {name}")
print("free formats:")
for name, count in free_format_counts.most_common():
    print(f"{count:4d}  {name}")
