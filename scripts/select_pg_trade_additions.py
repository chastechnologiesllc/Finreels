from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IN_PATH = ROOT / "docs" / "research" / "pg_trade_additions.json"
OUT_PATH = ROOT / "docs" / "research" / "pg_trade_selected_additions.json"

MAX_BY_FILE = {
    "profession_12_agriculture.json": 80,
    "business_10_poultry_farming.json": 60,
    "business_11_fish_farming.json": 60,
    "business_04_food_vending_catering_meal_prep.json": 40,
    "profession_18_catering_event_planning.json": 40,
    "skill_15_catering_baking.json": 40,
    "business_13_bakery_confectionery.json": 40,
    "business_14_cosmetics_skincare.json": 20,
    "business_15_phone_gadget_sales_repair.json": 40,
    "skill_10_phone_electronics_repair.json": 40,
    "business_18_cleaning_services.json": 30,
    "business_19_pure_water_sachet_bottled_water.json": 30,
    "profession_07_architecture.json": 60,
    "profession_08_estate_management_surveying.json": 30,
    "profession_14_dentistry.json": 20,
    "profession_16_fashion_design_tailoring.json": 50,
    "skill_01_tailoring_fashion_design.json": 50,
    "profession_19_automobile_technology.json": 35,
    "skill_09_auto_mechanics.json": 35,
    "profession_20_photography_videography.json": 50,
    "skill_13_photography.json": 40,
    "skill_14_videography_video_editing.json": 30,
    "skill_05_welding_metal_fabrication.json": 30,
    "skill_06_carpentry_furniture_making.json": 50,
    "skill_07_plumbing.json": 25,
    "skill_08_electrical_installation_wiring.json": 50,
    "skill_17_shoemaking_leatherwork.json": 20,
    "skill_18_pop_tiling_interior_decor.json": 50,
    "skill_20_ac_refrigeration_repair.json": 10,
}

payload = json.loads(IN_PATH.read_text(encoding="utf-8"))
selected = {}
for filename, items in payload.get("candidates", {}).items():
    cap = MAX_BY_FILE.get(filename, 0)
    if cap <= 0:
        continue
    # Prefer titles that explicitly contain a target keyword, then subject
    # matches. This avoids importing every book that merely shares a broad
    # bookshelf label.
    def score(item: dict) -> tuple[int, str]:
        title = item.get("title", "")
        method = item.get("verificationMethod", "")
        title_score = 0 if not re.search(r"farm|fish|poultry|chicken|cooking|baking|bread|cake|cosmetic|electronic|clean|architecture|survey|dent|fashion|tailor|automobile|motor|photograph|film|weld|metal|carpentr|wood|plumb|electric|shoe|leather|tile|refrigerat|water|soap|laundr|agricultur|crop|soil|garden|food|culinary|kitchen", title, re.I) else 10
        return (-(title_score), title.casefold())
    ordered = sorted(items, key=score)
    selected[filename] = ordered[:cap]

result = {
    "source": payload.get("source"),
    "retrievedOn": payload.get("retrievedOn"),
    "policy": "Selected only bounded, title-relevant public-domain supplemental resources from the targeted Gutenberg candidates; historical works require current-practice review.",
    "selectedCounts": {name: len(items) for name, items in sorted(selected.items())},
    "candidates": {name: items for name, items in sorted(selected.items())},
}
OUT_PATH.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({
    "selectedTotal": sum(len(items) for items in selected.values()),
    "selectedCounts": result["selectedCounts"],
    "output": str(OUT_PATH),
}, ensure_ascii=False, indent=2))
