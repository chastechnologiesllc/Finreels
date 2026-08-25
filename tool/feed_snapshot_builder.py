#!/usr/bin/env python3
"""Generate a small, source-verified feed snapshot for Flutter Web fallback.

The app still prefers live feeds. This snapshot only protects the static Web
build when browser CORS infrastructure is unavailable; it is refreshed by CI.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import html
import json
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERAL = ROOT / "assets/data/resources/_general.json"
CHANNEL_DART = ROOT / "lib/data/channel_data.dart"
USER_AGENT = "FinReelsFeedSnapshot/1.0 (+https://github.com/chastechnologiesllc/Finreels)"


def get(url: str, timeout: int = 15) -> str | None:
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/rss+xml, application/atom+xml, application/xml, text/html;q=0.9"})
        with urllib.request.urlopen(request, timeout=timeout) as response:
            if response.status != 200:
                return None
            return response.read().decode("utf-8", "replace")
    except Exception:
        return None


def is_xml(body: str) -> bool:
    start = body.lstrip().lower()
    return start.startswith("<?xml") or start.startswith("<rss") or start.startswith("<feed") or start.startswith("<rdf:rdf")


def discover_urls(body: str, source: str) -> list[str]:
    found: list[str] = []
    for tag in re.findall(r"<link\b[^>]*>", body, re.I):
        rel = re.search(r"\brel\s*=\s*[\"']([^\"']+)", tag, re.I)
        typ = re.search(r"\btype\s*=\s*[\"']([^\"']+)", tag, re.I)
        href = re.search(r"\bhref\s*=\s*[\"']([^\"']+)", tag, re.I)
        if rel and href and "alternate" in rel.group(1).lower() and typ and ("rss" in typ.group(1).lower() or "atom" in typ.group(1).lower() or "xml" in typ.group(1).lower()):
            found.append(urllib.parse.urljoin(source, html.unescape(href.group(1))))
    parsed = urllib.parse.urlparse(source)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    found.extend(f"{origin}{path}" for path in ("/feed/", "/feed", "/rss.xml", "/feed.xml", "/atom.xml"))
    return list(dict.fromkeys(found))


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].split(":")[-1].lower()


def text(node: ET.Element | None) -> str:
    if node is None:
        return ""
    return " ".join("".join(node.itertext()).split())


def first_child(node: ET.Element, names: set[str]) -> ET.Element | None:
    for child in node.iter():
        if child is node:
            continue
        if local_name(child.tag) in names:
            return child
    return None


def child_text(node: ET.Element, names: set[str]) -> str:
    return text(first_child(node, names))


def link_for(node: ET.Element, base: str) -> str:
    for child in node.iter():
        if local_name(child.tag) != "link":
            continue
        href = child.attrib.get("href", "").strip()
        if href and child.attrib.get("rel", "alternate") in ("alternate", ""):
            return urllib.parse.urljoin(base, html.unescape(href))
        value = text(child)
        if value:
            return urllib.parse.urljoin(base, html.unescape(value))
    return ""


def image_urls(node: ET.Element, base: str) -> list[str]:
    values: list[str] = []
    for child in node.iter():
        name = local_name(child.tag)
        value = child.attrib.get("url", "") or child.attrib.get("href", "")
        typ = child.attrib.get("type", "").lower()
        medium = child.attrib.get("medium", "").lower()
        if name in {"thumbnail", "content", "enclosure"} and value and (name != "content" or medium == "image" or typ.startswith("image") or re.search(r"\.(?:jpg|jpeg|png|webp|gif)(?:$|\?)", value, re.I)):
            values.append(urllib.parse.urljoin(base, html.unescape(value)))
    raw = child_text(node, {"encoded", "description", "content", "summary"})
    match = re.search(r"<img[^>]+(?:src|data-src)=[\"']([^\"']+)", raw, re.I)
    if match:
        values.append(urllib.parse.urljoin(base, html.unescape(match.group(1))))
    return list(dict.fromkeys(v for v in values if v.startswith(("http://", "https://"))))


def parse_feed(body: str, source_name: str, source_url: str) -> list[dict]:
    try:
        root = ET.fromstring(body)
    except ET.ParseError:
        return []
    nodes = [n for n in root.iter() if local_name(n.tag) in {"item", "entry"}]
    result: list[dict] = []
    for node in nodes[:20]:
        url = link_for(node, source_url)
        title = child_text(node, {"title"})
        if not url or not title:
            continue
        identifier = child_text(node, {"videoid"})
        if not identifier:
            urn = child_text(node, {"id"})
            identifier = urn.rsplit(":", 1)[-1] if "yt:video:" in urn else ""
        published = child_text(node, {"published", "updated", "pubdate", "date"})
        try:
            published_at = dt.datetime.fromisoformat(published.replace("Z", "+00:00")).isoformat()
        except ValueError:
            published_at = dt.datetime.now(dt.timezone.utc).isoformat()
        result.append({
            "id": identifier,
            "title": html.unescape(title),
            "url": url,
            "sourceName": source_name,
            "publishedAt": published_at,
            "description": html.unescape(child_text(node, {"description", "summary", "media:description"})),
            "thumbnailUrl": (image_urls(node, source_url) or [""])[0],
            "thumbnailFallbackUrls": image_urls(node, source_url)[1:8],
            "channelName": source_name,
            "channelId": "",
            "originalLink": url,
        })
    return result


def blog_feed(source: tuple[str, str]) -> list[dict]:
    name, url = source
    body = get(url)
    if not body:
        return []
    candidates = [url] if is_xml(body) else discover_urls(body, url)
    for candidate in candidates:
        feed = body if candidate == url else get(candidate)
        if feed and is_xml(feed):
            parsed = parse_feed(feed, name, candidate)
            if parsed:
                return parsed
    return []


def channel_feed(channel_id: str) -> list[dict]:
    url = f"https://www.youtube.com/feeds/videos.xml?channel_id={urllib.parse.quote(channel_id)}"
    body = get(url)
    if not body or not is_xml(body):
        return []
    videos = parse_feed(body, channel_id, url)
    for video in videos:
        video["id"] = video["id"] or re.search(r"[\w-]{11}", video["url"]).group(0) if re.search(r"[\w-]{11}", video["url"]) else ""
        video["channelId"] = channel_id
        video["channelName"] = channel_id
        video["description"] = video.get("description", "")
        video["thumbnailUrl"] = video.get("thumbnailUrl") or f"https://i.ytimg.com/vi/{video['id']}/hqdefault.jpg"
        video["originalLink"] = video["url"]
        video.pop("url", None)
        video.pop("sourceName", None)
    return [video for video in videos if video.get("id")]


def sources() -> tuple[list[str], list[tuple[str, str]]]:
    general = json.loads(GENERAL.read_text())
    channel_ids = re.findall(r"\bid:\s*'([A-Za-z0-9_-]{20,})'", CHANNEL_DART.read_text())
    for resource_path in (ROOT / "assets/data/resources").glob("*.json"):
        try:
            resource = json.loads(resource_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        channel_ids.extend(str(item.get("id", "")) for item in resource.get("channels", []))
    channel_ids = list(dict.fromkeys(i for i in channel_ids if i))
    # Keep the blog snapshot bounded: the General sources are the always-on
    # fallback set; selected-category blogs continue to prefer live requests.
    blog_sources = [(str(item.get("name", "")), str(item.get("url", ""))) for item in general.get("blogs", []) if item.get("name") and item.get("url")]
    # Stable, first-party general feeds used by the app at runtime.
    blog_sources.extend([
        ("Entrepreneur", "https://www.entrepreneur.com/latest.rss"),
        ("Inc. Magazine", "https://www.inc.com/rss/"),
        ("Forbes Business", "https://www.forbes.com/business/feed/"),
        ("Fast Company", "https://www.fastcompany.com/rss"),
        ("Seth Godin", "https://seths.blog/feed/"),
    ])
    unique_blogs: list[tuple[str, str]] = []
    seen = set()
    for item in blog_sources:
        if item[1] not in seen:
            seen.add(item[1])
            unique_blogs.append(item)
    return channel_ids, unique_blogs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default=str(ROOT / "assets/data/feed_snapshot.json"))
    args = parser.parse_args()
    channel_ids, blog_sources = sources()
    snapshot = {"generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(), "channels": {}, "blogs": []}
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        channel_results = list(pool.map(channel_feed, channel_ids))
        blog_results = list(pool.map(blog_feed, blog_sources))
    for channel_id, videos in zip(channel_ids, channel_results):
        if videos:
            snapshot["channels"][channel_id] = videos
    seen_urls: set[str] = set()
    for articles in blog_results:
        for article in articles:
            if article["url"] not in seen_urls:
                seen_urls.add(article["url"])
                snapshot["blogs"].append(article)
    snapshot["blogs"].sort(key=lambda a: a.get("publishedAt", ""), reverse=True)
    output_path = Path(args.output)
    if output_path.exists():
        try:
            previous = json.loads(output_path.read_text())
            if (previous.get("channels") == snapshot["channels"] and
                    previous.get("blogs") == snapshot["blogs"]):
                snapshot["generatedAt"] = previous.get("generatedAt", snapshot["generatedAt"])
        except (OSError, json.JSONDecodeError):
            pass
    output_path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {len(snapshot['channels'])} channels and {len(snapshot['blogs'])} blogs to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
