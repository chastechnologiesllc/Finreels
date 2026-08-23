from __future__ import annotations

import json
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
GENERAL = RESOURCE_DIR / "_general.json"
REPORT = ROOT / "docs" / "research" / "cover_enrichment_report.json"
TODAY = "2026-08-23"

TRUSTED_PAGE_HOSTS = {
    "open.umn.edu", "www.open.umn.edu", "openstax.org", "www.openstax.org",
    "pressbooks.pub", "openoregon.pressbooks.pub", "press.rebus.community",
    "milneopentextbooks.org", "usq.pressbooks.pub", "uark.pressbooks.pub",
    "iastate.pressbooks.pub", "pressbooks.bccampus.ca", "smarthistory.org",
    "www.openbookpublishers.com", "vtechworks.lib.vt.edu", "saylor.org",
    "www.saylor.org", "archive.org", "www.archive.org",
}
DIRECT_FILE_RE = re.compile(r"\.(pdf|epub|zip)(?:$|[?#])", re.I)
PG_RE = re.compile(r"https?://www\.gutenberg\.org/ebooks/(\d+)", re.I)


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.casefold()).strip()


def meaningful_tokens(value: str) -> set[str]:
    stop = {"the", "a", "an", "of", "and", "in", "to", "for", "on", "with", "by", "from", "book", "books"}
    return {token for token in norm(value).split() if len(token) > 2 and token not in stop}


def page_title_matches(book_title: str, page_title: str) -> bool:
    wanted = meaningful_tokens(book_title)
    found = meaningful_tokens(page_title)
    if not wanted or not found:
        return False
    return len(wanted & found) / len(wanted) >= 0.45


def unique_urls(*groups: list[str | None]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for group in groups:
        for value in group:
            if not value:
                continue
            value = value.strip()
            if value and value not in seen:
                seen.add(value)
                out.append(value)
    return out


def page_cover(book: dict) -> dict:
    source = str(book.get("freeSourceUrl", "")).strip()
    title = str(book.get("title", "")).strip()
    if not source or not source.startswith("http") or DIRECT_FILE_RE.search(source):
        return {"url": source, "cover": None, "reason": "not_an_html_source"}
    host = urlparse(source).netloc.lower()
    try:
        response = requests.get(
            source,
            headers={"User-Agent": "Finreels-cover-research/1.0"},
            timeout=12,
            allow_redirects=True,
        )
        if response.status_code >= 400 or "text/html" not in response.headers.get("content-type", "").lower():
            return {"url": source, "cover": None, "reason": f"http_{response.status_code}"}
        soup = BeautifulSoup(response.text, "html.parser")
        og_title = ""
        title_tag = soup.find("meta", attrs={"property": "og:title"})
        if title_tag:
            og_title = str(title_tag.get("content", ""))
        if not og_title and soup.title:
            og_title = soup.title.get_text(" ", strip=True)
        if not page_title_matches(title, og_title or title):
            return {"url": source, "cover": None, "reason": "page_title_mismatch", "pageTitle": og_title}
        image_tag = soup.find("meta", attrs={"property": "og:image"})
        image_url = str(image_tag.get("content", "")).strip() if image_tag else ""
        if not image_url:
            image_link = soup.find("link", attrs={"rel": lambda value: value and "image_src" in value})
            image_url = str(image_link.get("href", "")).strip() if image_link else ""
        if not image_url:
            return {"url": source, "cover": None, "reason": "no_og_image"}
        image_url = urljoin(response.url, image_url)
        image_host = urlparse(image_url).netloc.lower()
        if image_host != host and image_host not in TRUSTED_PAGE_HOSTS:
            return {"url": source, "cover": None, "reason": "untrusted_image_host", "imageHost": image_host}
        if any(token in image_url.casefold() for token in ("placeholder", "default-cover", "no-cover", "logo")):
            return {"url": source, "cover": None, "reason": "placeholder_image"}
        return {"url": source, "cover": image_url, "reason": "page_specific_og_image", "pageTitle": og_title}
    except Exception as exc:
        return {"url": source, "cover": None, "reason": str(exc)}


data = json.loads(GENERAL.read_text(encoding="utf-8"))
books = data.get("books", [])
report = {"date": TODAY, "gutenberg": 0, "pageSpecific": 0, "existingPreserved": 0, "unresolved": 0, "results": []}

# First pass: exact Gutenberg ID covers require no page scraping.
page_candidates = []
for index, book in enumerate(books):
    source = str(book.get("freeSourceUrl", "")).strip()
    pg = PG_RE.search(source)
    if pg:
        ebook_id = pg.group(1)
        medium = f"https://www.gutenberg.org/cache/epub/{ebook_id}/pg{ebook_id}.cover.medium.jpg"
        small = f"https://www.gutenberg.org/cache/epub/{ebook_id}/pg{ebook_id}.cover.small.jpg"
        embedded = f"https://www.gutenberg.org/cache/epub/{ebook_id}/images/cover.jpg"
        book["coverUrl"] = medium
        book["coverCandidates"] = unique_urls([medium, small, embedded], book.get("coverCandidates", []))
        report["gutenberg"] += 1
        continue
    if book.get("coverUrl") or book.get("coverCandidates"):
        current = [book.get("coverUrl"), *(book.get("coverCandidates") or [])]
        book["coverCandidates"] = unique_urls(current)
        report["existingPreserved"] += 1
    page_candidates.append((index, book))

# The non-Gutenberg remainder is small enough to fetch in parallel. Only
# source-page images with title agreement and trusted hosts are accepted.
with ThreadPoolExecutor(max_workers=12) as pool:
    futures = {pool.submit(page_cover, book): index for index, book in page_candidates}
    for future in as_completed(futures):
        index = futures[future]
        result = future.result()
        book = books[index]
        if result.get("cover"):
            cover = result["cover"]
            existing_primary = str(book.get("coverUrl", "")).strip()
            book["coverCandidates"] = unique_urls([existing_primary, cover], book.get("coverCandidates", []))
            if not existing_primary:
                book["coverUrl"] = cover
            report["pageSpecific"] += 1
        else:
            report["unresolved"] += 1
        report["results"].append({"index": index, "title": book.get("title", ""), **result})

# Keep a stable, small provenance note on the JSON file itself.
data["lastUpdated"] = TODAY
data["notes"] = (str(data.get("notes", "")).strip() + " " + f"{TODAY}: Added exact Project Gutenberg edition cover candidates and accepted only title-matched page-specific cover images from trusted free-book hosts; unresolved books intentionally fall back to the branded placeholder rather than a guessed cover.").strip()
data["actionRequired"] = data.get("actionRequired", []) if isinstance(data.get("actionRequired"), list) else []
data["actionRequired"].append(f"{TODAY}: Cover candidates use ordered exact-edition sources; keep the placeholder when no verified edition cover exists.")
GENERAL.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "results"}, ensure_ascii=False, indent=2))
