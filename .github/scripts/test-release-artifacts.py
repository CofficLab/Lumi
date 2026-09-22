#!/usr/bin/env python3
"""Tests the cross-job xcarchive provenance and extraction gate."""

from __future__ import annotations

import copy
import hashlib
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("verify-release-inputs.py")
PACKAGE_SCRIPT = Path(__file__).with_name("package-release-archive.sh")
ARCHES = ("arm64", "x86_64")


def metadata() -> dict:
    return {
        "schema_version": 1,
        "source_sha": "a" * 40,
        "run_id": "123",
        "marketing_version": "6.1.0",
        "build_number": "20260921190000",
        "build_floor": "20260921185959",
        "tag": "v6.1.0",
        "channel": "stable",
        "download_root": "https://example.invalid/lumi",
        "r2_prefix": "lumi",
        "previous_tag": "6.0.0",
        "is_prerelease": False,
        "xcode_version": "Xcode 26.3 Build version 17C999",
        "lock_hashes": {"main": "1" * 64, "acp": "2" * 64},
        "dmg_filenames": {a: f"Lumi_6.1.0_20260921190000_{a}.dmg" for a in ARCHES},
        "dsym_filenames": {a: f"Lumi_6.1.0_20260921190000_{a}_dSYMs.zip" for a in ARCHES},
        "state_filename": "release-state-20260921190000.json",
    }


def write_bundle(root: Path, arch: str, executable: bool = True) -> Path:
    archive = root / f"Lumi-{arch}.xcarchive"
    app = archive / "Products/Applications/Lumi.app/Contents"
    (app / "MacOS").mkdir(parents=True)
    (app / "Resources/PluginProjectRAG_ProjectRAGEngine.bundle").mkdir(parents=True)
    (app / "MacOS/Lumi").write_text("main")
    (app / "MacOS/lumi-acp").write_text("helper")
    mode = 0o755 if executable else 0o644
    os.chmod(app / "MacOS/Lumi", mode)
    os.chmod(app / "MacOS/lumi-acp", mode)
    os.symlink("Lumi", app / "MacOS/current-main")
    return archive


def make_artifacts(root: Path, data: dict, executable: bool = True) -> None:
    source = root / "source"
    artifacts = root / "artifacts"
    source.mkdir(); artifacts.mkdir()
    for index, arch in enumerate(ARCHES):
        archive = write_bundle(source, arch, executable)
        artifact = artifacts / arch
        artifact.mkdir()
        tar_path = artifact / f"Lumi-{arch}.xcarchive.tar.gz"
        with tarfile.open(tar_path, "w:gz") as tf:
            tf.add(archive, arcname=archive.name, recursive=True)
        digest = hashlib.sha256(tar_path.read_bytes()).hexdigest()
        manifest = {
            "schema_version": 1,
            "release": data,
            "target_arch": arch,
            "archive_root": archive.name,
            "archive_file": tar_path.name,
            "archive_sha256": digest,
            "actual_xcode_build": "17C999",
            "sdk_version": "26.3",
            "runner_image": "macos-26",
            "main_uuid": f"00000000-0000-0000-0000-00000000000{index}",
            "helper_archs": [arch],
        }
        (artifact / "release-metadata.json").write_text(json.dumps(data))
        (artifact / "manifest.json").write_text(json.dumps(manifest))
    (root / "metadata.json").write_text(json.dumps(data))


def verifier(root: Path) -> Path:
    path = root / "fake-archive-verifier.sh"
    path.write_text("""#!/usr/bin/env bash
set -e
test -x "$1/Products/Applications/Lumi.app/Contents/MacOS/Lumi"
test -x "$1/Products/Applications/Lumi.app/Contents/MacOS/lumi-acp"
test -d "$1/Products/Applications/Lumi.app/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle"
""")
    os.chmod(path, 0o755)
    return path


def run(root: Path) -> subprocess.CompletedProcess[str]:
    output = root / "restored"
    if output.exists(): shutil.rmtree(output)
    return subprocess.run(
        [str(SCRIPT), str(root / "metadata.json"), str(root / "artifacts"), str(output),
         "--verify-script", str(verifier(root))],
        text=True, capture_output=True,
    )


def scenario(mutator=None, *, executable=True) -> subprocess.CompletedProcess[str]:
    temp = tempfile.TemporaryDirectory()
    root = Path(temp.name)
    make_artifacts(root, metadata(), executable)
    if mutator: mutator(root)
    result = run(root)
    result._temp = temp  # type: ignore[attr-defined]
    return result


def expect_failure(mutator, phrase: str, *, executable=True) -> None:
    result = scenario(mutator, executable=executable)
    assert result.returncode != 0, result.stdout + result.stderr
    assert phrase.lower() in (result.stdout + result.stderr).lower(), result.stdout + result.stderr


