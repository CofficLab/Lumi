#!/usr/bin/env python3
"""Stop a stale publish job before it can overwrite a newer online build."""

import argparse
import json
import re
import urllib.error
import urllib.request
from pathlib import Path


def read(source: str, optional: bool) -> bytes:
    try:
        if source.startswith(("http://", "https://", "file://")):
            with urllib.request.urlopen(source, timeout=30) as response:
                return response.read()
        return Path(source).read_bytes()
    except (OSError, urllib.error.URLError) as exc:
        if optional:
            print(f"Optional feed unavailable: {source}")
            return b""
        raise SystemExit(f"error: required feed unavailable: {source}: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("--required-feed", action="append", default=[])
    parser.add_argument("--optional-feed", action="append", default=[])
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--state-url")
    args = parser.parse_args()
    metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
    expected = int(metadata["build_number"])
    online = 0
    for source, optional in [(v, False) for v in args.required_feed] + [(v, True) for v in args.optional_feed]:
        values = re.findall(rb"<sparkle:version>\s*(\d+)\s*</sparkle:version>", read(source, optional))
        online = max([online] + [int(value) for value in values])
    if online > expected:
        raise SystemExit(f"error: stale release run {expected}; online build is already {online}")
    if online == expected:
        if not args.manifest or not args.state_url:
            raise SystemExit("error: online build equals this run but no recovery state was provided")
        local_state = json.loads(args.manifest.read_text(encoding="utf-8"))
        try:
            remote_state = json.loads(read(args.state_url, False))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"error: invalid online recovery state: {exc}")
        if remote_state != local_state or remote_state.get("release") != metadata:
            raise SystemExit("error: online build number is reused by different release state")
        print("Online build is an exact recovery-state match; idempotent continuation allowed")
    print(f"Online build guard passed: online={online}, release={expected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
