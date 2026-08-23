from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "docs" / "research" / "open_textbook_library.csv"
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
OUT_PATH = ROOT / "docs" / "research" / "otl_book_additions.json"
TODAY = date(2026, 8, 23).isoformat()

# Only high-confidence subject-to-category mappings are used in this first pass.
SUBJECT_TARGETS: dict[str, list[str]] = {
    "Business - Accounting": ["profession_05_accounting.json"],
    "Business - Finance": ["profession_09_banking_finance.json"],
    "Social Sciences - Economics": ["profession_09_banking_finance.json"],
    "Finance": ["profession_09_banking_finance.json"],
    "Law": ["profession_02_law.json"],
    "Law - Civil Law": ["profession_02_law.json"],
    "Law - Administrative Law": ["profession_02_law.json"],
    "Law - Contract Law": ["profession_02_law.json"],
    "Law - Procedural Law": ["profession_02_law.json"],
    "Law - Criminal Law": ["profession_02_law.json"],
    "Law - Property Law": ["profession_02_law.json"],
    "Law - Constitutional Law": ["profession_02_law.json"],
    "Medicine": ["profession_01_medicine.json"],
    "Medicine - Public Health": ["profession_01_medicine.json"],
    "Medicine - Nutrition": ["profession_01_medicine.json"],
    "Medicine - Anatomy": ["profession_01_medicine.json"],
    "Medicine - Clinical Physiology": ["profession_01_medicine.json"],
    "Medicine - Pharmacology": ["profession_03_pharmacy.json"],
    "Medicine - Nursing": ["profession_04_nursing.json"],
    "Computer Science": ["profession_11_computer_science_software_engineering.json", "skill_12_web_app_development.json"],
    "Computer Science - Programming Languages": ["profession_11_computer_science_software_engineering.json", "skill_12_web_app_development.json"],
    "Computer Science - Information Systems": ["profession_11_computer_science_software_engineering.json"],
    "Computer Science - Databases": ["profession_11_computer_science_software_engineering.json", "skill_12_web_app_development.json"],
    "Computer Science - Artificial Intelligence": ["profession_11_computer_science_software_engineering.json", "online_hustles_10_ai_services.json"],
    "Computer Science - Cryptography": ["profession_11_computer_science_software_engineering.json"],
    "Engineering & Technology": ["profession_06_engineering.json"],
    "Engineering & Technology - Electrical Engineering": ["profession_06_engineering.json", "skill_08_electrical_installation_wiring.json"],
    "Engineering & Technology - Mechanical Engineering": ["profession_06_engineering.json", "profession_19_automobile_technology.json", "skill_09_auto_mechanics.json"],
    "Engineering & Technology - Civil Engineering": ["profession_06_engineering.json", "skill_07_plumbing.json"],
    "Engineering & Technology - Chemical Engineering": ["profession_06_engineering.json"],
    "Engineering & Technology - Materials Science": ["profession_06_engineering.json", "skill_05_welding_metal_fabrication.json"],
    "Education": ["profession_13_education.json", "_general.json"],
    "Education - Curriculum & Instruction": ["profession_13_education.json"],
    "Education - Higher Education": ["profession_13_education.json", "_general.json"],
    "Education - Early Childhood": ["profession_13_education.json"],
    "Education - Distance Education": ["profession_13_education.json", "business_16_private_tutorial_online_tutoring.json", "online_hustles_07_online_tutoring.json", "_general.json"],
    "Education - Elementary Education": ["profession_13_education.json"],
    "Education - Secondary Education": ["profession_13_education.json"],
    "Social Sciences - Psychology": ["profession_15_psychology_counselling.json", "_general.json"],
    "Psychology": ["profession_15_psychology_counselling.json", "_general.json"],
    "Journalism, Media Studies & Communications": ["profession_10_mass_communication_media_pr.json"],
    "Journalism, Media Studies & Communications - New Media Journalism": ["profession_10_mass_communication_media_pr.json", "online_hustles_14_blogging_seo.json"],
    "Journalism, Media Studies & Communications - Technical Writing": ["profession_10_mass_communication_media_pr.json", "online_hustles_03_freelance_writing.json"],
    "Journalism, Media Studies & Communications - Organizational Communication": ["profession_10_mass_communication_media_pr.json"],
    "Journalism, Media Studies & Communications - Intercultural Communication": ["profession_10_mass_communication_media_pr.json"],
    "Journalism, Media Studies & Communications - Print Journalism": ["profession_10_mass_communication_media_pr.json"],
    "Journalism, Media Studies & Communications - Speech Communication": ["profession_10_mass_communication_media_pr.json"],
    "Humanities - Arts": ["skill_11_graphic_design.json", "profession_20_photography_videography.json", "_general.json"],
    "Humanities - Philosophy": ["_general.json"],
    "Student Success": ["_general.json"],
    "Business - Marketing": ["business_20_social_media_digital_marketing_agency.json", "online_hustles_14_blogging_seo.json", "online_hustles_15_ads_management.json"],
    "Business - Entrepreneurship": ["business_20_social_media_digital_marketing_agency.json", "online_hustles_20_digital_agency.json"],
    "Business - Human Resources": ["_general.json"],
}


