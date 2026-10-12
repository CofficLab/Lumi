#!/usr/bin/env python3
"""Validate a saved final-assets recovery bundle before reusing it."""

import argparse
import hashlib
import json
import re
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("asset_dir", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    release = json.loads(args.metadata.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or manifest.get("release") != release:
        raise SystemExit("error: recovery manifest provenance mismatch")
    if manifest.get("publication_state") != "ready-for-publication":
        raise SystemExit("error: recovery manifest is not publishable")
    for arch in ("arm64", "x86_64"):
        record = manifest.get("notarizations", {}).get(arch, {})
        if record.get("status") != "Accepted" or not record.get("submission_id"):
            raise SystemExit(f"error: invalid notarization record for {arch}")
    for name, record in manifest.get("files", {}).items():
        if Path(name).name != name or not re.fullmatch(r"[0-9a-f]{64}", str(record.get("sha256", ""))):
            raise SystemExit(f"error: unsafe recovery manifest entry: {name}")
        path = args.asset_dir / name
        if not path.is_file() or path.is_symlink():
            raise SystemExit(f"error: recovery file missing: {name}")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != record["sha256"] or path.stat().st_size != record.get("size"):
            raise SystemExit(f"error: recovery file mismatch: {name}")
    print(f"Verified reusable final-assets bundle for {release['tag']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
