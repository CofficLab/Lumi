#!/usr/bin/env python3
"""
Tests for verify-package-locks.py.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path


def create_resolved(pins: dict) -> str:
    """Create a Package.resolved JSON string from a dict of identity -> (version, revision)."""
    pin_list = []
    for identity, (version, revision) in pins.items():
        pin_list.append({
            "identity": identity,
            "kind": "remoteSourceControl",
            "location": f"https://github.com/example/{identity}.git",
            "state": {
                "revision": revision,
                "version": version,
            }
        })
    return json.dumps({"pins": pin_list}, indent=2)


def run_verify(main_content: str, acp_content: str, *args) -> tuple[int, str]:
    """Run verify-package-locks.py with the given lock file contents and return (exit_code, output)."""
    script = Path(__file__).parent / "verify-package-locks.py"

    with tempfile.TemporaryDirectory() as tmpdir:
        main_path = Path(tmpdir) / "main.resolved"
        acp_path = Path(tmpdir) / "acp.resolved"
        main_path.write_text(main_content)
        acp_path.write_text(acp_content)

        result = subprocess.run(
            [sys.executable, str(script), str(main_path), str(acp_path)] + list(args),
            capture_output=True,
            text=True,
        )
        return result.returncode, result.stdout + result.stderr


def test_all_matching():
    """All shared dependencies have matching revisions."""
    print("▶ all shared dependencies match")

    main = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
        "SwiftLint": ("0.54.0", "def456"),
    })
    acp = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
        "SwiftLint": ("0.54.0", "def456"),
    })

    code, output = run_verify(main, acp)
    assert code == 0, f"expected exit 0, got {code}\n{output}"
    assert "2 matching" in output, f"expected '2 matching' in output\n{output}"
    assert "All shared dependencies have matching revisions" in output
    print("  ✅ all matching exits 0")


def test_revision_mismatch():
    """Shared dependency with different revisions fails."""
    print("▶ revision mismatch detected")

    main = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
    })
    acp = create_resolved({
        "Alamofire": ("5.9.0", "different_revision"),
    })

    code, output = run_verify(main, acp)
    assert code == 1, f"expected exit 1, got {code}\n{output}"
    assert "mismatched" in output.lower(), f"expected mismatch in output\n{output}"
    assert "Alamofire" in output
    print("  ✅ mismatch exits 1")


def test_unique_dependencies():
    """Dependencies unique to one lock are informational only."""
    print("▶ unique dependencies are informational")

    main = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
        "MainOnly": ("1.0.0", "main123"),
    })
    acp = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
        "AcpOnly": ("2.0.0", "acp456"),
    })

    code, output = run_verify(main, acp)
    assert code == 0, f"expected exit 0 (unique deps are OK), got {code}\n{output}"
    assert "1 matching" in output
    assert "2 unique" in output
    print("  ✅ unique deps don't fail")


def test_strict_mode():
    """Strict mode fails on unique dependencies."""
    print("▶ strict mode fails on unique deps")

    main = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
        "MainOnly": ("1.0.0", "main123"),
    })
    acp = create_resolved({
        "Alamofire": ("5.9.0", "abc123"),
    })

    code, output = run_verify(main, acp, "--strict")
    assert code == 1, f"expected exit 1 in strict mode, got {code}\n{output}"
    assert "strict" in output.lower()
    print("  ✅ strict mode exits 1")


def test_empty_locks():
    """Empty lock files work correctly."""
    print("▶ empty locks")

    main = create_resolved({})
    acp = create_resolved({})

    code, output = run_verify(main, acp)
    assert code == 0, f"expected exit 0 for empty locks, got {code}\n{output}"
    assert "0 matching" in output
    print("  ✅ empty locks exit 0")


def test_missing_file():
    """Missing file exits 2."""
    print("▶ missing file")

    script = Path(__file__).parent / "verify-package-locks.py"

    with tempfile.TemporaryDirectory() as tmpdir:
        main_path = Path(tmpdir) / "main.resolved"
        main_path.write_text('{"pins": []}')
        # acp_path does not exist

        result = subprocess.run(
            [sys.executable, str(script), str(main_path), "/nonexistent/acp.resolved"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 2, f"expected exit 2, got {result.returncode}"
        print("  ✅ missing file exits 2")


def test_no_args():
    """No arguments exits 2."""
    print("▶ no arguments")

    script = Path(__file__).parent / "verify-package-locks.py"
    result = subprocess.run(
        [sys.executable, str(script)],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 2, f"expected exit 2, got {result.returncode}"
    print("  ✅ no args exits 2")


def main():
    tests = [
        test_all_matching,
        test_revision_mismatch,
        test_unique_dependencies,
        test_strict_mode,
        test_empty_locks,
        test_missing_file,
        test_no_args,
    ]

    failed = 0
    for test in tests:
        try:
            test()
        except AssertionError as e:
            print(f"  ❌ {test.__name__}: {e}")
            failed += 1

    print()
    if failed == 0:
        print(f"✅ test-verify-package-locks.py: {len(tests)} tests passed")
        return 0
    else:
        print(f"❌ test-verify-package-locks.py: {failed} of {len(tests)} tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())
