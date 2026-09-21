#!/usr/bin/env python3
"""Tests final recovery manifest, public-byte verification, and stale-run guard."""

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).parent


def main() -> int:
    with tempfile.TemporaryDirectory() as value:
        root = Path(value); assets = root / "assets"; public = root / "public"; notary = root / "notary"
        assets.mkdir(); public.mkdir(); notary.mkdir()
        data = {
            "schema_version": 1, "source_sha": "a" * 40, "run_id": "1",
            "marketing_version": "6.1.0", "build_number": "20260921190000",
            "build_floor": "0", "tag": "v6.1.0", "channel": "stable",
            "download_root": public.as_uri(), "r2_prefix": "lumi", "previous_tag": "6.0.0",
            "is_prerelease": False, "xcode_version": "Xcode 26.3 Build version TEST",
            "lock_hashes": {"main": "1" * 64, "acp": "2" * 64},
            "dmg_filenames": {a: f"Lumi_6.1.0_20260921190000_{a}.dmg" for a in ("arm64", "x86_64")},
            "dsym_filenames": {a: f"Lumi_6.1.0_20260921190000_{a}_dSYMs.zip" for a in ("arm64", "x86_64")},
            "state_filename": "release-state-20260921190000.json",
        }
        metadata = root / "metadata.json"; metadata.write_text(json.dumps(data))
        (assets / "release-metadata.json").write_text(json.dumps(data))
        for name in list(data["dmg_filenames"].values()) + list(data["dsym_filenames"].values()):
            (assets / name).write_bytes(name.encode())
        for name in ("appcast.xml", "appcast-arm64.xml", "appcast-x86_64.xml", "changelog.md"):
            (assets / name).write_text(name)
        for arch in ("arm64", "x86_64"):
            (notary / f"{arch}.json").write_text(json.dumps({"status": "Accepted", "submission_id": f"id-{arch}"}))
        manifest = assets / "final-assets-manifest.json"
        subprocess.run([str(HERE / "create-final-assets-manifest.py"), str(metadata), str(assets), str(manifest),
                        "--notary-dir", str(notary)], check=True)
        subprocess.run([str(HERE / "verify-final-assets.py"), str(metadata), str(assets), str(manifest)], check=True)
        for name in data["dmg_filenames"].values():
            (public / name).write_bytes((assets / name).read_bytes())
        subprocess.run([str(HERE / "verify-published-assets.py"), str(metadata), str(manifest), str(public)], check=True)

        arm = public / data["dmg_filenames"]["arm64"]
        arm.write_bytes(b"different")
        failed = subprocess.run([str(HERE / "verify-published-assets.py"), str(metadata), str(manifest), str(public)], capture_output=True)
        assert failed.returncode != 0 and b"do not match" in failed.stderr

        feed = root / "feed.xml"; feed.write_text("<sparkle:version>20260921190001</sparkle:version>")
        stale = subprocess.run([str(HERE / "guard-release-build.py"), str(metadata), "--required-feed", str(feed)], capture_output=True)
        assert stale.returncode != 0 and b"stale release" in stale.stderr

        feed.write_text("<sparkle:version>20260921190000</sparkle:version>")
        state = root / "state.json"; state.write_bytes(manifest.read_bytes())
        equal = subprocess.run([str(HERE / "guard-release-build.py"), str(metadata), "--required-feed", str(feed),
                                "--manifest", str(manifest), "--state-url", str(state)], capture_output=True)
        assert equal.returncode == 0, equal.stdout + equal.stderr
        state.write_text("{}")
        collision = subprocess.run([str(HERE / "guard-release-build.py"), str(metadata), "--required-feed", str(feed),
                                    "--manifest", str(manifest), "--state-url", str(state)], capture_output=True)
        assert collision.returncode != 0 and b"different release state" in collision.stderr

    print("✅ test-published-assets.py: recovery integrity, public bytes, and stale-run guard passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
