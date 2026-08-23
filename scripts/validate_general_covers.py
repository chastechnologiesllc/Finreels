from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
GENERAL = ROOT / "assets" / "data" / "resources" / "_general.json"
PG_RE = re.compile(r"https?://www\.gutenberg\.org/ebooks/(\d+)$", re.I)
PG_COVER_RE = re.compile(r"https://www\.gutenberg\.org/cache/epub/(\d+)/pg\1\.cover\.(medium|small)\.jpg$", re.I)
ALLOWED_SCHEMES = {"https"}

payload = json.loads(GENERAL.read_text(encoding="utf-8"))
books = payload.get("books", [])
errors: list[dict] = []
counts = Counter()
for index, book in enumerate(books):
    source = str(book.get("freeSourceUrl", "")).strip()
    primary = str(book.get("coverUrl", "")).strip()
    fallback_candidates = [str(url).strip() for url in book.get("coverCandidates", []) if str(url).strip()]
    candidates = [primary, *fallback_candidates] if primary else fallback_candidates
    deduped = list(dict.fromkeys(candidates))
    for url in deduped:
        parsed = urlparse(url)
        if parsed.scheme not in ALLOWED_SCHEMES or not parsed.netloc:
            errors.append({"index": index, "title": book.get("title"), "url": url, "error": "unsafe cover URL"})
    pg = PG_RE.fullmatch(source)
    if pg:
        ebook_id = pg.group(1)
        expected = f"https://www.gutenberg.org/cache/epub/{ebook_id}/pg{ebook_id}.cover.medium.jpg"
        if primary != expected:
            errors.append({"index": index, "title": book.get("title"), "error": "Gutenberg primary cover does not match source ebook ID", "expected": expected, "actual": primary})
        if not any(PG_COVER_RE.fullmatch(url) and f"/epub/{ebook_id}/pg{ebook_id}.cover." in url for url in deduped):
            errors.append({"index": index, "title": book.get("title"), "error": "missing Gutenberg exact-edition fallback"})
        counts["gutenberg_with_cover"] += 1
    elif deduped:
        counts["non_gutenberg_with_cover"] += 1
    else:
        counts["no_verified_cover"] += 1

report = {
    "books": len(books),
    "booksWithCoverCandidates": counts["gutenberg_with_cover"] + counts["non_gutenberg_with_cover"],
    "gutenbergWithExactIdCovers": counts["gutenberg_with_cover"],
    "nonGutenbergWithVerifiedCovers": counts["non_gutenberg_with_cover"],
    "withoutVerifiedCover": counts["no_verified_cover"],
    "errors": errors,
}
print(json.dumps(report, ensure_ascii=False, indent=2))
if errors:
    raise SystemExit(1)
