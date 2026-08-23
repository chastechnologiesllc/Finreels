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
OUT_PATH = ROOT / "docs" / "research" / "pg_trade_additions.json"
TODAY = date(2026, 8, 23).isoformat()

# Practical, high-confidence keyword mappings. These are intentionally narrow
# and are supplemental rather than substitutes for current standards.
TARGET_RULES: dict[str, list[str]] = {
    "profession_12_agriculture.json": [r"farm", r"agricultur", r"agronom", r"crop", r"soil", r"horticultur", r"forestr", r"dairy", r"beekeep", r"garden"],
    "business_10_poultry_farming.json": [r"poultry", r"chicken", r"fowl", r"hen", r"egg", r"poultryman"],
    "business_11_fish_farming.json": [r"fish", r"fisher", r"aquaculture", r"piscicultur", r"pond"],
    "business_04_food_vending_catering_meal_prep.json": [r"cookery", r"cooking", r"food", r"culinary", r"kitchen", r"cater"],
    "profession_18_catering_event_planning.json": [r"cookery", r"cooking", r"food", r"culinary", r"kitchen", r"cater"],
    "skill_15_catering_baking.json": [r"cookery", r"cooking", r"food", r"culinary", r"baking", r"bread", r"pastry", r"cake", r"confection"],
    "business_13_bakery_confectionery.json": [r"baking", r"bread", r"pastry", r"cake", r"confection"],
    "skill_01_tailoring_fashion_design.json": [r"sewing", r"dressmak", r"tailor", r"garment", r"needlework", r"fashion"],
    "profession_16_fashion_design_tailoring.json": [r"sewing", r"dressmak", r"tailor", r"garment", r"needlework", r"fashion"],
    "skill_05_welding_metal_fabrication.json": [r"weld", r"metalwork", r"metal work", r"forge", r"foundry", r"smithing"],
    "skill_06_carpentry_furniture_making.json": [r"carpentr", r"woodwork", r"cabinet", r"furniture", r"joinery"],
    "skill_07_plumbing.json": [r"plumb", r"pipe[- ]?fitt", r"sanitary"],
    "skill_08_electrical_installation_wiring.json": [r"electric", r"wiring", r"electrical", r"dynamo", r"motor"],
    "skill_09_auto_mechanics.json": [r"automobile", r"motor car", r"motor vehicle", r"auto repair", r"motor mechanic", r"gasoline engine"],
    "profession_19_automobile_technology.json": [r"automobile", r"motor car", r"motor vehicle", r"auto repair", r"motor mechanic", r"gasoline engine"],
    "skill_13_photography.json": [r"photograph", r"camera", r"photographic"],
    "profession_20_photography_videography.json": [r"photograph", r"camera", r"photographic", r"cinematograph", r"motion picture"],
    "skill_14_videography_video_editing.json": [r"cinematograph", r"motion picture", r"film[- ]?making", r"moving picture"],
    "skill_17_shoemaking_leatherwork.json": [r"shoemak", r"shoe[- ]?making", r"leather", r"bootmak", r"tanning"],
    "business_15_phone_gadget_sales_repair.json": [r"wireless", r"radio", r"telegraph", r"telephone", r"electronic"],
    "skill_10_phone_electronics_repair.json": [r"wireless", r"radio", r"telegraph", r"telephone", r"electronic"],
    "skill_20_ac_refrigeration_repair.json": [r"refrigerat", r"ice[- ]?mak", r"cold storage", r"air conditioning"],
    "business_12_laundry_dry_cleaning.json": [r"laundr", r"dry cleaning", r"washing", r"soap[- ]?making"],
    "business_14_cosmetics_skincare.json": [r"cosmetic", r"perfum", r"toilet soap", r"skin care", r"beauty culture"],
    "business_18_cleaning_services.json": [r"cleaning", r"sanitation", r"janitor", r"housekeeping"],
    "business_19_pure_water_sachet_bottled_water.json": [r"water purification", r"water supply", r"sanitation", r"drinking water"],
    "profession_07_architecture.json": [r"architect", r"building construction", r"building design"],
    "profession_08_estate_management_surveying.json": [r"surveying", r"land survey", r"real estate", r"property management"],
    "profession_14_dentistry.json": [r"dentist", r"dentistry", r"dental"],
    "skill_18_pop_tiling_interior_decor.json": [r"plaster", r"tiling", r"tile", r"masonry", r"interior decoration", r"house painting"],
}

EXCLUDE_RE = re.compile(r"fiction|stories|novel|poetry|poems|drama|plays|detective|mystery|romance|fairy tales|tales|juvenile fiction|periodicals|magazines|newspapers|indexes", re.I)
EXCLUDE_TITLE_RE = re.compile(r"magazine|journal|newspaper|bulletin|periodical|index$", re.I)


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def values(value: str) -> list[str]:
    return [part.strip() for part in value.split(";") if part.strip()]


def author(value: str) -> str:
    value = value.strip()
    first = re.split(r";|\\|", value)[0].strip() if value else ""
    return first or "Project Gutenberg contributors"

with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
    rows = list(csv.DictReader(f))

existing_by_file = {}
for path in RESOURCE_DIR.glob("*.json"):
    data = json.loads(path.read_text(encoding="utf-8"))
    existing_by_file[path.name] = {(normalize(str(b.get("title", ""))), normalize(str(b.get("author", "")))) for b in data.get("books", [])}

candidates = defaultdict(list)
seen = defaultdict(set)
for row in rows:
    if row.get("Type", "").strip() != "Text" or row.get("Language", "").strip() != "en":
        continue
    title = row.get("Title", "").strip()
    subjects = " ".join(values(row.get("Subjects", "")))
    shelves = " ".join(values(row.get("Bookshelves", "")))
    corpus = f"{title} {subjects} {shelves}"
    if not title or EXCLUDE_TITLE_RE.search(title) or EXCLUDE_RE.search(subjects):
        continue
    ebook_id = row.get("Text#", "").strip()
    if not ebook_id.isdigit():
        continue
    matches = []
    for filename, patterns in TARGET_RULES.items():
        if any(re.search(pattern, corpus, re.I) for pattern in patterns):
            matches.append(filename)
    if not matches:
        continue
    book_author = author(row.get("Authors", ""))
    key = (normalize(title), normalize(book_author))
    for filename in matches:
        if key in existing_by_file.get(filename, set()) or key in seen[filename]:
            continue
        candidates[filename].append({
            "title": title,
            "author": book_author,
            "freeSourceUrl": f"https://www.gutenberg.org/ebooks/{ebook_id}",
            "freeSourceType": "online",
            "freeSourceNote": "Public-domain supplemental practical resource in Project Gutenberg’s official catalog; historical content must be paired with current standards where applicable.",
            "verifiedOn": TODAY,
            "verificationMethod": f"Project Gutenberg catalog record #{ebook_id}; matched practical keyword rule from title/subject metadata.",
        })
        seen[filename].add(key)

result = {
    "source": "https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv",
    "retrievedOn": TODAY,
    "policy": "Conservative keyword matching for trade and vocational categories; excluded fiction, poetry, drama, periodicals, and duplicate title-author pairs.",
    "candidateCounts": {name: len(items) for name, items in sorted(candidates.items())},
    "candidates": {name: items for name, items in sorted(candidates.items())},
}
OUT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "rows": len(rows),
    "candidateTotal": sum(len(items) for items in candidates.values()),
    "filesWithCandidates": len(candidates),
    "candidateCounts": result["candidateCounts"],
    "output": str(OUT_PATH),
}, ensure_ascii=False, indent=2))
