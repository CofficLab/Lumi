#!/usr/bin/env python3
"""Validate and restore the two architecture xcarchive artifacts for publish."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tarfile
from pathlib import Path, PurePosixPath

ARCHES = ("arm64", "x86_64")


def fail(message: str) -> "NoReturn":
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read JSON {path}: {exc}")


def validate_metadata(data: dict) -> None:
    required = {
        "schema_version",
        "source_sha",
        "run_id",
        "marketing_version",
        "build_number",
        "build_floor",
        "tag",
        "channel",
        "download_root",
        "xcode_version",
        "lock_hashes",
        "dmg_filenames",
        "dsym_filenames",
        "state_filename",
    }
    missing = sorted(required - data.keys())
    if missing:
        fail(f"metadata missing fields: {', '.join(missing)}")
    if data["schema_version"] != 1:
        fail("unsupported metadata schema")
    if not re.fullmatch(r"[0-9a-f]{40}", str(data["source_sha"])):
        fail("invalid metadata source_sha")
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(data["marketing_version"])):
        fail("invalid metadata marketing_version")
    if not re.fullmatch(r"\d+", str(data["build_number"])):
        fail("invalid metadata build_number")
    if data["channel"] not in {"stable", "preview"}:
        fail("invalid metadata channel")
    for key in ("main", "acp"):
        if not re.fullmatch(r"[0-9a-f]{64}", str(data["lock_hashes"].get(key, ""))):
            fail(f"invalid metadata lock hash: {key}")
    expected_names = {
        arch: f"Lumi_{data['marketing_version']}_{data['build_number']}_{arch}.dmg"
        for arch in ARCHES
    }
    if data["dmg_filenames"] != expected_names:
        fail("metadata DMG names are not derived from version/build/architecture")
    expected_dsyms = {
        arch: f"Lumi_{data['marketing_version']}_{data['build_number']}_{arch}_dSYMs.zip"
        for arch in ARCHES
    }
    if data["dsym_filenames"] != expected_dsyms:
        fail("metadata dSYM names are not derived from version/build/architecture")
    if data["state_filename"] != f"release-state-{data['build_number']}.json":
        fail("metadata recovery-state filename is invalid")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_members(tf: tarfile.TarFile, expected_root: str) -> list[tarfile.TarInfo]:
    members = tf.getmembers()
    if not members:
        fail("archive tar is empty")
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not path.parts or path.parts[0] != expected_root:
            fail(f"unsafe archive member: {member.name}")
        if member.issym() or member.islnk():
            target = PurePosixPath(member.linkname)
            if target.is_absolute():
                fail(f"unsafe absolute link target: {member.name} -> {member.linkname}")
            combined = path.parent.joinpath(target)
            depth = 0
            for part in combined.parts:
                if part == "..":
                    depth -= 1
                elif part not in ("", "."):
                    depth += 1
                if depth < 1:
                    fail(f"link escapes archive root: {member.name} -> {member.linkname}")
    return members


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("artifact_root", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument(
        "--verify-script",
        type=Path,
        default=Path(__file__).with_name("verify-release-archive.sh"),
    )
    args = parser.parse_args()

    metadata = load_json(args.metadata)
    validate_metadata(metadata)
    if args.output_dir.exists() and any(args.output_dir.iterdir()):
        fail(f"output directory must be empty: {args.output_dir}")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    manifests: dict[str, dict] = {}
    toolchains: set[tuple[str, str]] = set()
    for arch in ARCHES:
        artifact_dir = args.artifact_root / arch
        manifest_path = artifact_dir / "manifest.json"
        copied_metadata_path = artifact_dir / "release-metadata.json"
        if not artifact_dir.is_dir():
            fail(f"missing artifact directory for {arch}: {artifact_dir}")
        manifest = load_json(manifest_path)
        copied_metadata = load_json(copied_metadata_path)
        if copied_metadata != metadata or manifest.get("release") != metadata:
            fail(f"metadata/provenance mismatch for {arch}")
        if manifest.get("schema_version") != 1 or manifest.get("target_arch") != arch:
            fail(f"wrong manifest architecture for {arch}")
        if manifest.get("archive_root") != f"Lumi-{arch}.xcarchive":
            fail(f"wrong archive root for {arch}")
        if manifest.get("helper_archs") != [arch]:
            fail(f"helper architecture mismatch for {arch}: {manifest.get('helper_archs')}")
        if not manifest.get("main_uuid"):
            fail(f"missing main UUID for {arch}")
        if str(manifest.get("actual_xcode_build", "")) not in str(metadata.get("xcode_version", "")):
            fail(f"Xcode provenance mismatch for {arch}")

        archive_file = artifact_dir / str(manifest.get("archive_file", ""))
        if not archive_file.is_file():
            fail(f"archive payload missing for {arch}: {archive_file}")
        actual_hash = sha256(archive_file)
        if actual_hash != manifest.get("archive_sha256"):
            fail(f"archive SHA256 mismatch for {arch}")

        expected_root = f"Lumi-{arch}.xcarchive"
        with tarfile.open(archive_file, "r:gz") as tf:
            members = safe_members(tf, expected_root)
            tf.extractall(args.output_dir, members=members)

        restored = args.output_dir / expected_root
        main_binary = restored / "Products/Applications/Lumi.app/Contents/MacOS/Lumi"
        helper = restored / "Products/Applications/Lumi.app/Contents/MacOS/lumi-acp"
        if not os.access(main_binary, os.X_OK) or not os.access(helper, os.X_OK):
            fail(f"executable permissions were not preserved for {arch}")

        subprocess.run(
            [
                str(args.verify_script),
                str(restored),
                arch,
                "--expected-version",
                str(metadata["marketing_version"]),
                "--expected-build",
                str(metadata["build_number"]),
            ],
            check=True,
        )
        manifests[arch] = manifest
        toolchains.add((str(manifest.get("actual_xcode_build")), str(manifest.get("sdk_version"))))

    if len(toolchains) != 1:
        fail(f"architecture artifacts used different toolchains: {sorted(toolchains)}")
    if manifests["arm64"]["main_uuid"] == manifests["x86_64"]["main_uuid"]:
        fail("architecture archives unexpectedly share the same main UUID")

    print(
        f"Verified release inputs for {metadata['marketing_version']} ({metadata['build_number']}) "
        f"from {metadata['source_sha']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
