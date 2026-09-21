#!/usr/bin/env python3
"""Verify public DMG bytes and guard against stale release reruns."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ARCHES = ("arm64", "x86_64")


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def source_url(root: str, name: str) -> str:
    parsed = urllib.parse.urlparse(root)
    if parsed.scheme in {"http", "https", "file"}:
        return urllib.parse.urljoin(root.rstrip("/") + "/", urllib.parse.quote(name))
    return (Path(root) / name).resolve().as_uri()


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Lumi-release-verifier/1"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        fail(f"cannot download {url}: {exc}")


def max_build(xml: bytes) -> int:
    values = re.findall(rb"<sparkle:version>\s*(\d+)\s*</sparkle:version>", xml)
    return max((int(value) for value in values), default=0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("public_root")
    parser.add_argument("--online-feed", action="append", default=[])
    args = parser.parse_args()

    metadata = json.loads(args.metadata.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("release") != metadata:
        fail("final manifest metadata does not match release metadata")
    if manifest.get("publication_state") != "ready-for-publication":
        fail("final manifest is not ready for publication")

    expected_build = int(metadata["build_number"])
    for feed in args.online_feed:
        online = max_build(fetch(source_url("", feed) if not urllib.parse.urlparse(feed).scheme else feed))
        if online > expected_build:
            fail(f"online build {online} is newer than this run {expected_build}")

    for arch in ARCHES:
        name = metadata["dmg_filenames"][arch]
        record = manifest.get("files", {}).get(name)
        if not record or not re.fullmatch(r"[0-9a-f]{64}", str(record.get("sha256", ""))):
            fail(f"manifest lacks a valid digest for {name}")
        payload = fetch(source_url(args.public_root, name))
        actual = hashlib.sha256(payload).hexdigest()
        if actual != record["sha256"] or len(payload) != record.get("size"):
            fail(f"public bytes do not match final manifest for {name}")
        print(f"Verified public bytes: {name} ({len(payload)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
