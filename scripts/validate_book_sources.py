from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
OUT = ROOT / "docs" / "research" / "book_source_validation.json"

urls = set()
locations = {}
for path in sorted(RESOURCE_DIR.glob("*.json")):
    data = json.loads(path.read_text(encoding="utf-8"))
    for book in data.get("books", []):
        url = str(book.get("freeSourceUrl", "")).strip()
        if url:
            urls.add(url)
            locations.setdefault(url, []).append({"file": path.name, "title": book.get("title", "")})


def check(url: str) -> dict:
    try:
        req = Request(url, headers={"User-Agent": "Rumuo-open-book-research/1.0"}, method="GET")
        with urlopen(req, timeout=15) as response:
            return {"url": url, "status": response.status, "finalUrl": response.geturl(), "ok": 200 <= response.status < 400}
    except Exception as exc:
        return {"url": url, "status": None, "finalUrl": None, "ok": False, "error": str(exc)}

results = []
with ThreadPoolExecutor(max_workers=16) as pool:
    futures = {pool.submit(check, url): url for url in sorted(urls)}
    for future in as_completed(futures):
        result = future.result()
        result["uses"] = locations.get(result["url"], [])
        results.append(result)

results.sort(key=lambda row: row["url"])
out = {
    "checkedOn": "2026-08-23",
    "uniqueUrlCount": len(urls),
    "okCount": sum(1 for row in results if row["ok"]),
    "failedCount": sum(1 for row in results if not row["ok"]),
    "results": results,
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({k: out[k] for k in ("checkedOn", "uniqueUrlCount", "okCount", "failedCount", "results") if k != "results"}, indent=2))
for row in results:
    if not row["ok"]:
        print(f"FAIL {row['url']} :: {row.get('error', row.get('status'))}")
