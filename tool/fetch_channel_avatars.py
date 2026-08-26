#!/usr/bin/env python3
"""Fetch official YouTube channel avatar URLs for the FinReels channel corpus.

The source is the official YouTube channel page for each already-verified
channel ID. The script only reads public page metadata and stores the returned
og:image URL; it does not download or execute page assets.
"""
from __future__ import annotations

import json
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date
from pathlib import Path
from typing import Any

import requests

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
CHANNEL_DATA = ROOT / "lib" / "data" / "channel_data.dart"
MANIFEST = ROOT / "docs" / "research" / "channel_avatar_manifest_2026-08-26.json"
DART_OUT = ROOT / "lib" / "data" / "channel_avatar_data.dart"

CHANNEL_RE = re.compile(
    r"Channel\(\s*.*?id:\s*'([^']+)'\s*,\s*name:\s*'([^']+)'\s*,\s*handle:\s*'([^']+)'",
    re.S,
)
META_RE = re.compile(
    r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)',
    re.I,
)
LINK_RE = re.compile(
    r'<link[^>]+rel=["\']image_src["\'][^>]+href=["\']([^"\']+)',
    re.I,
)


def collect_channels() -> dict[str, dict[str, str]]:
    channels: dict[str, dict[str, str]] = {}
    for path in sorted(RESOURCE_DIR.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        category_id = str(payload.get("categoryId", ""))
        for channel in payload.get("channels", []):
            channel_id = str(channel.get("id", "")).strip()
            if not channel_id:
                continue
            channels.setdefault(channel_id, {
                "id": channel_id,
                "name": str(channel.get("name", "")).strip(),
                "handle": str(channel.get("handle", "")).strip(),
                "categoryId": category_id,
            })

    for channel_id, name, handle in CHANNEL_RE.findall(CHANNEL_DATA.read_text(encoding="utf-8")):
        channels.setdefault(channel_id, {
            "id": channel_id,
            "name": name,
            "handle": handle,
            "categoryId": "",
        })
    return channels


def fetch_avatar(channel: dict[str, str]) -> dict[str, Any]:
    channel_id = channel["id"]
    urls = [f"https://www.youtube.com/channel/{channel_id}"]
    handle = channel.get("handle", "").strip()
    if handle.startswith("@"):
        urls.append(f"https://www.youtube.com/{handle}")

    last_status: Any = "error"
    for url in urls:
        try:
            response = requests.get(
                url,
                headers={"User-Agent": "Mozilla/5.0 (compatible; FinReels research)"},
                timeout=25,
            )
            last_status = response.status_code
            if response.status_code != 200:
                continue
            avatar = None
            match = META_RE.search(response.text)
            if match:
                avatar = match.group(1)
            if not avatar:
                match = LINK_RE.search(response.text)
                if match:
                    avatar = match.group(1)
            if avatar:
                avatar = avatar.replace("&amp;", "&")
            valid = bool(
                avatar
                and re.match(
                    r"^https://yt3(?:\.googleusercontent\.com|\.ggpht\.com)/",
                    avatar,
                )
            )
            if valid:
                return {
                    **channel,
                    "status": response.status_code,
                    "avatarUrl": avatar,
                    "sourceUrl": url,
                }
        except requests.RequestException as exc:
            last_status = str(exc)
    return {**channel, "status": last_status, "avatarUrl": None, "sourceUrl": urls[-1]}


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def write_dart(results: list[dict[str, Any]]) -> None:
    entries = {
        item["id"]: item["avatarUrl"]
        for item in results
        if item.get("avatarUrl")
    }
    lines = [
        "// GENERATED FILE — official YouTube channel profile images.",
        "// Source: each channel's official YouTube page og:image metadata.",
        "// Regenerate with tool/fetch_channel_avatars.py when channel branding changes.",
        "",
        "class ChannelAvatarData {",
        "  ChannelAvatarData._();",
        "",
        "  static const Map<String, String> byChannelId = {",
    ]
    for channel_id in sorted(entries):
        lines.append(f"    {dart_string(channel_id)}: {dart_string(entries[channel_id])},")
    lines.extend(["  };", "}", ""])
    DART_OUT.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    channels = collect_channels()
    results: list[dict[str, Any]] = []
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(fetch_avatar, channel) for channel in channels.values()]
        for future in as_completed(futures):
            results.append(future.result())
    results.sort(key=lambda item: item["id"])
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps({
        "retrievedOn": str(date.today()),
        "source": "Official YouTube channel page og:image metadata",
        "channelCount": len(results),
        "avatarCount": sum(bool(item.get("avatarUrl")) for item in results),
        "missingCount": sum(not item.get("avatarUrl") for item in results),
        "channels": results,
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_dart(results)
    print(json.dumps({
        "channelCount": len(results),
        "avatarCount": sum(bool(item.get("avatarUrl")) for item in results),
        "missingCount": sum(not item.get("avatarUrl") for item in results),
        "manifest": str(MANIFEST),
        "dart": str(DART_OUT),
    }, indent=2))


if __name__ == "__main__":
    main()
