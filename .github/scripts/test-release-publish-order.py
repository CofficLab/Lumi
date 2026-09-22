#!/usr/bin/env python3
"""Static safety checks for release publication ordering and recovery."""

from pathlib import Path

WORKFLOW = Path(__file__).parents[1] / "workflows/release.yml"
SCRIPTS = Path(__file__).parent


def position(text: str, marker: str) -> int:
    value = text.find(marker)
    assert value >= 0, f"missing workflow marker: {marker}"
    return value


def main() -> int:
    text = WORKFLOW.read_text(encoding="utf-8")
    order = [
        "name: Sign restored applications",
        "name: Create uniquely named DMGs",
        "name: Sign disk images",
        "name: Notarize, staple, and validate DMGs",
        "name: Generate architecture appcasts",
        "name: Create immutable final-assets manifest",
        "name: Save final-assets recovery artifact before publication",
        "name: Upload immutable DMGs",
        "name: Verify public DMG bytes",
        "name: Upload immutable release recovery state",
        "name: Create or verify draft GitHub Release",
        "name: Upload architecture feeds",
        "name: Upload legacy feed last",
        "name: Publish GitHub Release",
    ]
    indexes = [position(text, marker) for marker in order]
    assert indexes == sorted(indexes), "release public-write order is unsafe"
    assert "overwrite: true" not in text
    assert "grep -q '\"success\":true'" not in text
    assert "--target" in text and "needs.prepare.outputs.source_sha" in text
    assert "needs: [prepare, build]" in text
    assert "contents: read" in text

    sign_dmg = (SCRIPTS / "sign-dmg.sh").read_text(encoding="utf-8")
    notarize_dmg = (SCRIPTS / "notarize-dmg.sh").read_text(encoding="utf-8")
    assert 'codesign --force --timestamp --sign "${identity}" "${dmg}"' in sign_dmg
    assert 'codesign --verify --strict --verbose=2 "${dmg}"' in sign_dmg
    assert 'spctl -a -vvv -t open --context context:primary-signature "${dmg}"' in notarize_dmg
    assert "-t install" not in notarize_dmg
    print("✅ test-release-publish-order.py: recovery and public-write order passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
