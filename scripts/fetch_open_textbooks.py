from __future__ import annotations

import json
import time
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "research" / "open_textbook_library.json"
BASE_URL = "https://open.umn.edu/opentextbooks/textbooks.json"

all_items = []
page = 1
while True:
    url = f"{BASE_URL}?page={page}"
    req = Request(url, headers={"User-Agent": "Finreels-open-book-research/1.0"})
    with urlopen(req, timeout=60) as response:
        payload = json.load(response)
    batch = payload.get("data", [])
    all_items.extend(batch)
    links = payload.get("links", {})
    next_url = links.get("next")
    if not next_url:
        break
    page += 1
    time.sleep(0.05)

full_payload = {
    "data": all_items,
    "links": {"total_count": len(all_items), "total_pages": page},
    "source": BASE_URL,
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(full_payload, ensure_ascii=False, indent=2), encoding="utf-8")

print(f"saved={OUT}")
print(f"pages={page}")
print(f"items={len(all_items)}")
if all_items:
    print("sample_keys=", sorted(all_items[0].keys()))
    print("sample=", json.dumps(all_items[0], ensure_ascii=False)[:1200])
