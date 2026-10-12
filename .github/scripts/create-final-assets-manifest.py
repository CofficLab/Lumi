#!/usr/bin/env python3
"""Create the immutable manifest saved before the first public release write."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ARCHES = ("arm64", "x86_64")


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("asset_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--notary-dir", type=Path, required=True)
    args = parser.parse_args()

    release = json.loads(args.metadata.read_text(encoding="utf-8"))
    if not re.fullmatch(r"[0-9a-f]{40}", str(release.get("source_sha", ""))):
        fail("invalid release metadata")
    if args.output.parent.resolve() != args.asset_dir.resolve():
        fail("manifest must be written inside the final asset directory")

    if release["channel"] == "preview":
        appcasts = ["appcast-pre.xml", "appcast-pre-arm64.xml", "appcast-pre-x86_64.xml"]
    else:
        appcasts = ["appcast.xml", "appcast-arm64.xml", "appcast-x86_64.xml"]
    required = [release["dmg_filenames"][a] for a in ARCHES]
    required += [release["dsym_filenames"][a] for a in ARCHES]
    required += appcasts + ["changelog.md", "release-metadata.json"]

    notarizations = {}
    for arch in ARCHES:
        record_path = args.notary_dir / f"{arch}.json"
        if not record_path.is_file():
            fail(f"missing notarization record for {arch}")
        record = json.loads(record_path.read_text(encoding="utf-8"))
        if record.get("status") != "Accepted" or not record.get("submission_id"):
            fail(f"notarization for {arch} is not Accepted")
        notarizations[arch] = record

    files = {}
    for name in required:
        path = args.asset_dir / name
        if not path.is_file() or path.is_symlink():
            fail(f"required final asset missing or unsafe: {name}")
        files[name] = {"sha256": digest(path), "size": path.stat().st_size}

    manifest = {
        "schema_version": 1,
        "release": release,
        "publication_state": "ready-for-publication",
        "files": files,
        "notarizations": notarizations,
    }
    args.output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Created final-assets manifest with {len(files)} immutable files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