def test_packager() -> None:
    with tempfile.TemporaryDirectory() as value:
        root = Path(value); archive = root / "Lumi-arm64.xcarchive"; output = root / "output"
        app = archive / "Products/Applications/Lumi.app/Contents"
        for directory in (
            app / "MacOS", app / "PlugIns/LumiFinder.appex/Contents/MacOS",
            app / "Frameworks/Sparkle.framework", app / "Resources/PluginProjectRAG_ProjectRAGEngine.bundle",
            app / "Resources/PluginACP_PluginACP.bundle", archive / "dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF",
        ): directory.mkdir(parents=True)
        for binary in (app / "MacOS/Lumi", app / "MacOS/lumi-acp",
                       app / "PlugIns/LumiFinder.appex/Contents/MacOS/LumiFinder", app / "Frameworks/vec0.dylib"):
            binary.write_text("fake"); os.chmod(binary, 0o755)
        (archive / "dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi").write_text("fake")
        (app / "Info.plist").write_text("fake")
        (app / "PlugIns/LumiFinder.appex/Contents/Info.plist").write_text("fake")
        data = metadata(); (root / "metadata.json").write_text(json.dumps(data))
        tools = root / "tools"; tools.mkdir()
        commands = {
            "lipo": '#!/bin/sh\n[ "$1" = -archs ] && echo arm64\nexit 0\n',
            "dwarfdump": '#!/bin/sh\necho "UUID: ABCDEF00-0000-0000-0000-000000000001 (arm64) $2"\n',
            "xcodebuild": '#!/bin/sh\necho "Xcode 26.3"\necho "Build version 17C999"\n',
            "xcrun": '#!/bin/sh\necho 26.3\n',
            "PlistBuddy": '#!/bin/sh\ncase "$2" in *CFBundleExecutable*) echo LumiFinder;; *CFBundleShortVersionString*) echo 6.1.0;; *CFBundleVersion*) echo 20260921190000;; esac\n',
        }
        for name, body in commands.items():
            path = tools / name; path.write_text(body); os.chmod(path, 0o755)
        env = os.environ.copy(); env["PATH"] = f"{tools}:{env['PATH']}"; env["PLIST_BUDDY"] = str(tools / "PlistBuddy")
        result = subprocess.run([str(PACKAGE_SCRIPT), str(archive), "arm64", str(root / "metadata.json"), str(output)],
                                env=env, text=True, capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
        manifest = json.loads((output / "manifest.json").read_text())
        assert manifest["target_arch"] == "arm64" and manifest["helper_archs"] == ["arm64"]
        assert (output / manifest["archive_file"]).is_file()


def main() -> int:
    test_packager()
    result = scenario()
    assert result.returncode == 0, result.stdout + result.stderr

    expect_failure(lambda r: shutil.rmtree(r / "artifacts/x86_64"), "missing artifact directory")
    expect_failure(lambda r: (r / "artifacts/arm64/Lumi-arm64.xcarchive.tar.gz").write_bytes(b"bad"), "SHA256 mismatch")

    def wrong_sha(root: Path) -> None:
        path = root / "artifacts/arm64/release-metadata.json"
        data = json.loads(path.read_text()); data["source_sha"] = "b" * 40
        path.write_text(json.dumps(data))
    expect_failure(wrong_sha, "metadata/provenance mismatch")

    def wrong_arch(root: Path) -> None:
        path = root / "artifacts/arm64/manifest.json"
        data = json.loads(path.read_text()); data["helper_archs"] = ["x86_64"]
        path.write_text(json.dumps(data))
    expect_failure(wrong_arch, "helper architecture mismatch")

    expect_failure(lambda _: None, "executable permissions", executable=False)

    def traversal(root: Path) -> None:
        artifact = root / "artifacts/arm64"
        tar_path = artifact / "Lumi-arm64.xcarchive.tar.gz"
        with tarfile.open(tar_path, "w:gz") as tf:
            info = tarfile.TarInfo("../escape"); payload = b"nope"; info.size = len(payload)
            tf.addfile(info, io.BytesIO(payload))
        manifest = json.loads((artifact / "manifest.json").read_text())
        manifest["archive_sha256"] = hashlib.sha256(tar_path.read_bytes()).hexdigest()
        (artifact / "manifest.json").write_text(json.dumps(manifest))
    expect_failure(traversal, "unsafe archive member")

    def same_uuid(root: Path) -> None:
        a = json.loads((root / "artifacts/arm64/manifest.json").read_text())
        path = root / "artifacts/x86_64/manifest.json"
        x = json.loads(path.read_text()); x["main_uuid"] = a["main_uuid"]
        path.write_text(json.dumps(x))
    expect_failure(same_uuid, "share the same main UUID")

    print("✅ test-release-artifacts.py: transfer, provenance, permissions, paths, and architecture failures passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
