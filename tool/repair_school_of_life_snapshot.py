#!/usr/bin/env python3
"""Replace stale School of Life snapshot data with its official RSS feed."""
from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "assets/data/feed_snapshot.json"
OLD_ID = "UC8c9l98f2Zq4l9YnbmutPTw"
NEW_ID = "UC7IcJI8PUf5Z3zKxnZvTBog"

sys.path.insert(0, str(ROOT / "tool"))
from feed_snapshot_builder import channel_feed  # noqa: E402


def main() -> None:
    snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    channels = snapshot.setdefault("channels", {})
    channels.pop(OLD_ID, None)
    videos = channel_feed(NEW_ID)
    if not videos:
        raise SystemExit("official School of Life RSS feed returned no videos")
    channels[NEW_ID] = videos
    SNAPSHOT.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "removedOldBucket": OLD_ID not in channels,
        "canonicalId": NEW_ID,
        "videoCount": len(videos),
    }, indent=2))


if __name__ == "__main__":
    main()
