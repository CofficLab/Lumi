#!/usr/bin/env python3
"""Static safety checks for release publication ordering and recovery."""

from pathlib import Path

WORKFLOW = Path(__file__).parents[1] / "workflows/release.yml"
SCRIPTS = Path(__file__).parent


def position(text: str, marker: str) -> int:
    value = text.find(marker)
    assert value >= 0, f"missing workflow marker: {marker}"
    return value


def shell_commands(text: str, needle: str) -> list[str]:
    """Return whole logical shell commands containing needle, joined over backslash continuations.

    A flag on a continuation line belongs to the same command, so scanning line by
    line would let a blocking option hide past the end of the first line.
    """
    commands = []
    current = ""
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("#"):
            continue
        if not line:
            current = ""
            continue
        continued = line.endswith("\\")
        current += line.rstrip("\\").strip() + " "
        if not continued:
            commands.append(current.strip())
            current = ""
    assert not current, f"unterminated shell continuation near: {current}"
    return [command for command in commands if command.startswith(needle)]


def main() -> int:
    text = WORKFLOW.read_text(encoding="utf-8")
    order = [
        "name: Sign restored applications",
        "name: Create uniquely named DMGs",
        "name: Sign disk images",
        "name: Submit DMGs for notarization",
        "name: Wait for notarization, staple, and validate DMGs",
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
    assert 'prerelease=()' not in text
    assert '"${prerelease[@]}"' not in text
    assert 'gh release create "${tag}" --draft --prerelease' in text

    sign_dmg = (SCRIPTS / "sign-dmg.sh").read_text(encoding="utf-8")
    notarize_dmg = (SCRIPTS / "notarize-dmg.sh").read_text(encoding="utf-8")
    wait_notarization = (SCRIPTS / "wait-notarization.sh").read_text(encoding="utf-8")
    assert 'codesign --force --timestamp --sign "${identity}" "${dmg}"' in sign_dmg
    assert 'codesign --verify --strict --verbose=2 "${dmg}"' in sign_dmg
    assert 'spctl -a -vvv -t open --context context:primary-signature "${dmg}"' in wait_notarization
    assert "-t install" not in wait_notarization
    assert "-t install" not in notarize_dmg

    # Submission must never block on Apple's queue. A blocking submit loses the
    # submission id, which is the only handle that makes a wait resumable.
    submit_blocks = shell_commands(notarize_dmg, "xcrun notarytool submit")
    assert len(submit_blocks) == 1, "exactly one notarytool submit command is expected"
    submit_call = submit_blocks[0]
    assert "--wait" not in submit_call, "submit must not wait, or a slow queue discards the submission id"
    assert "--timeout" not in submit_call
    assert "submission_id" in notarize_dmg
    assert '"status": "Submitted"' in notarize_dmg
    assert "sha256" in notarize_dmg, "a record must bind the submission id to the DMG bytes it notarized"
    # The wait budget must exceed the longest observed notary queue by a wide margin.
    assert "POLL_ATTEMPTS:-80" in wait_notarization
    assert "xcrun stapler staple" in wait_notarization
    assert "notarytool info" in wait_notarization, "the wait must resume from a stored submission id"
    print("✅ test-release-publish-order.py: recovery and public-write order passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
