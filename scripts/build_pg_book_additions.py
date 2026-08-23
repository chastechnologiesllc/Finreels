from __future__ import annotations

import csv
import json
import re
from collections import defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "docs" / "research" / "project_gutenberg_catalog.csv"
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
OUT_PATH = ROOT / "docs" / "research" / "pg_book_additions.json"
TODAY = date(2026, 8, 23).isoformat()

# High-confidence mapping from Gutenberg's own Bookshelves labels to the
# narrowest useful Finreels category. General gets broad, non-fiction works
# that support lifelong learning; professional categories get only directly
# relevant subject shelves.
SHELF_TARGETS: dict[str, list[str]] = {
    "Category: Health & Medicine": ["profession_01_medicine.json", "_general.json"],
    "Category: Psychiatry/Psychology": ["profession_15_psychology_counselling.json", "_general.json"],
    "Category: Nutrition": ["profession_01_medicine.json", "_general.json"],
    "Category: Drugs/Alcohol/Pharmacology": ["profession_01_medicine.json", "profession_03_pharmacy.json", "_general.json"],
    "Category: Law & Criminology": ["profession_02_law.json", "_general.json"],
    "Category: Economics": ["profession_09_banking_finance.json", "_general.json"],
    "Category: Business/Management": ["profession_09_banking_finance.json", "_general.json"],
    "Category: Engineering & Technology": ["profession_06_engineering.json", "_general.json"],
    "Category: Architecture": ["profession_06_engineering.json", "_general.json"],
    "Category: Science - Physics": ["profession_06_engineering.json", "_general.json"],
    "Category: Science - Chemistry/Biochemistry": ["profession_06_engineering.json", "profession_01_medicine.json", "_general.json"],
    "Category: Science - Biology": ["profession_01_medicine.json", "profession_12_agriculture.json", "_general.json"],
    "Category: Science - Earth/Agricultural/Farming": ["profession_12_agriculture.json", "_general.json"],
    "Category: Mathematics": ["profession_06_engineering.json", "_general.json"],
    "Category: Journalism/Media/Writing": ["profession_10_mass_communication_media_pr.json", "_general.json"],
    "Category: Language & Communication": ["profession_10_mass_communication_media_pr.json", "_general.json"],
    "Category: Sociology": ["profession_15_psychology_counselling.json", "_general.json"],
    "Category: Philosophy & Ethics": ["profession_15_psychology_counselling.json", "_general.json"],
    "Category: History - Modern (1750+)": ["_general.json"],
    "Category: History - Early Modern (c. 1450-1750)": ["_general.json"],
    "Category: History - Ancient": ["_general.json"],
    "Category: History - European": ["_general.json"],
    "Category: History - American": ["_general.json"],
    "Category: History - British": ["_general.json"],
    "Category: History - Other": ["_general.json"],
    "Category: History - Warfare": ["_general.json"],
    "Category: History - Religious": ["_general.json"],
    "Category: Travel Writing": ["_general.json"],
    "Category: Art": ["skill_11_graphic_design.json", "_general.json"],
    "Category: Music": ["_general.json"],
    "Category: Fashion": ["profession_16_fashion_design_tailoring.json", "_general.json"],
    "Category: Cooking & Drinking": ["_general.json"],
    "Category: Parenthood & Family Relations": ["_general.json"],
    "Category: Sports/Hobbies": ["_general.json"],
    "Category: Education": ["profession_13_education.json", "_general.json"],
    "Category: History - Schools & Universities": ["profession_13_education.json", "_general.json"],
}

# These subject terms are strong evidence that an item is fiction or another
# non-book serial/periodical and should not enter the non-fiction collection.
EXCLUDE_SUBJECT_RE = re.compile(
    r"fiction|stories|novel|poetry|poems|drama|plays|detective|mystery|romance|fairy tales|tales|juvenile fiction|periodicals|magazines|newspapers|indexes",
    re.I,
)
EXCLUDE_TITLE_RE = re.compile(r"magazine|journal|newspaper|bulletin|periodical|index$|catalog|directory|annual report|minutes of|prospectus|timetable|price list|address$|inaugural address|lecture notes|first 100 pages", re.I)


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def split_values(value: str) -> list[str]:
    return [part.strip() for part in value.split(";") if part.strip()]


def first_author(value: str) -> str:
    value = value.strip()
    first = re.split(r";|\\|", value)[0].strip() if value else ""
    return first or "Unknown author (Project Gutenberg record)"


with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

existing_by_file: dict[str, set[tuple[str, str]]] = {}
for path in RESOURCE_DIR.glob("*.json"):
    data = json.loads(path.read_text(encoding="utf-8"))
    existing_by_file[path.name] = {
        (normalize(str(book.get("title", ""))), normalize(str(book.get("author", ""))))
        for book in data.get("books", [])
    }

candidates_by_file: dict[str, list[dict]] = defaultdict(list)
seen_by_file: dict[str, set[tuple[str, str]]] = defaultdict(set)

for row in rows:
    if row.get("Type", "").strip() != "Text":
        continue
    if row.get("Language", "").strip() != "en":
        continue
    title = row.get("Title", "").strip()
    if not title or EXCLUDE_TITLE_RE.search(title):
        continue
    subjects = split_values(row.get("Subjects", ""))
    shelves = split_values(row.get("Bookshelves", ""))
    if any(EXCLUDE_SUBJECT_RE.search(subject) for subject in subjects):
        continue
    targets: list[str] = []
    matched_shelves: list[str] = []
    for shelf in shelves:
        for target in SHELF_TARGETS.get(shelf, []):
            if target not in targets:
                targets.append(target)
        if shelf in SHELF_TARGETS:
            matched_shelves.append(shelf)
    if not targets:
        continue
    author = first_author(row.get("Authors", ""))
    key = (normalize(title), normalize(author))
    ebook_id = row.get("Text#", "").strip()
    if not ebook_id.isdigit():
        continue
    url = f"https://www.gutenberg.org/ebooks/{ebook_id}"
    for target in targets:
        if key in existing_by_file.get(target, set()) or key in seen_by_file[target]:
            continue
        entry = {
            "title": title,
            "author": author,
            "freeSourceUrl": url,
            "freeSourceType": "online",
            "freeSourceNote": "Public-domain ebook in Project Gutenberg’s official catalog; complete text and download formats are provided at no cost.",
            "verifiedOn": TODAY,
            "verificationMethod": f"Project Gutenberg catalog record #{ebook_id}; public-domain collection; matched bookshelf: {'; '.join(matched_shelves)}.",
        }
        candidates_by_file[target].append(entry)
        seen_by_file[target].add(key)

result = {
    "source": "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv",
    "retrievedOn": TODAY,
    "policy": "English Text records were considered only when Gutenberg bookshelf labels matched a high-confidence Finreels category and no subject/title exclusion indicated fiction, poetry, drama, or periodicals.",
    "candidateCounts": {name: len(items) for name, items in sorted(candidates_by_file.items())},
    "candidates": {name: items for name, items in sorted(candidates_by_file.items())},
}
OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
OUT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "rows": len(rows),
    "candidateTotal": sum(len(items) for items in candidates_by_file.values()),
    "filesWithCandidates": len(candidates_by_file),
    "candidateCounts": result["candidateCounts"],
    "output": str(OUT_PATH),
}, ensure_ascii=False, indent=2))
