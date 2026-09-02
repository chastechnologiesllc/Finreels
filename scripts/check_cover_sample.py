from __future__ import annotations

import json
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
GENERAL = ROOT / "assets" / "data" / "resources" / "_general.json"
OUT = ROOT / "docs" / "research" / "cover_http_sample_report.json"

books = json.loads(GENERAL.read_text(encoding="utf-8")).get("books", [])
pg_books = [book for book in books if "gutenberg.org/ebooks/" in str(book.get("freeSourceUrl", ""))]
non_pg = [book for book in books if "gutenberg.org/ebooks/" not in str(book.get("freeSourceUrl", "")) and book.get("coverUrl")]
# Spread a deterministic sample across the Gutenberg collection, plus every
# existing non-Gutenberg exact/page-specific cover candidate.
sample = []
step = max(1, len(pg_books) // 120)
sample.extend(pg_books[::step][:120])
sample.extend(non_pg)


def check(url: str) -> dict:
    try:
        response = requests.get(
            url,
            headers={"User-Agent": "Rumuo-cover-validation/1.0"},
            timeout=8,
            stream=True,
            allow_redirects=True,
        )
        result = {
            "url": url,
            "status": response.status_code,
            "contentType": response.headers.get("content-type", ""),
            "ok": response.status_code < 400 and "image" in response.headers.get("content-type", "").lower(),
            "finalUrl": response.url,
        }
        response.close()
        return result
    except Exception as exc:
        return {"url": url, "status": None, "contentType": "", "ok": False, "finalUrl": None, "error": str(exc)}

rows = []
urls = sorted({str(url).strip() for book in sample for url in ([book.get("coverUrl")] + list(book.get("coverCandidates", []))) if str(url).strip()})
with ThreadPoolExecutor(max_workers=12) as pool:
    future_map = {pool.submit(check, url): url for url in urls}
    results = {future_map[f]: f.result() for f in as_completed(future_map)}
for book in sample:
    candidates = [str(book.get("coverUrl", "")).strip(), *[str(url).strip() for url in book.get("coverCandidates", [])]]
    candidates = list(dict.fromkeys(url for url in candidates if url))
    good = [results[url] for url in candidates if results.get(url, {}).get("ok")]
    rows.append({
        "title": book.get("title", ""),
        "source": book.get("freeSourceUrl", ""),
        "candidateCount": len(candidates),
        "firstWorking": good[0]["url"] if good else None,
    })
report = {
    "sampleBooks": len(sample),
    "sampleUrls": len(urls),
    "workingBooks": sum(1 for row in rows if row["firstWorking"]),
    "failedBooks": sum(1 for row in rows if not row["firstWorking"]),
    "workingUrls": sum(1 for result in results.values() if result["ok"]),
    "failedUrls": sum(1 for result in results.values() if not result["ok"]),
    "rows": rows,
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: report[key] for key in report if key != "rows"}, indent=2))