def normalize(value: str) -> str:
    value = value.casefold()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def author_from_contributors(value: str, publisher: str) -> str:
    value = value.strip()
    if value:
        first = re.split(r";|\\|", value)[0].strip()
        first = re.sub(r"\s+-\s+(Author|Editor|Contributor|Illustrator)\s*$", "", first, flags=re.I)
        return first or value
    return publisher.strip() or "Open Textbook Library contributors"


def choose_free_source(row: dict[str, str]) -> tuple[str, str] | None:
    for i in range(1, 7):
        kind = row.get(f"Type {i}", "").strip()
        url = row.get(f"URL {i}", "").strip()
        price = row.get(f"Price {i}", "").strip()
        if kind in {"Online", "PDF", "eBook"} and url and price == "$0.00":
            return kind.lower(), url
    return None


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
source_count = Counter()
subject_count = Counter()

for row in rows:
    source = choose_free_source(row)
    license_name = row.get("License", "").strip()
    title = row.get("Title", "").strip()
    if not source or not license_name or not title:
        continue
    author = author_from_contributors(row.get("Contributors", ""), row.get("Publisher", ""))
    subjects = [row.get("Subject 1", "").strip(), row.get("Subject 2", "").strip()]
    targets = []
    matched_subjects = []
    for subject in subjects:
        for target in SUBJECT_TARGETS.get(subject, []):
            if target not in targets:
                targets.append(target)
        if subject in SUBJECT_TARGETS:
            matched_subjects.append(subject)
    if not targets:
        continue

    source_type, source_url = source
    library_url = row.get("Library URL", "").strip()
    key = (normalize(title), normalize(author))
    for target in targets:
        if key in existing_by_file.get(target, set()) or key in seen_by_file[target]:
            continue
        entry = {
            "title": title,
            "author": author,
            "freeSourceUrl": source_url,
            "freeSourceType": source_type,
            "freeSourceNote": f"Openly licensed textbook ({license_name}) with a $0.00 {source_type} format in the Open Textbook Library catalog.",
            "verifiedOn": TODAY,
            "verificationMethod": f"Open Textbook Library catalog record; subject match: {'; '.join(matched_subjects)}; license: {license_name}; catalog record: {library_url}",
        }
        isbn13 = row.get("ISBN13", "").strip()
        if isbn13:
            entry["coverUrl"] = f"https://covers.openlibrary.org/b/isbn/{quote(isbn13)}-L.jpg"
        candidates_by_file[target].append(entry)
        seen_by_file[target].add(key)
        source_count[source_type] += 1
        for subject in matched_subjects:
            subject_count[subject] += 1

result = {
    "source": "https://open.umn.edu/opentextbooks/download.csv",
    "retrievedOn": TODAY,
    "policy": "Only records with a non-empty license and a $0.00 Online, PDF, or eBook format were considered; existing title-author duplicates were excluded.",
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
    "freeSourceTypes": dict(source_count),
    "matchedSubjects": dict(subject_count),
    "output": str(OUT_PATH),
}, ensure_ascii=False, indent=2))
