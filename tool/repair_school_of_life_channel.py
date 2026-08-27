#!/usr/bin/env python3
"""Correct the verified The School of Life channel identity in resources."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
OLD_ID = "UC8c9l98f2Zq4l9YnbmutPTw"
NEW_ID = "UC7IcJI8PUf5Z3zKxnZvTBog"
OLD_HANDLE = "@TheSchoolOfLife"
NEW_HANDLE = "@theschooloflifetv"


def main() -> None:
    changed_files = 0
    changed_records = 0
    for path in sorted(RESOURCE_DIR.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for channel in payload.get("channels", []):
            if channel.get("id") != OLD_ID:
                continue
            channel["id"] = NEW_ID
            channel["handle"] = NEW_HANDLE
            channel["name"] = "The School of Life"
            channel["description"] = (
                "Psychology, emotional intelligence, relationships, and self-awareness."
            )
            channel["verificationMethod"] = (
                "Direct official YouTube handle page @theschooloflifetv resolved to "
                "channel ID UC7IcJI8PUf5Z3zKxnZvTBog; verified against the official "
                "channel page on 2026-08-26."
            )
            changed = True
            changed_records += 1
        if changed:
            path.write_text(
                json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
                encoding="utf-8",
            )
            changed_files += 1
    print(json.dumps({
        "changedFiles": changed_files,
        "changedRecords": changed_records,
        "oldId": OLD_ID,
        "newId": NEW_ID,
        "oldHandle": OLD_HANDLE,
        "newHandle": NEW_HANDLE,
    }, indent=2))


if __name__ == "__main__":
    main()
