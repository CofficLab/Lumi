#!/usr/bin/env python3
"""Idempotently upload one immutable release asset through the Lumi R2 API."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def remote_digest(url: str) -> str | None:
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Lumi-publisher/1"}), timeout=60) as response:
            value = hashlib.sha256()
            for chunk in iter(lambda: response.read(1024 * 1024), b""):
                value.update(chunk)
            return value.hexdigest()
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return None
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("file", type=Path)
    parser.add_argument("key")
    parser.add_argument("public_url")
    parser.add_argument("--api-url", default="https://data.kuaiyizhi.cn")
    parser.add_argument("--secret-env", default="WEBHOOK_SECRET")
    parser.add_argument("--mutable", action="store_true", help="allow an existing feed to be replaced")
    args = parser.parse_args()
    secret = os.environ.get(args.secret_env, "")
    if not args.file.is_file() or not secret:
        raise SystemExit("error: local file or upload credential missing")

    local = sha(args.file)
    existing = remote_digest(args.public_url)
    if existing is not None and not args.mutable:
        if existing != local:
            raise SystemExit(f"error: refusing to overwrite {args.key} with different bytes")
        print(f"Reusing identical public asset: {args.key}")
        return 0
    if existing == local:
        print(f"Public asset already matches: {args.key}")
        return 0

    with tempfile.NamedTemporaryFile() as response:
        completed = subprocess.run([
            "curl", "--fail-with-body", "--silent", "--show-error", "-X", "POST",
            f"{args.api_url.rstrip('/')}/lumi/upload", "-H", f"X-Webhook-Secret: {secret}",
            "-F", f"file=@{args.file}", "-F", f"key={args.key}", "-o", response.name,
        ])
        if completed.returncode:
            return completed.returncode
        result = json.loads(Path(response.name).read_text(encoding="utf-8"))
    if result.get("success") is not True:
        raise SystemExit(f"error: upload API rejected {args.key}: {result}")
    print(f"Uploaded asset: {args.key}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
