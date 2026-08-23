import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
data = json.loads((root / "assets/data/resource_categories.json").read_text())
categories = data["categories"]
assert categories, "category catalog is empty"
assert len({item["id"] for item in categories}) == len(categories), "duplicate category ids"
assert len({item["name"].casefold() for item in categories}) == len(categories), "duplicate category names"

medicine = [item for item in categories if item["name"].casefold() == "medicine"]
assert len(medicine) == 1, "Medicine category missing or duplicated"
assert isinstance(medicine[0].get("searchKeywords", []), list), "Medicine keywords are not indexed as a list"

for item in categories:
    assert item.get("name", "").strip(), f"blank category name: {item.get('id')}"
    for keyword in item.get("searchKeywords", []):
        assert isinstance(keyword, str) and keyword.strip(), f"blank keyword: {item['id']}"

print(f"categories={len(categories)}")
print(f"medicine_id={medicine[0]['id']}")
print(f"medicine_keywords={len(medicine[0].get('searchKeywords', []))}")
print("index_audit=passed")
