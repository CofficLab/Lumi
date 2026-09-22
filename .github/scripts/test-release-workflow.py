#!/usr/bin/env python3
"""Static invariants for production and non-publishing validation workflows."""

from pathlib import Path

ROOT = Path(__file__).parents[1] / "workflows"


def main() -> int:
    release = (ROOT / "release.yml").read_text(encoding="utf-8")
    validation = (ROOT / "release-build-validation.yml").read_text(encoding="utf-8")
    for text in (release, validation):
        assert "arch: [arm64, x86_64]" in text
        assert "fail-fast: false" in text
        assert "ref: ${{ needs.prepare.outputs.source_sha }}" in text
        assert ".github/scripts/archive-lumi.sh" in text
        assert ".github/scripts/package-release-archive.sh" in text
        assert "restore-keys:" not in text
        assert "@v4" not in text and "@v6" not in text and "@v1\n" not in text
    assert "jobs:\n  prepare:" in release and "\n  build:" in release and "\n  publish:" in release
    assert "permissions:\n      contents: read" in release
    build_section = release.split("\n  build:", 1)[1].split("\n  publish:", 1)[0]
    publish_section = release.split("\n  publish:", 1)[1].split("\n  rebase:", 1)[0]
    assert "secrets." not in build_section
    assert "RESTORED_ARCHIVES: restored-archives" in publish_section
    assert 'verify-release-inputs.py "${RELEASE_METADATA}" incoming "${RESTORED_ARCHIVES}"' in publish_section
    assert 'source_app="${RESTORED_ARCHIVES}/Lumi-${arch}.xcarchive/Products/Applications/Lumi.app"' in publish_section
    assert '"${RESTORED_ARCHIVES}/Lumi-${arch}.xcarchive/dSYMs"' in publish_section
    assert 'verify-release-inputs.py "${RELEASE_METADATA}" incoming temp' not in publish_section
    assert "release-archive-${{ github.run_id }}-${{ needs.prepare.outputs.build_number }}-${{ matrix.arch }}" in release
    assert "retention-days: 7" in release and "retention-days: 14" in release
    assert "secrets." not in validation
    assert "publish:" not in validation and "COFFIC_APP_UPLOAD_KEY" not in validation
    assert "release-validation/**" in validation and "workflow_dispatch:" in validation
    print("✅ test-release-workflow.py: matrix, SHA pinning, permissions, caches, artifacts, and validation isolation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
